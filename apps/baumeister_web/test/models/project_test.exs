defmodule BaumeisterWeb.Web.ProjectTest do
  use BaumeisterWeb.Web.ModelCase

  alias BaumeisterWeb.Web.Project

  @valid_attrs %{name: "some content", plugins: "some content",
    url: "some content", enabled: false, delay: 5}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Project.changeset(%Project{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Project.changeset(%Project{}, @invalid_attrs)
    refute changeset.valid?
  end
end
