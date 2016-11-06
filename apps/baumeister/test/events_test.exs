defmodule EventsTest do
  use ExUnit.Case

  alias Experimental.GenStage
  alias Baumeister.EventCenter
  alias Baumeister.EventLogger

  defmodule TestObserver do
    @moduledoc """
    A simple observer for the Event Center
    """
    use GenStage

    def start(), do: GenStage.start_link(__MODULE__, :ok)
    def init(_), do: {:consumer, []}
    def handle_events(events, _, state) do
      {:noreply, [], state ++ events}
    end

    def get(stage), do: GenStage.call(stage, :get)
    def handle_call(:get, _, state), do: {:reply, state, [], state}
  end

  test "EventCenter starts and stops" do
    {:ok, pid} = EventCenter.start_link(:anon)
    EventCenter.stop(pid)
    refute Process.alive?(pid)
  end

  test "observer start and stops" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, observer} = TestObserver.start()

    GenStage.sync_subscribe(observer, to: ec)
    # GenStage.stop(observer)
    EventCenter.stop(ec)
    # give the observer some time to die properly
    Process.sleep(1)
    refute Process.alive?(observer)
  end

  test "send and consume an event" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, observer} = TestObserver.start()
    GenStage.sync_subscribe(observer, to: ec)

    :ok = EventCenter.sync_notify(ec, "Hello")
    assert TestObserver.get(observer) == ["Hello"]

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
    {:ok, observer_1} = TestObserver.start()
    GenStage.sync_subscribe(observer_1, to: ec)

    :ok = EventCenter.sync_notify(ec, "One")

    {:ok, observer_2} = TestObserver.start()
    GenStage.sync_subscribe(observer_2, to: ec)

    :ok = EventCenter.sync_notify(ec, "Two")
    assert TestObserver.get(observer_1) == ["One", "Two"]
    assert TestObserver.get(observer_2) == ["Two"]

    EventCenter.stop(ec)
  end

  test "use the event logger" do
    {:ok, ec} = EventCenter.start_link(:anon)
    {:ok, log} = EventLogger.start_link()
    GenStage.sync_subscribe(log, to: ec)
    {:ok, observer_1} = TestObserver.start()
    GenStage.sync_subscribe(observer_1, to: ec)

    :ok = EventCenter.sync_notify(ec, "One")
    :ok = EventCenter.sync_notify(ec, "Two")

    assert TestObserver.get(observer_1) == ["One", "Two"]

    EventCenter.stop(ec)
  end
end
