defmodule Baumeister.ObserverTest do
  use ExUnit.Case

  require Logger
  @moduletag capture_log: true

  alias Baumeister.Test.TestListener
  alias Experimental.GenStage

  alias Baumeister.Observer
  alias Baumeister.Observer.FailPlugin
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.Observer.Take

  def wait_for(pred) do
    case pred.() do
      false ->
        Process.sleep(1)
        wait_for(pred)
      _ -> true
    end
  end

  setup context do
    IO.inspect(context)
    # need process flag, because Observer will crash
    Process.flag(:trap_exit, true)
    {:ok, listener} = TestListener.start()
    GenStage.sync_subscribe(listener, to: Baumeister.EventCenter)
    {:ok, pid} = Observer.start_link(context[:test])
    assert is_pid(pid)

    # merge this with the context
    [pid: pid, listener: listener]
  end

  @tag timeout: 1_000
  test "observe with a failing plugin", context do
    pid = context[:pid]
    listener = context[:listener]

    Observer.configure(pid, FailPlugin, :ok)
    :ok = Observer.run(pid)

    wait_for fn -> length(TestListener.get(listener)) >= 3 end

    l = TestListener.get(listener) |> Enum.take(3)
    assert length(l) == 3
    assert [{_, :start_observer, _}, {_, :exec_observer, _},
        {_, :failed_observer, _}] = l

    # It should really die, otherwise it's not implemented as it should
    Logger.debug "Test Observer"
    refute Process.alive?(pid)
  end

  @tag timeout: 1_000
  test "take and noop", context do
    pid = context[:pid]
    listener = context[:listener]
    name = context[:test]
    bmf = """
    command: echo "Ja, wir schaffen das"
    """

    Observer.configure(pid, [{NoopPlugin, {"file:///", bmf}},{Take, 2}])
    :ok = Observer.run(pid)

    wait_for fn -> length(TestListener.get(listener)) >= 3 end
    l = TestListener.get(listener)

    plug_events = l
    |> Enum.filter(
      fn {_, _, ^name} -> true
          _ -> false end)
    |> Enum.map(fn {_, action, _} -> action end)
    assert length(plug_events) >= 5
    assert [:start_observer,
      :exec_observer, :exec_observer, :exec_observer,
      :stopped_observer] = plug_events
  end

  @tag timeout: 1_000
  test "take and noop - premature end", context do
    pid = context[:pid]
    listener = context[:listener]
    bmf = """
    command: echo "Ja, wir schaffen das"
    """

    Observer.configure(pid, [{Take, 0}, {NoopPlugin, {"file:///", bmf}}])
    :ok = Observer.run(pid)

    wait_for fn -> length(TestListener.get(listener)) >= 3 end

    l = TestListener.get(listener) |> Enum.take(3)
    assert length(l) == 3
    assert [{_, :start_observer, _}, {_, :exec_observer, _}, {_, :stopped_observer, _}] = l
  end

  @tag timeout: 1_000
  test "noop", context do
    pid = context[:pid]
    listener = context[:listener]
    bmf = """
    command: echo "Ja, wir schaffen das"
    """

    Observer.configure(pid, [{NoopPlugin, {"file:///", bmf}}])
    :ok = Observer.run(pid)

    wait_for fn -> length(TestListener.get(listener)) >= 2 end

    # take only the first two elements, since noop is extremely fast
    # and produces a huge amount of events.
    l = TestListener.get(listener) |> Enum.take(2)
    assert [{_, :start_observer, _}, {_, :exec_observer, _}] = l
  end


end
