defmodule Test.BM.CoordinatorTest do
  use ExUnit.Case

  alias Baumeister.Config
  alias Baumeister.Observer.Delay
  alias Baumeister.Observer.Git
  alias Baumeister.Observer.Take
  alias Baumeister.EventCenter
  alias Baumeister.Worker
  alias Baumeister.BuildEvent

  alias Baumeister.Test.GitRepos
  alias Baumeister.Test.TestListener
  alias Baumeister.Test.Utils

  alias Experimental.GenStage

  require Logger
  # @moduletag capture_log: true

  # Setup the repository and the paths to their working spaces
  setup do
    Logger.info "Stop the Baumeister App for a fresh start"
    Application.stop(:baumeister_coordinator)
    repos = GitRepos.make_temp_git_repo_with_some_content()
    Logger.info "Start the Baumeister Application"
    :ok = Application.ensure_started(:baumeister_core)
    {:ok, _} = Application.ensure_all_started(:baumeister_coordinator)
    Utils.wait_for fn -> nil != Process.whereis(Baumeister.ObserverSupervisor) end

    Logger.info "Start a worker"
    {:ok, worker} = Worker.start_link()
    Logger.info "Worker process is #{inspect worker}"
    # Wait for registration
    Utils.wait_for fn -> Enum.count(Baumeister.Coordinator.all_workers()) > 0 end

    # Drain the event queue of old events.
    Logger.info "Clear the event center"
    Utils.wait_for fn -> 0 == EventCenter.clear() end

    on_exit(fn ->
      Application.stop(:baumeister_coordinator)
      [worker, Baumeister.ObserverSupervisor]
      |> Enum.map(fn p when is_pid(p) -> p
                     p -> Process.whereis(p)
         end)
      |> Enum.each(fn p -> assert_down(p) end)
    end)
    {:ok, repos}
  end

  @tag timeout: 1_000
  test "add a new project", %{parent_repo_path: repo_url, parent_repo: repo} do
    # observe the git repo, but only 1 time, and wait 100 ms
    plugs = [{Take, 2}, {Git, repo_url}, {Delay, 100}]
    project = "baumeister_test"
    assert Config.keys() == []
    # ensure that there are no events in the event center
    Utils.wait_for fn -> 0 == EventCenter.clear() end

    {:ok, listener} = TestListener.start()
    GenStage.sync_subscribe(listener, to: EventCenter.name())

    :ok = Baumeister.add_project(project, repo_url, plugs)

    # nothing has happend, the listener is still disabled
    assert [] == TestListener.get(listener)
    assert Config.keys() == [project]

    # enable the observer
    true = Baumeister.enable(project)
    Logger.info("Project is enabled, observer is running")
    :timer.sleep(100)
    {bmf, _local_os} = Utils.create_bmf("echo Hello")
    {:ok, _} = GitRepos.update_the_bmf(repo, bmf)

    # wait for some events
    # When running a larger test set, there are sometimes some old
    # events still in the queue. Therefore, we filter all events
    # for our current listener for `project`
    Utils.wait_for fn ->
      {build_events, obs_event} = TestListener.get(listener)
      |> Enum.partition(fn ev -> match?(%BuildEvent{}, ev) end)
      worker_ev_cnt = Enum.count(build_events)
      stopped_observer? = Enum.any?(obs_event, fn {_, a, _} -> a == :stopped_observer end)

      # And the condition
      (stopped_observer? and (worker_ev_cnt >= 3))
    end

    {w_list, ol} = listener
    |> TestListener.get()
    |> Enum.partition(fn ev -> match?(%BuildEvent{}, ev) end)

    obs_actions = ol
    |> Enum.map(fn {_, a, _} -> a end)
    |> Enum.reject(&(&1 == :register))
    worker_actions = Enum.map(w_list, &(&1.action))

    assert obs_actions ==
      [:start_observer, :exec_observer, :exec_observer, :execute, :spawned, :exec_observer, :stopped_observer]

    assert worker_actions == [:start, :result, :log]

    # After a stop, the project is disabled
    {:ok, p} = Config.config(project)
    assert_down(p.observer)
    assert false == p.enabled
  end

  test "Ensure that all required processes are running" do
    obs_sup = Process.whereis(Baumeister.ObserverSupervisor)
    assert nil != obs_sup
    assert 0 == Supervisor.count_children(obs_sup).active
    assert nil != Process.whereis(Baumeister.ObserverTaskSupervisor)
  end

  # asserts that the given process is down with 100 ms
  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
