defmodule BaumeisterWeb.Web.BuildChannelTest do
  use BaumeisterWeb.Web.ChannelCase

  alias BaumeisterWeb.Web.BuildChannel
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.BuildEvent
  alias BaumeisterWeb.Builds
  alias BaumeisterWeb.Builds.Project
  alias BaumeisterWeb.Builds.Build

  require Logger

  setup do
    Repo.delete_all(Build)
    Repo.delete_all(Project)
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

  test "broadcast a build event", %{socket: _socket} do
    coord = "/tmp"
    |> NoopPlugin.make_coordinate()
    |> Map.put(:project_name, "test_project_#{System.unique_integer([:positive])}")

    {:ok, project} = %Project{}
    |> Project.changeset(%{name: coord.project_name, url: coord.url,
      plugins: "noop", enabled: false, delay: 500})
    |> Builds.insert_project()

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
    assert Enum.count(all_builds) == 1
    Logger.debug "all_builds = #{inspect all_builds}"

    [build] = Builds.builds_for_project(project)
    assert build.coordinate == coord_s

    # check that the project is also updated
    p = Builds.get_project(project.id)
    assert p.last_build.id == build.id
  end
end
