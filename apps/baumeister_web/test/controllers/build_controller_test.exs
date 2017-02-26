defmodule BaumeisterWeb.BuildControllerTest do
  use BaumeisterWeb.ConnCase

  alias BaumeisterWeb.Build
  @valid_attrs %{config: "some content", coordinate: "some content",
    log: "some content", number: 42, project_id: 42}
  @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, build_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing builds"
  end

  test "shows chosen resource", %{conn: conn} do
    build = Repo.insert! %Build{}
    conn = get conn, build_path(conn, :show, build)
    assert html_response(conn, 200) =~ "Show build"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, build_path(conn, :show, -1)
    end
  end

end
