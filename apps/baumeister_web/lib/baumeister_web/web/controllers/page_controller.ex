defmodule BaumeisterWeb.Web.PageController do
  use BaumeisterWeb.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
