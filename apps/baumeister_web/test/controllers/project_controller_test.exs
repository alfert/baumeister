defmodule BaumeisterWeb.ProjectControllerTest do
  use BaumeisterWeb.ConnCase

  alias BaumeisterWeb.Project
  @valid_attrs %{name: "some content", plugins: "some content", url: "some content",
    enabled: false, delay: 5}
  @invalid_attrs %{}

  @doc """
  Creates unique and valid attributes, i.e. the unique constraint on `name`
  is fullfilled by appending a unique integer.
  """
  def unique_attributes do
    count = "#{System.unique_integer([:positive])}"
    %{@valid_attrs | name: @valid_attrs.name <> count}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, project_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing projects"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, project_path(conn, :new)
    assert html_response(conn, 200) =~ "New project"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    attributes = unique_attributes()
    conn = post conn, project_path(conn, :create), project: attributes
    assert redirected_to(conn) == project_path(conn, :index)
    assert Repo.get_by(Project, attributes)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, project_path(conn, :create), project: @invalid_attrs
    assert html_response(conn, 200) =~ "New project"
  end

  test "shows chosen resource", %{conn: conn} do
    project = Repo.insert! %Project{}
    conn = get conn, project_path(conn, :show, project)
    assert html_response(conn, 200) =~ "Show project"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, project_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    project = Repo.insert! %Project{}
    conn = get conn, project_path(conn, :edit, project)
    assert html_response(conn, 200) =~ "Edit project"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    project = Repo.insert! %Project{}
    attributes = unique_attributes()
    conn = put conn, project_path(conn, :update, project), project: attributes
    assert redirected_to(conn) == project_path(conn, :show, project)
    assert Repo.get_by(Project, attributes)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    project = Repo.insert! %Project{}
    conn = put conn, project_path(conn, :update, project), project: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit project"
  end

  test "deletes chosen resource", %{conn: conn} do
    project = Repo.insert! %Project{}
    conn = delete conn, project_path(conn, :delete, project)
    assert redirected_to(conn) == project_path(conn, :index)
    refute Repo.get(Project, project.id)
  end
end
