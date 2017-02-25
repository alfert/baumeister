defmodule BaumeisterWeb.BuildChannelTest do
  use BaumeisterWeb.ChannelCase

  alias BaumeisterWeb.BuildChannel

  setup do
    {:ok, _, socket} =
      socket("user_id", %{some: :assign})
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

  test "broadcast a build event", %{socket: socket} do
    event = {:tester, :test_broadcast, :data}
    BuildChannel.broadcast_event(event)
    assert_broadcast "build_event", %{
      "role" => "tester", "action" => "test_broadcast", "step" => ":data"}
  end
end
