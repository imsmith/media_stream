defmodule MediaStreamWeb.PlayerLive do
  use MediaStreamWeb, :live_view
  alias MediaStream.Media
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    # Generate or retrieve device ID from session
    device_id = session["device_id"] || generate_device_id()

    if connected?(socket) do
      # Subscribe to playback updates for this device
      PubSub.subscribe(MediaStream.PubSub, "playback:#{device_id}")
    end

    # Load all audio files
    audio_files = Media.list_audio_files()

    # Restore playback state if it exists
    playback_state = Media.get_playback_state(device_id)

    {current_file, queue, position} =
      case playback_state do
        nil ->
          {nil, [], 0.0}

        state ->
          current = if state.current_file_id, do: Media.get_audio_file!(state.current_file_id)
          queue_ids = decode_queue(state.queue_json)
          queue_files = Enum.map(queue_ids, &Media.get_audio_file!/1)
          {current, queue_files, state.position_seconds || 0.0}
      end

    {:ok,
     socket
     |> assign(:device_id, device_id)
     |> assign(:audio_files, audio_files)
     |> assign(:filtered_files, audio_files)
     |> assign(:current_file, current_file)
     |> assign(:queue, queue)
     |> assign(:position, position)
     |> assign(:playing, false)
     |> assign(:search_query, "")
     |> assign(:upload_error, nil)
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
    queue = socket.assigns.queue ++ [file]

    # Update playback state
    update_state(socket, %{queue_json: encode_queue(queue)})

    {:noreply, assign(socket, :queue, queue)}
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
    update_state(socket, %{current_file_id: file.id, position_seconds: 0.0})

    {:noreply,
     socket
     |> assign(:current_file, file)
     |> assign(:position, 0.0)
     |> assign(:playing, true)}
  end

  def handle_event("pause", _params, socket) do
    {:noreply, assign(socket, :playing, false)}
  end

  def handle_event("resume", _params, socket) do
    {:noreply, assign(socket, :playing, true)}
  end

  def handle_event("seek", %{"position" => position}, socket) do
    position_float = String.to_float(position)

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
          queue_json: encode_queue(rest)
        })

        {:noreply,
         socket
         |> assign(:current_file, next_file)
         |> assign(:queue, rest)
         |> assign(:position, 0.0)
         |> assign(:playing, true)}
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

  @impl true
  def handle_info({:playback_state_updated, state}, socket) do
    # Sync from other device
    current = if state.current_file_id, do: Media.get_audio_file!(state.current_file_id)
    queue_ids = decode_queue(state.queue_json)
    queue_files = Enum.map(queue_ids, &Media.get_audio_file!/1)

    {:noreply,
     socket
     |> assign(:current_file, current)
     |> assign(:queue, queue_files)
     |> assign(:position, state.position_seconds || 0.0)}
  end

  defp update_state(socket, attrs) do
    attrs_with_device = Map.put(attrs, :device_id, socket.assigns.device_id)
    Media.update_playback_state(socket.assigns.device_id, attrs_with_device)
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

  defp format_duration(nil), do: "0:00"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
