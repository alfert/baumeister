defmodule Baumeister.WorkerTest do
  use ExUnit.Case

  require Logger

  alias Baumeister.Coordinator
  alias Baumeister.Worker


  # Ensures that the coordinator is running and puts the pid in the environment
  setup do
    Application.ensure_started(:baumeister)
    m = GenServer.whereis(Coordinator.name)
    assert is_pid(m)
    {:ok, coordinator: m}
  end

  test "Start a worker", _env do
    {:ok, worker} = Worker.start_link()
    assert is_pid(worker)
    assert Process.alive?(worker)
    all_workers = Coordinator.workers()
    assert Enum.member?(all_workers, worker)
    Process.exit(worker, :normal)
    remaining_workers = Coordinator.workers()
    assert not Enum.member?(remaining_workers, worker)
  end

  test "Kill the coordinator", env do
    Process.flag(:trap_exit, true)
    {:ok, worker} = Worker.start_link()
    assert Process.alive?(worker)
    ref = Process.monitor(GenServer.whereis(Coordinator.name))

    Logger.info "env is: #{inspect env}"
    Process.exit(env[:coordinator], :kill)

    assert_receive({:DOWN, ^ref, :process, _, _})

    refute Process.alive?(worker)
  end

end
