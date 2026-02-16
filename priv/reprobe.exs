alias MediaStream.{Repo, Media.AudioFile}

files = Repo.all(AudioFile)
IO.puts("Re-probing #{length(files)} files...")

{updated, missing} =
  Enum.reduce(files, {0, 0}, fn file, {count, miss} ->
    if not File.exists?(file.path) do
      {count, miss + 1}
    else
      case System.cmd("ffprobe", [
             "-v", "error",
             "-show_entries", "format_tags=artist,album,title",
             "-of", "default=noprint_wrappers=1",
             file.path
           ], stderr_to_stdout: true) do
        {output, 0} ->
          tags =
            output
            |> String.split("\n", trim: true)
            |> Enum.reduce(%{}, fn line, acc ->
              case String.split(line, "=", parts: 2) do
                ["TAG:title", val] -> Map.put(acc, :title, String.trim(val))
                ["TAG:artist", val] -> Map.put(acc, :artist, String.trim(val))
                ["TAG:album", val] -> Map.put(acc, :album, String.trim(val))
                _ -> acc
              end
            end)

          changes = tags |> Enum.reject(fn {_k, v} -> v == "" end) |> Map.new()

          if map_size(changes) > 0 do
            file |> AudioFile.changeset(changes) |> Repo.update!()
            {count + 1, miss}
          else
            {count, miss}
          end

        _ ->
          {count, miss}
      end
    end
  end)

IO.puts("Updated #{updated} of #{length(files)} files (#{missing} missing from disk).")
