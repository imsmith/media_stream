defmodule MediaStreamWeb.PageController do
  use MediaStreamWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
