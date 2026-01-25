defmodule MediaStreamWeb.AudioController do
  use MediaStreamWeb, :controller
  alias MediaStream.Media

  @mime_types %{
    ".mp3" => "audio/mpeg",
    ".m4a" => "audio/mp4",
    ".flac" => "audio/flac",
    ".ogg" => "audio/ogg",
    ".wav" => "audio/wav",
    ".aac" => "audio/aac",
    ".wma" => "audio/x-ms-wma",
    ".opus" => "audio/opus"
  }

  @doc """
  Streams an audio file with range request support for seeking.
  """
  def stream(conn, %{"id" => id}) do
    audio_file = Media.get_audio_file!(id)

    if not File.exists?(audio_file.path) do
      conn
      |> send_resp(404, "File not found")
      |> halt()
    else
      file_stat = File.stat!(audio_file.path)
      file_size = file_stat.size
      content_type = get_mime_type(audio_file.path, audio_file.file_type)

      # Get range header if present
      range_header = get_req_header(conn, "range")

      case range_header do
        ["bytes=" <> range] ->
          # Parse range header
          {start_byte, end_byte} = parse_range(range, file_size)
          content_length = end_byte - start_byte + 1

          # Send partial content with range
          conn
          |> put_resp_header("content-type", content_type)
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
          |> put_resp_header("content-type", content_type)
          |> put_resp_header("accept-ranges", "bytes")
          |> put_resp_header("content-length", "#{file_size}")
          |> send_file(200, audio_file.path)
      end
    end
  end

  defp get_mime_type(path, stored_type) do
    ext = Path.extname(path) |> String.downcase()
    # Check if stored_type is already a valid MIME type
    if stored_type && String.contains?(stored_type, "/") do
      stored_type
    else
      Map.get(@mime_types, ext, "audio/mpeg")
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
