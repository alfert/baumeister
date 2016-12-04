defmodule Baumeister.ObserverTest do
  use ExUnit.Case

  require Logger

  alias Baumeister.Test.TestListener
  alias Experimental.GenStage

  alias Baumeister.Coordinator
  alias Baumeister.Worker
  alias Baumeister.BaumeisterFile
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

    wait_for fn -> length(TestListener.get(listener)) >= 2 end

    l = TestListener.get(listener)
    assert length(l) == 2
    assert [{_, :start_observer, _}, {_, :failed_observer, _}] = l

    # It should really die, otherwise it's not implemented as it should
    Logger.debug "Test Observer"
    refute Process.alive?(pid)
  end



  # GENERAL TODO:
  # * Allow the state of the observer change
  # * Introduce `:stop` as addition to `:ok` and `:error`
  # * Think carefully about nesting of plugins to enable
  #   timings, delays, ... Similar to the Plug-Concept.

  @tag timeout: 1_000
  test "take and noop", context do
    pid = context[:pid]
    listener = context[:listener]
    bmf = """
    command: echo "Ja, wir schaffen das"
    """

    Observer.configure(pid, [{Take, 1}, {NoopPlugin, {"file:///", bmf}}])
    #Observer.configure(pid, [{NoopPlugin, {"file:///", bmf}},{Take, 1}])
    :ok = Observer.run(pid)

    wait_for fn -> length(TestListener.get(listener)) >= 2 end

    l = TestListener.get(listener)
    assert length(l) == 2
    assert [{_, :start_observer, _}, {_, :failed_observer, _}] = l
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

    l = TestListener.get(listener)
    assert length(l) == 2
    assert [{_, :start_observer, _}, {_, :failed_observer, _}] = l
  end


end
