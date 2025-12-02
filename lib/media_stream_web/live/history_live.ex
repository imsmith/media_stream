defmodule MediaStreamWeb.HistoryLive do
  use MediaStreamWeb, :live_view
  alias MediaStream.Media

  @impl true
  def mount(_params, session, socket) do
    device_id = session["device_id"] || generate_device_id()

    # Load listening history
    history = Media.list_listening_history()

    # Default to last 30 days for search
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -30)

    {:ok,
     socket
     |> assign(:device_id, device_id)
     |> assign(:history, history)
     |> assign(:filtered_history, history)
     |> assign(:search_query, "")
     |> assign(:start_date, Date.to_string(start_date))
     |> assign(:end_date, Date.to_string(end_date))
     |> assign(:show_all_devices, true)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filtered = filter_history(socket.assigns.history, query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_history, filtered)}
  end

  def handle_event("filter_by_date", params, socket) do
    start_date = Date.from_iso8601!(params["start_date"])
    end_date = Date.from_iso8601!(params["end_date"])
    query = if params["query"] == "", do: nil, else: params["query"]

    history = Media.search_listening_history(start_date, end_date, query)

    {:noreply,
     socket
     |> assign(:history, history)
     |> assign(:filtered_history, history)
     |> assign(:start_date, params["start_date"])
     |> assign(:end_date, params["end_date"])
     |> assign(:search_query, query || "")}
  end

  def handle_event("toggle_device_filter", _params, socket) do
    show_all = !socket.assigns.show_all_devices

    history =
      if show_all do
        Media.list_listening_history()
      else
        Media.list_listening_history(socket.assigns.device_id)
      end

    {:noreply,
     socket
     |> assign(:show_all_devices, show_all)
     |> assign(:history, history)
     |> assign(:filtered_history, history)}
  end

  defp filter_history(history, ""), do: history

  defp filter_history(history, query) do
    search_term = String.downcase(query)

    Enum.filter(history, fn entry ->
      title = String.downcase(entry.audio_file.title || "")
      artist = String.downcase(entry.audio_file.artist || "")
      album = String.downcase(entry.audio_file.album || "")

      String.contains?(title, search_term) or
        String.contains?(artist, search_term) or
        String.contains?(album, search_term)
    end)
  end

  defp generate_device_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :upper)
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp format_duration(nil), do: "0:00"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
