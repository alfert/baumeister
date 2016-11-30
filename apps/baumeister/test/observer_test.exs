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

  def wait_for(pred) do
    case pred.() do
      false ->
        Process.sleep(1)
        wait_for(pred)
      _ -> true
    end
  end

  @tag timeout: 1_000
  test "observe with a failing plugin" do
    # need process flag, because Observer will crash
    Process.flag(:trap_exit, true)
    {:ok, listener} = TestListener.start()
    GenStage.sync_subscribe(listener, to: Baumeister.EventCenter)
    {:ok, pid} = Observer.start_link(FailPlugin, :ok)
    assert is_pid(pid)

    :ok = Observer.run(pid)
    # Process.sleep(10)
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

end
