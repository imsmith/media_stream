defmodule MediaStreamWeb.PlayerLive do
  use MediaStreamWeb, :live_view
  alias MediaStream.Media
  alias Phoenix.PubSub

  @global_playback_id "GLOBAL"

  @impl true
  def mount(_params, session, socket) do
    # Device ID is kept for listening history, but playback syncs globally
    device_id = session["device_id"] || generate_device_id()
    Comn.Contexts.new(%{metadata: %{device_id: device_id}})

    if connected?(socket) do
      # Subscribe to global playback updates (all devices share the same state)
      PubSub.subscribe(MediaStream.PubSub, "playback:#{@global_playback_id}")
    end

    # Load all audio files
    audio_files = Media.list_audio_files()

    # Restore global playback state
    playback_state = Media.get_playback_state(@global_playback_id)

    {current_file, queue, position, playing, active_player_id} =
      case playback_state do
        nil ->
          {nil, [], 0.0, false, nil}

        state ->
          current = if state.current_file_id, do: Media.get_audio_file!(state.current_file_id)
          queue_ids = decode_queue(state.queue_json)
          queue_files = Enum.map(queue_ids, &Media.get_audio_file!/1)
          {current, queue_files, state.position_seconds || 0.0, state.playing || false, state.active_player_id}
      end

    {:ok,
     socket
     |> assign(:device_id, device_id)
     |> assign(:audio_files, audio_files)
     |> assign(:filtered_files, audio_files)
     |> assign(:current_file, current_file)
     |> assign(:queue, queue)
     |> assign(:position, position)
     |> assign(:playing, playing)
     |> assign(:active_player_id, active_player_id)
     |> assign(:remote_control_mode, false)
     |> assign(:search_query, "")
     |> assign(:upload_error, nil)
     |> assign(:scan_status, nil)
     |> assign(:directory_path, "")
     |> assign(:current_history_id, nil)
     |> allow_upload(:playlist, accept: [".m3u", ".m3u8"], max_entries: 1)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filtered =
      if query == "" do
        socket.assigns.audio_files
      else
        Media.search_audio_files(query)
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_files, filtered)}
  end

  def handle_event("add_to_queue", %{"id" => id}, socket) do
    file = Media.get_audio_file!(String.to_integer(id))

    # If nothing is currently playing, auto-play this track
    # Otherwise, add to queue
    if not socket.assigns.playing do
      # Start playing this track immediately
      update_state(socket, %{
        current_file_id: file.id,
        position_seconds: 0.0,
        queue_json: encode_queue(socket.assigns.queue),
        playing: true
      })

      {:noreply,
       socket
       |> assign(:current_file, file)
       |> assign(:position, 0.0)
       |> assign(:playing, true)
       |> start_history_entry(file.id)}
    else
      # Something is playing, add to queue
      queue = socket.assigns.queue ++ [file]
      update_state(socket, %{queue_json: encode_queue(queue)})

      {:noreply, assign(socket, :queue, queue)}
    end
  end

  def handle_event("remove_from_queue", %{"id" => id}, socket) do
    file_id = String.to_integer(id)
    queue = Enum.reject(socket.assigns.queue, fn f -> f.id == file_id end)

    # Update playback state
    update_state(socket, %{queue_json: encode_queue(queue)})

    {:noreply, assign(socket, :queue, queue)}
  end

  def handle_event("play", %{"id" => id}, socket) do
    file = Media.get_audio_file!(String.to_integer(id))

    # Update playback state
    update_state(socket, %{current_file_id: file.id, position_seconds: 0.0, playing: true})

    {:noreply,
     socket
     |> assign(:current_file, file)
     |> assign(:position, 0.0)
     |> assign(:playing, true)
     |> start_history_entry(file.id)}
  end

  def handle_event("pause", _params, socket) do
    update_state(socket, %{playing: false})
    {:noreply,
     socket
     |> assign(:playing, false)
     |> finalize_history_entry()}
  end

  def handle_event("resume", _params, socket) do
    update_state(socket, %{playing: true})
    {:noreply, assign(socket, :playing, true)}
  end

  def handle_event("seek", %{"position" => position}, socket) do
    position_float = String.to_float(position)

    # Update playback state
    update_state(socket, %{position_seconds: position_float})

    {:noreply, assign(socket, :position, position_float)}
  end

  def handle_event("seek_to_position", %{"position" => position}, socket) do
    # Handle click on progress bar - position is calculated by JS hook
    position_float = if is_float(position), do: position, else: position / 1

    # Update playback state
    update_state(socket, %{position_seconds: position_float})

    {:noreply, assign(socket, :position, position_float)}
  end

  def handle_event("next", _params, socket) do
    case socket.assigns.queue do
      [] ->
        {:noreply, socket}

      [next_file | rest] ->
        # Update playback state
        update_state(socket, %{
          current_file_id: next_file.id,
          position_seconds: 0.0,
          queue_json: encode_queue(rest),
          playing: true
        })

        {:noreply,
         socket
         |> assign(:current_file, next_file)
         |> assign(:queue, rest)
         |> assign(:position, 0.0)
         |> assign(:playing, true)
         |> start_history_entry(next_file.id)}
    end
  end

  def handle_event("prev", _params, socket) do
    # For simplicity, just restart current track
    update_state(socket, %{position_seconds: 0.0})

    {:noreply, assign(socket, :position, 0.0)}
  end

  def handle_event("audio_playing", _params, socket) do
    {:noreply, assign(socket, :playing, true)}
  end

  def handle_event("audio_paused", _params, socket) do
    {:noreply, assign(socket, :playing, false)}
  end

  def handle_event("audio_time_update", %{"position" => position}, socket) do
    update_state(socket, %{position_seconds: position})
    {:noreply, assign(socket, :position, position)}
  end

  def handle_event("audio_ended", _params, socket) do
    # Auto-advance to next track
    send(self(), :play_next)
    {:noreply, socket}
  end

  def handle_event("audio_metadata_loaded", %{"duration" => _duration}, socket) do
    # Update duration if needed
    {:noreply, socket}
  end

  def handle_event("validate_playlist", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("load_playlist", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :playlist, fn %{path: path}, _entry ->
        case Media.load_playlist_queue(path) do
          {:ok, audio_files} ->
            {:ok, audio_files}

          {:error, _reason} ->
            {:ok, []}
        end
      end)

    case uploaded_files do
      [audio_files] when is_list(audio_files) and audio_files != [] ->
        # Replace queue with playlist tracks
        update_state(socket, %{queue_json: encode_queue(audio_files)})

        {:noreply,
         socket
         |> assign(:queue, audio_files)
         |> assign(:upload_error, nil)
         |> put_flash(:info, "Loaded #{length(audio_files)} tracks from playlist")}

      [_empty_list] ->
        {:noreply,
         socket
         |> assign(:upload_error, "No matching tracks found in playlist")
         |> put_flash(:error, "No matching tracks found in playlist")}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :playlist, ref)}
  end

  def handle_event("scan_directory", %{"directory_path" => path}, socket) do
    path = String.trim(path)

    if path == "" do
      {:noreply,
       socket
       |> assign(:scan_status, "Please enter a directory path")
       |> assign(:directory_path, path)}
    else
      case Media.scan_directory(path) do
        {:ok, %{scanned: scanned, added: added, skipped: skipped}} ->
          # Refresh audio files list
          audio_files = Media.list_audio_files()

          {:noreply,
           socket
           |> assign(:audio_files, audio_files)
           |> assign(:filtered_files, audio_files)
           |> assign(:scan_status, "Scanned #{scanned} files: #{added} added, #{skipped} skipped")
           |> assign(:directory_path, "")
           |> put_flash(:info, "Scanned #{scanned} files: #{added} added, #{skipped} skipped")}

        {:error, reason} ->
          error = Comn.Errors.wrap(reason)
          {:noreply,
           socket
           |> assign(:scan_status, "Error: #{error.message}")
           |> assign(:directory_path, path)
           |> put_flash(:error, error.message)}
      end
    end
  end

  def handle_event("update_directory_path", %{"directory_path" => path}, socket) do
    {:noreply, assign(socket, :directory_path, path)}
  end

  def handle_event("toggle_remote_control", _params, socket) do
    {:noreply, assign(socket, :remote_control_mode, !socket.assigns.remote_control_mode)}
  end

  def handle_event("claim_active_player", _params, socket) do
    # Explicitly claim this device as the active player
    update_state(socket, %{active_player_id: socket.assigns.device_id})
    {:noreply, assign(socket, :active_player_id, socket.assigns.device_id)}
  end

  @impl true
  def handle_info({:event, "playback:" <> _, %Comn.Events.EventStruct{type: :playback_state_updated, data: state}}, socket) do
    # Sync from other device/tab
    current = if state.current_file_id, do: Media.get_audio_file!(state.current_file_id)
    queue_ids = decode_queue(state.queue_json)
    queue_files = Enum.map(queue_ids, &Media.get_audio_file!/1)

    {:noreply,
     socket
     |> assign(:current_file, current)
     |> assign(:queue, queue_files)
     |> assign(:position, state.position_seconds || 0.0)
     |> assign(:playing, state.playing || false)
     |> assign(:active_player_id, state.active_player_id)}
  end

  def handle_info(:play_next, socket) do
    # Auto-advance to next track in queue
    case socket.assigns.queue do
      [] ->
        # No more tracks, stop playing
        update_state(socket, %{playing: false})
        {:noreply,
         socket
         |> assign(:playing, false)
         |> finalize_history_entry()}

      [next_file | rest] ->
        # Play next track
        update_state(socket, %{
          current_file_id: next_file.id,
          position_seconds: 0.0,
          queue_json: encode_queue(rest),
          playing: true
        })

        {:noreply,
         socket
         |> assign(:current_file, next_file)
         |> assign(:queue, rest)
         |> assign(:position, 0.0)
         |> assign(:playing, true)
         |> start_history_entry(next_file.id)}
    end
  end

  defp update_state(socket, attrs) do
    # All devices share the global playback state
    # If not in remote control mode, also claim this device as the active player
    attrs_with_device =
      attrs
      |> Map.put(:device_id, @global_playback_id)
      |> maybe_claim_active_player(socket)

    Media.update_playback_state(@global_playback_id, attrs_with_device)
  end

  defp maybe_claim_active_player(attrs, socket) do
    if socket.assigns.remote_control_mode do
      # Remote control mode: don't change active player
      attrs
    else
      # Normal mode: this device becomes the active player
      Map.put(attrs, :active_player_id, socket.assigns.device_id)
    end
  end

  defp encode_queue(queue) do
    queue
    |> Enum.map(& &1.id)
    |> Jason.encode!()
  end

  defp decode_queue(nil), do: []

  defp decode_queue(json) do
    case Jason.decode(json) do
      {:ok, ids} -> ids
      {:error, _} -> []
    end
  end

  defp generate_device_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :upper)
  end

  defp start_history_entry(socket, audio_file_id) do
    # Finalize any existing history entry first
    socket = finalize_history_entry(socket)

    case Media.create_listening_history(%{
      audio_file_id: audio_file_id,
      device_id: socket.assigns.device_id,
      started_at: DateTime.utc_now()
    }) do
      {:ok, entry} -> assign(socket, :current_history_id, entry.id)
      {:error, reason} ->
        error = Comn.Errors.wrap(reason)
        socket |> put_flash(:error, error.message)
    end
  end

  defp finalize_history_entry(socket) do
    case socket.assigns.current_history_id do
      nil ->
        socket

      history_id ->
        case Media.get_listening_history(history_id) do
          nil ->
            socket

          entry ->
            now = DateTime.utc_now()
            duration = DateTime.diff(now, entry.started_at, :second)
            Media.update_listening_history(entry, %{
              completed_at: now,
              duration_listened_seconds: max(duration, 0)
            })
            assign(socket, :current_history_id, nil)
        end
    end
  end

  defp format_duration(nil), do: "0:00"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
