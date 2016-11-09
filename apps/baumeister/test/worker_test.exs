defmodule Baumeister.WorkerTest do
  use ExUnit.Case

  require Logger

  alias Baumeister.Coordinator
  alias Baumeister.Worker
  alias Baumeister.BaumeisterFile


  # Ensures that the coordinator is running and puts the pid in the environment
  setup do
    Application.ensure_started(:baumeister)
    m = wait_for_coordinator
    {:ok, coordinator: m}
  end

  def wait_for_coordinator(wait\\ 5)
  def wait_for_coordinator(0), do: assert "Coordinator is not available :-("
  def wait_for_coordinator(wait) do
    m = GenServer.whereis(Coordinator.name)
    if not is_pid(m) do
      # only 1 ms, to let the scheduler recover. This is to
      # prevent a concurrency issue on Travis-CI
      Process.sleep(1)
      wait_for_coordinator(wait - 1)
    else
      m
    end
  end

  @tag timeout: 1_000
  test "Start a worker", _env do
    {:ok, worker} = Worker.start_link()
    Logger.debug "Worker is started"
    assert is_pid(worker)
    assert Process.alive?(worker)
    all_workers = Coordinator.workers()
    Logger.debug "all workers: #{inspect all_workers}"
    assert Enum.any?(all_workers, fn(w) -> w.pid == worker end)
    Process.exit(worker, :normal)
    remaining_workers = Coordinator.workers()
    assert not Enum.member?(remaining_workers, worker)
  end

  @tag timeout: 1_000
  test "Kill the coordinator", env do
    Process.flag(:trap_exit, true)
    {:ok, worker} = Worker.start_link()
    assert Process.alive?(worker)
    ref = Process.monitor(GenServer.whereis(Coordinator.name))
    ref_worker = Process.monitor(worker)

    Logger.info "env is: #{inspect env}"
    Logger.debug "Registered workers: #{inspect Coordinator.workers}"
    Logger.debug "Killing Coordinator"
    Process.exit(env[:coordinator], :kill)

    # Coordinator is down
    assert_receive({:DOWN, ^ref, :process, _, _})
    # Worker goes down
    assert_receive({:DOWN, ^ref_worker, :process, _, _})
    refute Process.alive?(worker)
  end

  test "Check for the capabilities" do
    l = Worker.detect_capabilities()
    assert is_map(l)
    assert Map.fetch!(l, :os) != nil
  end

  test "Find suitable workers for Elixir on macOS" do
    {_, local_os} = :os.type()
    bmf = """
      os: #{local_os |> Atom.to_string}
      language: elixir
    """ |> BaumeisterFile.parse!
    {:ok, worker} = Worker.start_link()
    Logger.debug "Worker is started"
    capa = Worker.detect_capabilities
    assert %{:os => :macos, :mix => true} = capa
    assert Coordinator.match_worker?(capa, bmf)
  end

end
