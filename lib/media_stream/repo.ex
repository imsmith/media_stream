defmodule MediaStream.Repo do
  use Ecto.Repo,
    otp_app: :media_stream,
    adapter: Ecto.Adapters.SQLite3
end
