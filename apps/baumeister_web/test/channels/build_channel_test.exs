defmodule BaumeisterWeb.BuildChannelTest do
  use BaumeisterWeb.ChannelCase

  alias BaumeisterWeb.BuildChannel
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.BuildEvent
  alias BaumeisterWeb.Project
  alias BaumeisterWeb.Build

  setup do
    {:ok, _, socket} = "user_id"
      |> socket(%{some: :assign})
      |> subscribe_and_join(BuildChannel, "build:lobby")

    {:ok, socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to build:lobby", %{socket: socket} do
    push socket, "shout", %{"hello" => "all"}
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from! socket, "broadcast", %{"some" => "data"}
    assert_push "broadcast", %{"some" => "data"}
  end

  test "broadcast an old build event", %{socket: _socket} do
    event = {:tester, :test_broadcast, :data}
    BuildChannel.broadcast_event(event)
    assert_broadcast "old_build_event", %{
      "role" => "tester", "action" => "test_broadcast", "step" => ":data"}
  end

  test "broadcast a build event", %{socket: _socket} do
    coord = "/tmp"
    |> NoopPlugin.make_coordinate()
    |> Map.put(:project_name, "test_project")
    changeset = Project.changeset(%Project{}, %{name: coord.project_name,
      url: coord.url, plugins: "noop", enabled: true, delay: 500, builds: [], last_build: nil})
    project = Repo.insert_or_update!(changeset)
    IO.inspect(project)
    # last build id is not set => default value is -1
    last_build = project.last_build_id
    assert nil == last_build

    build_number = 1
    event = coord
      |> BuildEvent.new(build_number)
      |> BuildEvent.action(:log, "Hello")
    BuildChannel.broadcast_event(event)
    coord_s = "#{inspect coord}"
    assert_broadcast "build_event", %{
      "role" => "worker", "action" => "log", "data" => "\"Hello\"",
      "coordinate" => ^coord_s}
    all_builds = Repo.all Build
    assert Enum.count(all_builds) > 0
    IO.inspect(all_builds)
    # assert all_builds == []
    build = Repo.get_by!(Build, [project_id: project.id, number: 1])
    assert build.coordinate == coord_s

    # check that the project is also updated
    p = Repo.get(Project, project.id)
    assert p.last_build_id == build_number
  end
end
