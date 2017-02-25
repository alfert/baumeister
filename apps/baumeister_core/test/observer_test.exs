defmodule Baumeister.ObserverTest do
  use ExUnit.Case

  require Logger
  @moduletag capture_log: true

  alias Baumeister.Test.TestListener
  alias Baumeister.Test.Utils
  alias Experimental.GenStage
  alias Baumeister.EventCenter

  alias Baumeister.Observer
  alias Baumeister.Observer.FailPlugin
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.Observer.Take
  alias Baumeister.Observer.Delay

  setup context do
    Logger.info("setup: context = #{inspect context}")
    sup_name = Baumeister.Supervisor
    opts = [strategy: :one_for_one, name: sup_name]
    children = Baumeister.App.setup_coordinator()
    Logger.info "ObserverTest.setup: Stopping Supervisor"
    if GenServer.whereis(sup_name) != nil, do: :ok = Supervisor.stop(sup_name)
    Logger.info "ObserverTest.setup: (Re)starting Supervisor"
    {:ok, sup_pid} = Supervisor.start_link(children, opts)
    counts = Supervisor.count_children(sup_pid)
    assert counts[:specs] == counts[:active]

    # need process flag, because Observer will crash
    Process.flag(:trap_exit, true)
    {:ok, listener} = TestListener.start()
    GenStage.sync_subscribe(listener, to: Baumeister.EventCenter.name())
    # set the observer name to the test name
    {:ok, pid} = Observer.start_link(Atom.to_string(context[:test]))
    assert is_pid(pid)

    # Let the listener drain the event queue of old events.
    Utils.wait_for fn -> 0 == EventCenter.clear() end
    # wait_for fn -> 0 == TestListener.clear(listener) end

    # merge this with the context
    [pid: pid, listener: listener]
  end

  @tag timeout: 1_000
  test "observe with a failing plugin", context do
    pid = context[:pid]
    listener = context[:listener]

    Observer.configure(pid, FailPlugin, :ok)
    :ok = Observer.run(pid)

    Utils.wait_for fn -> length(TestListener.get(listener)) >= 3 end

    l = listener
    |> TestListener.get()
    |> Enum.take(3)
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
    name = Atom.to_string(context[:test])
    bmf = """
    command: echo "Ja, wir schaffen das"
    """

    Observer.configure(pid, [{NoopPlugin, {"file:///", bmf}},{Take, 2}])
    TestListener.clear(listener)
    :ok = Observer.run(pid)

    # wait until at least 5 observer related messages arrive
    Utils.wait_for fn -> listener
      |> TestListener.get()
      |> Enum.filter(fn {_, _, n} -> n == name end)
      |> Enum.count() >= 5 end
    l = TestListener.get(listener)

    plug_events = l
    |> log_inspect()
    |> Enum.filter(fn {_, _, n} -> n == name end)
    |> log_inspect()
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

    Utils.wait_for fn -> length(TestListener.get(listener)) >= 3 end

    l = listener
    |> TestListener.get()
    |> Enum.take(3)
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

    Observer.configure(pid, [{NoopPlugin, {"file:///", bmf}}, {Delay, 50}])
    TestListener.clear(listener)
    :ok = Observer.run(pid)

    Utils.wait_for fn -> length(TestListener.get(listener)) >= 2 end
    Observer.stop(pid, :stop)

    # take only the first two elements, since noop is extremely fast
    # and produces a huge amount of events.
    l = listener
    |> TestListener.get()
    |> Enum.take(2)
    assert [{_, :start_observer, _}, {_, :exec_observer, _}] = l
  end

  def log_inspect(value, level \\ :info) do
    apply(Logger, :bare_log, [level, "#{inspect value}"])
    value
  end

end
