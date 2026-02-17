defmodule MediaStreamWeb.Plugs.DeviceId do
  @moduledoc """
  Plug to ensure a consistent device_id is set in the session.

  This allows the same device_id to be used across page loads and tabs,
  enabling PubSub-based playback state synchronization.

  Also initializes a Comn.Contexts for the HTTP request process.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    device_id =
      case get_session(conn, "device_id") do
        nil -> generate_device_id()
        existing -> existing
      end

    Comn.Contexts.new(%{metadata: %{device_id: device_id}})

    conn
    |> put_session("device_id", device_id)
  end

  defp generate_device_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :upper)
  end
end
