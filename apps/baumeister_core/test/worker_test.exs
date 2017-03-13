defmodule Baumeister.WorkerTest do
  use ExUnit.Case

  require Logger

  alias Experimental.GenStage

  alias Baumeister.Coordinator
  alias Baumeister.Worker
  alias Baumeister.BaumeisterFile
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.Test.TestListener
  alias Baumeister.EventCenter
  alias Baumeister.EventLogger

  alias Baumeister.Test.Utils

  use PropCheck

  # Ensures that the coordinator is running and puts the pid in the environment
  setup do
    Application.ensure_started(:baumeister_core)
    Application.stop(:baumeister_coordinator)
    {:ok, pid} = Coordinator.start_link(name: Coordinator.name())
    {:ok,  _ec_pid} = EventCenter.start_link()
    {:ok, listener} = EventLogger.start_link([subscribe_to: Baumeister.EventCenter.name(),
      verbose: false])
    :global.sync()
    Logger.warn("Coordinator is #{inspect Coordinator.name()}")
    Logger.warn("Global registered names are: #{inspect :global.registered_names()}")

    m = wait_for_coordinator()
    assert [] == Coordinator.all_workers()
    assert 0 == EventCenter.clear()

    on_exit(fn ->
      Enum.each([pid, listener], fn p -> assert_down(p) end)
    end)
    {:ok, coordinator: pid}
  end

  def wait_for_coordinator(wait \\ 5)
  def wait_for_coordinator(0), do: flunk "Coordinator is not available :-("
  def wait_for_coordinator(wait) do
    m = GenServer.whereis(Coordinator.name())
    if not is_pid(m) do
      # only 1 ms, to let the scheduler recover. This is to
      # prevent a concurrency issue on Travis-CI
      Process.sleep(1)
      wait_for_coordinator(wait - 1)
    else
      m
    end
  end

  def make_tmp_coordinate() do
    tmp_dir = System.tmp_dir!
    NoopPlugin.make_coordinate(tmp_dir)
  end

  def wait_for_worker() do
    # registration is async, there we wait for that eveent
    Utils.wait_for(fn -> Enum.count(Coordinator.all_workers()) > 0 end)
  end

  @tag timeout: 1_000
  test "Start a worker", _env do
    {:ok, worker} = Worker.start_link()
    Logger.debug "Worker is started"
    assert is_pid(worker)
    assert Process.alive?(worker)
    wait_for_worker()

    all_workers = Coordinator.all_workers()
    Logger.debug "all workers: #{inspect all_workers}"
    assert Enum.any?(all_workers, fn(w) -> w.pid == worker end)
    # Process.exit(worker, :normal)
    remaining_workers = Coordinator.all_workers()
    assert not Enum.member?(remaining_workers, worker)
  end

  @tag timeout: 1_000
  test "Kill the coordinator", env do
    Process.flag(:trap_exit, true)
    {:ok, worker} = Worker.start_link()
    assert Process.alive?(worker)
    wait_for_worker()

    Logger.info "env is: #{inspect env}"
    Logger.debug "Registered workers: #{inspect Coordinator.all_workers}"
    Logger.debug "Killing Coordinator"
    Process.exit(env[:coordinator], :kill)

    assert_down(worker)
    assert_down(Coordinator.name)
  end

  test "Check for the capabilities" do
    l = Worker.detect_capabilities()
    assert is_map(l)
    assert Map.fetch!(l, :os) != nil
  end

  test "Find suitable workers for Elixir for the current OS" do
    {bmf, local_os} = Utils.create_parsed_bmf()
    capa = Worker.detect_capabilities
    capa_expected = %{:os => BaumeisterFile.canonized_values(local_os, :os), :mix => true}

    # check that at least all values of capa_expected are set in capa
    for {k, v} <- capa_expected do
      assert capa[k] == v, "key: #{inspect k}, expect: #{inspect v}, got: #{inspect capa[k]}"
    end
    assert Coordinator.match_worker?(capa, bmf)
  end

  test "execute a simple command" do
    {bmf, _local_os} = Utils.create_parsed_bmf("echo Hallo")
    coord = make_tmp_coordinate()
    {out, rc} = Worker.execute_bmf(coord, bmf)

    assert rc == 0
    # use trim to avoid problems with linefeeds
    assert String.trim(out) == "Hallo"
  end

  test "execute a failing command" do
    name =  "*"
    |> Path.wildcard()
    |> Enum.max_by(fn s -> String.length(s) end)
    |> Path.absname()
    non_existing_file = "#{name}-xxx"
    {bmf, _local_os} = Utils.create_parsed_bmf("type #{non_existing_file}")
    {out, rc} = Worker.execute_bmf(make_tmp_coordinate(), bmf)

    # return codes are different for various operating systems :-(
    assert rc != 0
    # use trim to avoid problems with linefeeds
    assert String.trim(out) != ""
    # in the error message the file name should appear
    assert String.contains?(out, non_existing_file)
  end

  test "execute a simple command from a Worker process" do
    {bmf, _local_os} = Utils.create_parsed_bmf("echo Hallo")
    {:ok, worker} = Worker.start_link()
    Logger.debug "Worker is started"

    {:ok, ref} = Worker.execute(worker, make_tmp_coordinate(), bmf)
    assert_receive {:executed, {_out, 0, ^ref}}
  end

  test "execute a failing command from a Worker process" do
    name = "*"
    |> Path.wildcard()
    |> Enum.max_by(fn s -> String.length(s) end)
    |> Path.absname()
    non_existing_file = "#{name}-xxx"
    {bmf, _local_os} = Utils.create_parsed_bmf("type #{non_existing_file}")
    {:ok, worker} = Worker.start_link()
    Logger.debug "Worker is started"

    {:ok, ref} = Worker.execute(worker, make_tmp_coordinate(), bmf)

    # return codes are different for various operating systems :-(
    assert_receive {:executed, {out, rc, ^ref}}
    # return codes are different for various operating systems :-(
    assert rc != 0
    # use trim to avoid problems with linefeeds
    assert String.trim(out) != ""
    # in the error message the file name should appear
    assert String.contains?(out, non_existing_file)
  end

  @tag timeout: 1_000
  test "execute a command via the coordinator", _env do
    {bmf, _local_os} = Utils.create_parsed_bmf("echo Hallo")
    coord = make_tmp_coordinate()
    {:ok, listener} = TestListener.start()
    GenStage.sync_subscribe(listener, to: EventCenter.name())
    {:ok, _worker} = Worker.start_link()
    wait_for_worker()
    Logger.debug "Worker is started"

    {:ok, _ref} = Coordinator.add_job(coord, bmf)
    ################
    #
    # Why is the event sent to the coordinator? Only
    # for testing purposes?
    #
    #################
    # wait for some events
    Utils.wait_for fn -> length(TestListener.get(listener)) >= 6 end
    # consider only worker messages
    l = listener
    |> TestListener.get()
    |> Enum.filter(fn {w, a, _} -> w == :worker and a == :execute end)
    |> Enum.map(fn {_, _, data} -> data end)

    assert l ==
      [{:start, coord}, {:ok, coord}, {:log, coord, "Hallo\n"}]
  end

  ####################
  #
  # Add tests with propcheck to run various tasks with different
  # runtimes, ideally also in parallel
  #
  # Extra long timeout since sometimes it does fit into 1 minute
  ####################
  @tag timeout: 120_000
  property "run many worker executions", [:verbose] do
    {:ok, worker} = Worker.start_link()
    wait_for_worker()
    Logger.debug "Worker is started"
    # use size to achieve smaller lists
    forall delays <- vector(10, float(0.0,0.1))  do
      returns = delays
      |> Stream.map(fn f -> Utils.create_parsed_bmf("sleep #{f} && echo Hallo") end)
      # |> Stream.map(fn f -> create_bmf("echo Hallo")end)
      |> Enum.map(fn {bmf, _} -> Worker.execute(worker, make_tmp_coordinate(), bmf) end)
      |> Enum.map(fn {:ok, ref} -> receive do
          {:executed, {_, 0, ^ref}} = msg -> msg
         end
      end)
      Logger.warn("Returns = #{inspect returns}")
      Logger.warn("Delays  = #{inspect delays}")
      test_result = (Enum.count(returns) == Enum.count(delays))
      test_result
      |> measure("Statistics about Delays", delays)
      |> collect(Enum.sum(delays))
    end
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
