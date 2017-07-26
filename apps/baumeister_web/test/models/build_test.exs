defmodule BaumeisterWeb.Web.BuildTest do
  use BaumeisterWeb.Web.ModelCase

  alias BaumeisterWeb.Web.Build

  @valid_attrs %{config: "some content", coordinate: "some content", log: "some content", number: 42, project_id: 42}
  @invalid_attrs %{}

  setup do
    {_, _} = Repo.delete_all(Build)
    :ok
  end

  test "store build with valid attributes" do
    changeset = Build.changeset(%Build{}, @valid_attrs)
    assert changeset.valid?
    {:ok, build} = Repo.insert(changeset)
    assert build.id == 1
  end

  test "changeset with valid attributes" do
    changeset = Build.changeset(%Build{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Build.changeset(%Build{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "there are no builds to load" do
    assert [] = Repo.all(Build)
  end
end
