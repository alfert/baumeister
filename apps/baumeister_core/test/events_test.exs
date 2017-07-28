defmodule EventsTest do
  use ExUnit.Case
  require Logger

  alias Baumeister.EventCenter
  alias Baumeister.EventLogger

  alias Baumeister.Test.TestListener

  test "EventCenter starts and stops" do
    {:ok, pid} = EventCenter.start_link(:anon)
    EventCenter.stop(pid)
    refute Process.alive?(pid)
  end

  test "observer start and stops" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, observer} = TestListener.start()

    GenStage.sync_subscribe(observer, to: ec)

    EventCenter.stop(ec)

    assert_down(observer)
    assert_down(ec)
  end

  test "send and consume an event" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, observer} = TestListener.start()
    GenStage.sync_subscribe(observer, to: ec)

    :ok = EventCenter.sync_notify(ec, "Hello")
    assert TestListener.get(observer) == ["Hello"]

    EventCenter.stop(ec)

    assert_down(observer)
    assert_down(ec)
  end

  test "send an event without consumer" do
    {:ok, ec} = EventCenter.start_link(:anon)

    # expect timeout after 2 ms
    catch_exit(EventCenter.sync_notify(ec, "Hello", 2))

    EventCenter.stop(ec)
    assert_down(ec)
  end

  test "send and consume several events" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, observer_1} = TestListener.start()
    GenStage.sync_subscribe(observer_1, to: ec)

    :ok = EventCenter.sync_notify(ec, "One")

    {:ok, observer_2} = TestListener.start()
    GenStage.sync_subscribe(observer_2, to: ec)

    :ok = EventCenter.sync_notify(ec, "Two")
    assert TestListener.get(observer_1) == ["One", "Two"]
    assert TestListener.get(observer_2) == ["Two"]

    EventCenter.stop(ec)

    assert_down(ec)
    assert_down(observer_1)
    assert_down(observer_2)
  end

  test "use the event logger" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, log} = EventLogger.start_link()
    GenStage.sync_subscribe(log, to: ec)
    {:ok, observer_1} = TestListener.start()
    GenStage.sync_subscribe(observer_1, to: ec)

    :ok = EventCenter.sync_notify(ec, "One")
    :ok = EventCenter.sync_notify(ec, "Two")

    assert TestListener.get(observer_1) == ["One", "Two"]

    EventCenter.stop(ec)
    assert_down(ec)
    assert_down(log)
    assert_down(observer_1)
  end

  # asserts that the given process is down with 100 ms
  defp assert_down(pid) when is_pid(pid) do
    Logger.debug "assert_down of #{inspect pid}"
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
  defp assert_down(process) do
    Logger.debug "assert_down of #{inspect process}"
    case GenServer.whereis(process) do
      p when is_pid(p) -> assert_down(p)
      nil -> Logger.debug "already unnamed: #{inspect process}"
    end
  end
end
