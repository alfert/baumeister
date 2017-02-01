defmodule EventsTest do
  use ExUnit.Case

  alias Experimental.GenStage
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
    # GenStage.stop(observer)
    EventCenter.stop(ec)
    # give the observer some time to die properly
    Process.sleep(1)
    refute Process.alive?(observer)
  end

  test "send and consume an event" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, observer} = TestListener.start()
    GenStage.sync_subscribe(observer, to: ec)

    :ok = EventCenter.sync_notify(ec, "Hello")
    assert TestListener.get(observer) == ["Hello"]

    EventCenter.stop(ec)
  end

  test "send an event without consumer" do
    {:ok, ec} = EventCenter.start_link(:anon)

    # expect timeout after 2 ms
    catch_exit(EventCenter.sync_notify(ec, "Hello", 2))

    EventCenter.stop(ec)
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
  end
end
