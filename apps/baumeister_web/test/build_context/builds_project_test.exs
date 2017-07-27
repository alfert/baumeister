defmodule BaumeisterWeb.Web.Test.Builds.Project do
  @moduledoc """
  Tests of Projects and Builds within the Builds-Context.
  """
  use BaumeisterWeb.Web.ModelCase

  alias BaumeisterWeb.Builds.Project
  alias BaumeisterWeb.Builds.Build
  alias BaumeisterWeb.Builds
  alias Baumeister.BuildEvent
  alias Baumeister.Observer.NoopPlugin
  require Logger

  @valid_p_attrs %{name: "project_", plugins: "some content",
    url: "some content", enabled: false, delay: 5}
  @invalid_p_attrs %{}

  @valid_b_attrs %{config: "some content", coordinate: "some content",
    log: "some content", number: 42}

  setup do
    Repo.delete_all(Build)
    Repo.delete_all(Project)
    :ok
  end

  # creates a unique project name inside the attributes
  def unique_project(attributes) do
    count = "#{System.unique_integer([:positive])}"
    %{attributes | name: attributes.name <> count}
  end

  test "insert a project" do
    changeset = Project.changeset(%Project{}, unique_project @valid_p_attrs)
    # Logger.debug "changeset = #{inspect changeset}"
    result = Builds.insert_project(changeset)
    assert {:ok, _} = result
    assert {:ok, %Project{}} = result
    {:ok, p} = result
    assert is_nil(p.last_build)
  end

  test "insert a project with build fails" do
    b = Build.changeset(%Build{}, @valid_b_attrs)
    changeset = Project.changeset(%Project{}, unique_project @valid_p_attrs)
    |> put_embed(:last_build, b)
    Logger.debug "changeset = #{inspect changeset}"
    result = Builds.insert_project(changeset)
    assert {:error, _} = result
  end

  test "add a build with several states" do
    {:ok, project} = %Project{}
    |> Project.changeset(unique_project @valid_p_attrs)
    |> Builds.insert_project()
    coord = "/tmp"
    |> NoopPlugin.make_coordinate()
    |> Map.put(:project_name, project.name)

    assert is_nil(project.last_build)
    actions = [{:start, nil}, {:log, "log1"}, {:log, "log2"}, {:result, 0}]
    actions |> Enum.each(fn {action, data} ->
      be = BuildEvent.new(coord, 1)
      |> BuildEvent.action(action, data)
      result = Builds.create_build_from_event(be)
      assert {:ok, _} = result
      assert {:ok, %Build{}} = result
      {:ok, b} = result
      assert b.number == 1
      assert b.project_id == project.id
      p = Builds.get_project(b.project_id)
      # Logger.debug "p is #{inspect p}, at be = #{inspect be}"
      assert project.id == p.id
      assert p.last_build == b
    end)
    # How many builds were created?
    bs = Builds.builds_for_project(project)
    assert length(bs) == 1
  end

  test "Retrieve all projects" do
    ps = Builds.list_projects()
    Logger.debug "ps is #{inspect ps}"
    assert ps == []
  end

  test "Retrieve all builds of project" do
    {:ok, p} = %Project{}
    |> Project.changeset(unique_project @valid_p_attrs)
    |> Builds.insert_project()
    Logger.debug "p = #{inspect p}"
    bs = Builds.builds_for_project(p)
    assert bs == []
  end
end
