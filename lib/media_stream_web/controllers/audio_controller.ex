defmodule MediaStreamWeb.AudioController do
  use MediaStreamWeb, :controller
  alias MediaStream.Media

  @doc """
  Streams an audio file with range request support for seeking.
  """
  def stream(conn, %{"id" => id}) do
    audio_file = Media.get_audio_file!(id)

    unless File.exists?(audio_file.path) do
      send_resp(conn, 404, "File not found")
    else
      file_stat = File.stat!(audio_file.path)
      file_size = file_stat.size

      # Get range header if present
      range_header = get_req_header(conn, "range")

      case range_header do
        ["bytes=" <> range] ->
          # Parse range header
          {start_byte, end_byte} = parse_range(range, file_size)
          content_length = end_byte - start_byte + 1

          # Send partial content with range
          conn
          |> put_resp_header("content-type", audio_file.file_type || "audio/mpeg")
          |> put_resp_header("accept-ranges", "bytes")
          |> put_resp_header(
            "content-range",
            "bytes #{start_byte}-#{end_byte}/#{file_size}"
          )
          |> put_resp_header("content-length", "#{content_length}")
          |> send_file(206, audio_file.path, start_byte, content_length)

        _ ->
          # No range header, send entire file
          conn
          |> put_resp_header("content-type", audio_file.file_type || "audio/mpeg")
          |> put_resp_header("accept-ranges", "bytes")
          |> put_resp_header("content-length", "#{file_size}")
          |> send_file(200, audio_file.path)
      end
    end
  end

  defp parse_range(range, file_size) do
    case String.split(range, "-") do
      [start, ""] ->
        # Range like "0-" means from start to end
        {String.to_integer(start), file_size - 1}

      [start, end_str] ->
        # Range like "0-1023" means from start to end
        {String.to_integer(start), String.to_integer(end_str)}

      ["", end_str] ->
        # Range like "-1024" means last 1024 bytes
        bytes = String.to_integer(end_str)
        {max(0, file_size - bytes), file_size - 1}

      _ ->
        # Invalid range, return entire file
        {0, file_size - 1}
    end
  end
end
