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
  # @moduletag capture_log: true

  # Setup the repository and the paths to their working spaces
  setup do
    Logger.info "Stop the Baumeister App for a fresh start"
    :ok = Application.stop(:baumeister)
    repos = GitRepos.make_temp_git_repo_with_some_content()
    Logger.info "Start the Baumeister Application"
    :ok= Application.ensure_started(:baumeister)
    Utils.wait_for fn -> nil != Process.whereis(Baumeister.ObserverSupervisor) end

    # Drain the event queue of old events.
    Logger.info "Clear the event center"
    Utils.wait_for fn -> 0 == EventCenter.clear() end

    {:ok, repos}
  end

  @tag timeout: 1_000
  test "add a new project", %{parent_repo_path: repo_url, parent_repo: repo} do
    # observe the git repo, but only 1 time, and wait 100 ms
    plugs = [{Take, 2}, {Git, repo_url}, {Delay, 100}]
    project = "baumeister_test"
    assert Config.keys() == []

    {:ok, listener} = TestListener.start()
    GenStage.sync_subscribe(listener, to: EventCenter)

    :ok = Baumeister.add_project(project, repo_url, plugs)

    # nothing has happend, the listener is still disabled
    assert [] == TestListener.get(listener)
    assert Config.keys() == [project]

    # enable the observer
    :ok = Baumeister.enable(project)
    Logger.info("Project is enabled, observer is running")
    :timer.sleep(100)
    {bmf, _local_os} = Utils.create_bmf("echo Hello")
    {:ok, _} = GitRepos.update_the_bmf(repo, bmf)

    # wait for some events
    # When running a larger test set, there are sometimes some old
    # events still in the queue. Therefore, we filter all events
    # for our current listener for `project`
    Utils.wait_for fn -> listener
      |> TestListener.get()
      |> Enum.any?(fn {_, a, _} -> a == :stopped_observer end)
      # |> Enum.any?(fn {_, a, _} -> a == :execute end)
    end
    {testl, rubbish} = listener
    |> TestListener.get()
    |> Enum.partition(fn {_, _, v} -> v == project end)
    l = testl
    |> Enum.map(fn {_, a, _} -> a end)

    assert l ==
      [:start_observer, :exec_observer, :exec_observer, :exec_observer, :stopped_observer]
    assert [] == rubbish
    if rubbish != [], do: Logger.error("rubbish is #{inspect rubbish}")

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
