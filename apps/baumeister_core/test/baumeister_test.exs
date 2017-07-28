defmodule BaumeisterTest do
  require Logger
  use ExUnit.Case

  alias Baumeister.Test.TestListener
  alias Baumeister.Test.Utils
  alias Baumeister.EventCenter
  alias Baumeister.Worker
  alias Baumeister.Observer.Take
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.Observer.Delay
  alias Baumeister.BuildEvent

  doctest Baumeister
  doctest Baumeister.BaumeisterFile

  setup context do
    Logger.info("setup: context = #{inspect context}")
    sup_name = Baumeister.Supervisor
    opts = [strategy: :one_for_one, name: sup_name]
    children = Baumeister.App.setup_coordinator()
    Logger.info "ObserverTest.setup: Stopping Supervisor"
    if GenServer.whereis(sup_name) != nil, do: :ok = Supervisor.stop(sup_name)
    assert assert_down(sup_name)

    Logger.info "ObserverTest.setup: (Re)starting Supervisor"
    {:ok, sup_pid} = Supervisor.start_link(children, opts)
    counts = Supervisor.count_children(sup_pid)
    assert counts[:specs] == counts[:active]

    # need process flag, because Observer will crash
    # Process.flag(:trap_exit, true)
    {:ok, listener} = TestListener.start()
    Utils.wait_for fn -> GenServer.whereis(EventCenter.name()) != nil end
    GenStage.sync_subscribe(listener, to: EventCenter.name())

    # Let the listener drain the event queue of old events.
    Utils.wait_for fn -> 0 == EventCenter.clear() end

    on_exit(fn ->
      Enum.each([listener, EventCenter.name(), sup_pid],
        fn p -> assert_down(p) end)
    end)
    # merge this with the context
    [listener: listener]
  end

  @tag timeout: 1_000
  test "observer and buildmaster run together", context do
    listener = context[:listener]
    project_name = Atom.to_string(context[:test])
    {bmf, _os} = Utils.create_bmf """
    echo "Ja, wir schaffen das"
    """
    url = "file:///"
    {:ok, worker} = Worker.start_link()

    TestListener.clear(listener)
    assert :ok == Baumeister.add_project(project_name, url,
      [{NoopPlugin, {url, bmf}}, {Delay, 50}, {Take, 1}])
    assert true == Baumeister.enable(project_name)

    # wait for first execution
    Utils.wait_for(fn -> listener
      |> TestListener.get()
      |> Enum.filter(&(match?(%BuildEvent{}, &1)))
      |> Enum.any?(fn %BuildEvent{action: a} -> a == :log end)
    end)
    Baumeister.disable(project_name)

    # consider only worker messages
    l = listener
    |> TestListener.get()
    |> Enum.filter(&(match?(%BuildEvent{}, &1)))
    |> Enum.map(fn be -> {be.action, be.coordinate, be.data} end)

    assert [{:start, coord, nil}, {:result, coord, :ok}, {:log, coord, "Ja, wir schaffen das\n"}] = l
    Process.exit(worker, :normal)
    assert assert_down(worker)
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
