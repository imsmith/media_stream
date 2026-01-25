defmodule MediaStreamWeb.Plugs.DeviceId do
  @moduledoc """
  Plug to ensure a consistent device_id is set in the session.

  This allows the same device_id to be used across page loads and tabs,
  enabling PubSub-based playback state synchronization.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, "device_id") do
      nil ->
        device_id = generate_device_id()
        put_session(conn, "device_id", device_id)

      _existing ->
        conn
    end
  end

  defp generate_device_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :upper)
  end
end
