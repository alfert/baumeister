defmodule BaumeisterWeb.BuildChannelTest do
  use BaumeisterWeb.ChannelCase

  alias BaumeisterWeb.BuildChannel
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.BuildEvent

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

  test "broadcast an old build event", %{socket: socket} do
    event = {:tester, :test_broadcast, :data}
    BuildChannel.broadcast_event(event)
    assert_broadcast "old_build_event", %{
      "role" => "tester", "action" => "test_broadcast", "step" => ":data"}
  end

  test "broadcast a build event", %{socket: socket} do
    coord = NoopPlugin.make_coordinate("/tmp")
    event = coord
      |> BuildEvent.new(1)
      |> BuildEvent.action(:log, "Hello")
    BuildChannel.broadcast_event(event)
    coord_s = "#{inspect coord}"
    assert_broadcast "build_event", %{
      "role" => "worker", "action" => "log", "data" => "\"Hello\"",
      "coordinate" => ^coord_s}
  end
end
