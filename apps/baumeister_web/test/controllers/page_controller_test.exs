defmodule BaumeisterWeb.Web.PageControllerTest do
  use BaumeisterWeb.Web.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Baumeister!"
  end
end
