defmodule BaumeisterTest do
  use ExUnit.Case
  doctest Baumeister
  doctest Baumeister.BaumeisterFile

  alias Baumeister.Config
  alias Baumeister.Observer.Delay
  alias Baumeister.Observer.Git
  alias Baumeister.Observer.FailPlugin
  alias Baumeister.Observer.NoopPlugin
  alias Baumeister.Observer.Take
  alias Baumeister.Test.GitRepos
  alias Baumeister.EventCenter
  alias Baumeister.Test.TestListener
  alias Baumeister.Test.Utils
  alias Experimental.GenStage

  require Logger
  @moduletag capture_log: true

  # Setup the repository and the paths to their working spaces
  setup do
    Logger.info "Stop the Observer Supervisor"
    :ok = Supervisor.stop(Baumeister.ObserverSupervisor, :normal)
    repos = GitRepos.make_temp_git_repo_with_some_content()
    assert nil != Process.whereis(Baumeister.ObserverSupervisor)

    # Drain the event queue of old events.
    Utils.wait_for fn -> 0 == EventCenter.clear() end

    {:ok, repos}
  end

  @tag timeout: 1_000
  test "add a new project", %{parent_repo_path: repo_url, parent_repo: repo} do
    # observe the git repo, but only 1 time, and wait 100 ms
    plugs = [{Delay, 100}, {Git, repo_url}, {Take, 1}]
    project = "baumeister_test"
    assert Config.keys() == []

    {:ok, observer} = TestListener.start()
    GenStage.sync_subscribe(observer, to: EventCenter)

    :ok = Baumeister.add_project(project, repo_url, plugs)

    # nothing has happend, the observer is still disabled
    assert [] == TestListener.get(observer)
    assert Config.keys() == [project]

    # enable the observer
    :ok = Baumeister.enable(project)

    {bmf, _local_os} = Utils.create_bmf("echo Hello")
    {:ok, _} = GitRepos.update_the_bmf(repo, bmf)

    # wait for some events
    Utils.wait_for fn -> length(TestListener.get(observer)) >= 4 end
    l = observer
    |> TestListener.get()
    |> Enum.map(fn {_, a, _} -> a end)

    assert l ==
      [:start_observer, :exec_observer, :exec_observer, :stopped_observer]

    # After a stop, the project is disabled
    {:ok, p} = Config.config(project)
    assert nil == p.observer
    assert false == p.enabled
  end

  test "Ensure that all required processes are running" do
    obs_sup = Process.whereis(Baumeister.ObserverSupervisor)
    assert nil != obs_sup
    assert 0 == Supervisor.count_children(obs_sup).active
    assert nil != Process.whereis(Baumeister.ObserverTaskSupervisor)
  end

end
