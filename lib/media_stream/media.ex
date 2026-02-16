defmodule MediaStream.Media do
  @moduledoc """
  The Media context for managing audio files and playback state.
  """

  import Ecto.Query, warn: false
  alias MediaStream.Repo
  alias MediaStream.Media.{AudioFile, PlaybackState}
  alias Phoenix.PubSub

  @doc """
  Returns the list of audio files.

  ## Examples

      iex> list_audio_files()
      [%AudioFile{}, ...]

  """
  def list_audio_files do
    Repo.all(AudioFile)
  end

  @doc """
  Searches audio files by title, artist, or album.

  ## Examples

      iex> search_audio_files("dark")
      [%AudioFile{}, ...]

  """
  def search_audio_files(query) when is_binary(query) do
    search_term = "%#{String.downcase(query)}%"

    AudioFile
    |> where(
      [a],
      like(fragment("lower(?)", a.title), ^search_term) or
        like(fragment("lower(?)", a.artist), ^search_term) or
        like(fragment("lower(?)", a.album), ^search_term)
    )
    |> Repo.all()
  end

  @doc """
  Gets a single audio file.

  Raises `Ecto.NoResultsError` if the Audio file does not exist.

  ## Examples

      iex> get_audio_file!(123)
      %AudioFile{}

      iex> get_audio_file!(456)
      ** (Ecto.NoResultsError)

  """
  def get_audio_file!(id), do: Repo.get!(AudioFile, id)

  @doc """
  Creates an audio file.

  ## Examples

      iex> create_audio_file(%{field: value})
      {:ok, %AudioFile{}}

      iex> create_audio_file(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_audio_file(attrs \\ %{}) do
    %AudioFile{}
    |> AudioFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Scans a directory for audio files and adds them to the database.
  Skips files that already exist based on path.

  ## Examples

      iex> scan_directory("/path/to/music")
      {:ok, %{scanned: 10, added: 5, skipped: 5}}

  """
  def scan_directory(directory_path) do
    audio_extensions = [".mp3", ".m4a", ".flac", ".ogg", ".wav", ".aac"]

    files =
      directory_path
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(fn path ->
        File.regular?(path) && Path.extname(path) in audio_extensions
      end)

    # Process files in parallel for much faster scanning
    results =
      files
      |> Task.async_stream(
        fn file_path ->
          case create_audio_file_from_path(file_path) do
            {:ok, _audio_file} -> {:added, 1}
            {:error, _changeset} -> {:skipped, 1}
          end
        end,
        max_concurrency: System.schedulers_online(),
        timeout: 10_000,
        ordered: false
      )
      |> Enum.reduce(%{scanned: 0, added: 0, skipped: 0}, fn
        {:ok, {:added, count}}, acc ->
          %{acc | scanned: acc.scanned + count, added: acc.added + count}

        {:ok, {:skipped, count}}, acc ->
          %{acc | scanned: acc.scanned + count, skipped: acc.skipped + count}

        {:exit, _reason}, acc ->
          # File timed out or crashed, count as skipped
          %{acc | scanned: acc.scanned + 1, skipped: acc.skipped + 1}
      end)

    {:ok, results}
  end

  defp create_audio_file_from_path(file_path) do
    file_name = Path.basename(file_path, Path.extname(file_path))
    file_type = Path.extname(file_path)
    file_size = File.stat!(file_path).size

    # Extract embedded metadata and duration via ffprobe (single call)
    probe = probe_file(file_path)

    # Fall back to filename/directory parsing for missing fields
    path_metadata = extract_metadata_from_path(file_path, file_name)

    attrs = %{
      path: file_path,
      title: probe[:title] || path_metadata.title,
      artist: probe[:artist] || path_metadata.artist,
      album: probe[:album] || path_metadata.album,
      duration_seconds: probe[:duration] || 0,
      file_type: file_type,
      file_size: file_size
    }

    create_audio_file(attrs)
  end

  # Single ffprobe call to extract both metadata tags and duration.
  defp probe_file(file_path) do
    case System.cmd("ffprobe", [
      "-v", "error",
      "-show_entries", "format=duration:format_tags=artist,album,title",
      "-of", "default=noprint_wrappers=1",
      file_path
    ], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.reduce(%{}, fn line, acc ->
          case String.split(line, "=", parts: 2) do
            ["duration", val] ->
              case Float.parse(val) do
                {d, _} -> Map.put(acc, :duration, trunc(d))
                :error -> acc
              end
            ["TAG:title", val] -> Map.put(acc, :title, String.trim(val))
            ["TAG:artist", val] -> Map.put(acc, :artist, String.trim(val))
            ["TAG:album", val] -> Map.put(acc, :album, String.trim(val))
            _ -> acc
          end
        end)

      _ ->
        %{}
    end
  end

  # Extracts metadata from file path and filename.
  #
  # Attempts to intelligently parse common filename patterns:
  # - "Artist - Title.mp3"
  # - "01 - Artist - Title.mp3"
  # - "01 Title.mp3"
  # - "Title.mp3"
  #
  # Also attempts to extract album from parent directory name.
  defp extract_metadata_from_path(file_path, file_name) do
    # Try to get album from parent directory
    parent_dir = file_path |> Path.dirname() |> Path.basename()
    album = if parent_dir != "." and parent_dir != "/" and parent_dir != "", do: parent_dir, else: "Unknown"

    # Parse filename for artist and title
    {artist, title} = parse_filename(file_name)

    %{
      title: title || file_name,
      artist: artist || "Unknown",
      album: album
    }
  end

  # Parses common filename patterns to extract artist and title.
  #
  # Patterns handled:
  # - "Artist - Title" -> {Artist, Title}
  # - "01 - Artist - Title" -> {Artist, Title}
  # - "01 - Title" -> {nil, Title}
  # - "01. Artist - Title" -> {Artist, Title}
  # - "Title" -> {nil, Title}
  defp parse_filename(filename) do
    # Remove leading track numbers (e.g., "01 - ", "01. ", "1 - ")
    cleaned = Regex.replace(~r/^\d+[\s\.\-]+/, filename, "")

    case String.split(cleaned, " - ", parts: 2, trim: true) do
      [artist, title] when byte_size(artist) > 0 and byte_size(title) > 0 ->
        # "Artist - Title" or "01 - Artist - Title" (after track number removal)
        {String.trim(artist), String.trim(title)}

      [title] ->
        # Just title, no artist
        {nil, String.trim(title)}

      _ ->
        # Couldn't parse, use whole filename as title
        {nil, filename}
    end
  end

  @doc """
  Gets the playback state for a device.

  ## Examples

      iex> get_playback_state("device_123")
      %PlaybackState{}

      iex> get_playback_state("unknown")
      nil

  """
  def get_playback_state(device_id) do
    Repo.get_by(PlaybackState, device_id: device_id)
  end

  @doc """
  Updates or creates playback state for a device.
  Broadcasts the update via PubSub for real-time sync.

  ## Examples

      iex> update_playback_state("device_123", %{position_seconds: 45.2})
      {:ok, %PlaybackState{}}

  """
  def update_playback_state(device_id, attrs) do
    case get_playback_state(device_id) do
      nil ->
        %PlaybackState{device_id: device_id}
        |> PlaybackState.changeset(attrs)
        |> Repo.insert()
        |> broadcast_playback_update()

      playback_state ->
        playback_state
        |> PlaybackState.changeset(attrs)
        |> Repo.update()
        |> broadcast_playback_update()
    end
  end

  defp broadcast_playback_update({:ok, playback_state} = result) do
    PubSub.broadcast(
      MediaStream.PubSub,
      "playback:#{playback_state.device_id}",
      {:playback_state_updated, playback_state}
    )

    result
  end

  defp broadcast_playback_update(error), do: error

  @doc """
  Creates a listening history entry.

  ## Examples

      iex> create_listening_history(%{audio_file_id: 1, device_id: "abc"})
      {:ok, %ListeningHistory{}}

  """
  def create_listening_history(attrs \\ %{}) do
    result =
      %MediaStream.Media.ListeningHistory{}
      |> MediaStream.Media.ListeningHistory.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, entry} ->
        entry = Repo.preload(entry, :audio_file)
        broadcast_history_update(entry)
        {:ok, entry}

      error ->
        error
    end
  end

  @doc """
  Updates a listening history entry (e.g., to set completed_at and duration).
  """
  def update_listening_history(%MediaStream.Media.ListeningHistory{} = entry, attrs) do
    result =
      entry
      |> MediaStream.Media.ListeningHistory.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        updated = Repo.preload(updated, :audio_file)
        broadcast_history_update(updated)
        {:ok, updated}

      error ->
        error
    end
  end

  def get_listening_history(id), do: Repo.get(MediaStream.Media.ListeningHistory, id)

  defp broadcast_history_update(entry) do
    PubSub.broadcast(MediaStream.PubSub, "listening_history", {:history_updated, entry})
  end

  @doc """
  Lists listening history, ordered by most recent first.
  Optionally filter by device_id.

  ## Examples

      iex> list_listening_history()
      [%ListeningHistory{}, ...]

      iex> list_listening_history("device_123")
      [%ListeningHistory{}, ...]

  """
  def list_listening_history(device_id \\ nil) do
    query =
      from h in MediaStream.Media.ListeningHistory,
        order_by: [desc: h.started_at],
        preload: [:audio_file]

    query =
      if device_id do
        where(query, [h], h.device_id == ^device_id)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Searches listening history by date range and optional query string.

  ## Examples

      iex> search_listening_history(~D[2024-01-01], ~D[2024-01-31])
      [%ListeningHistory{}, ...]

      iex> search_listening_history(~D[2024-01-01], ~D[2024-01-31], "podcast")
      [%ListeningHistory{}, ...]

  """
  def search_listening_history(start_date, end_date, query \\ nil) do
    start_datetime = DateTime.new!(start_date, ~T[00:00:00])
    end_datetime = DateTime.new!(end_date, ~T[23:59:59])

    base_query =
      from h in MediaStream.Media.ListeningHistory,
        where: h.started_at >= ^start_datetime and h.started_at <= ^end_datetime,
        order_by: [desc: h.started_at],
        preload: [:audio_file]

    query =
      if query do
        search_term = "%#{String.downcase(query)}%"

        from h in base_query,
          join: a in assoc(h, :audio_file),
          where:
            like(fragment("lower(?)", a.title), ^search_term) or
              like(fragment("lower(?)", a.artist), ^search_term) or
              like(fragment("lower(?)", a.album), ^search_term)
      else
        base_query
      end

    Repo.all(query)
  end

  @doc """
  Parses a .m3u or .m3u8 playlist file and returns a list of file paths.
  Skips comments and #EXTM3U headers.

  ## Examples

      iex> parse_playlist("/path/to/playlist.m3u8")
      ["/path/to/song1.mp3", "/path/to/song2.mp3"]

  """
  def parse_playlist(playlist_path) do
    unless File.exists?(playlist_path) do
      {:error, :file_not_found}
    else
      playlist_dir = Path.dirname(playlist_path)

      paths =
        playlist_path
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.reject(fn line ->
          # Skip comments and #EXTM3U headers
          String.starts_with?(line, "#")
        end)
        |> Enum.map(fn path ->
          # Handle relative paths by resolving against playlist directory
          if Path.type(path) == :absolute do
            path
          else
            Path.join(playlist_dir, path) |> Path.expand()
          end
        end)

      {:ok, paths}
    end
  end

  @doc """
  Loads a playlist and returns the corresponding AudioFile structs in order.
  Only returns files that exist in the database.

  ## Examples

      iex> load_playlist_queue("/path/to/playlist.m3u8")
      {:ok, [%AudioFile{}, %AudioFile{}]}

  """
  def load_playlist_queue(playlist_path) do
    case parse_playlist(playlist_path) do
      {:error, reason} ->
        {:error, reason}

      {:ok, paths} ->
        # Find matching audio files in database, preserving order
        audio_files =
          paths
          |> Enum.map(fn path ->
            Repo.get_by(AudioFile, path: path)
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, audio_files}
    end
  end
end
