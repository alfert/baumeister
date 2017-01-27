defmodule Baumeister.App do
  @moduledoc """
  The application module of Baumeister.
  """
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  use Application

  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = []

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Baumeister.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Creates the setup for a coordinator instance of Baumeister.
  """
  @spec setup_coordinator() :: [Supervisor.Spec.spec]
  def setup_coordinator() do
    import Supervisor.Spec, warn: false
    observer_spec = [worker(Baumeister.Observer, [], restart: :transient)]
    [
      # Starts a worker by calling: Baumeister.Worker.start_link(arg1, arg2, arg3)
      # worker(Baumeister.Worker, [arg1, arg2, arg3]),
      supervisor(Task.Supervisor, [[name: Baumeister.ObserverTaskSupervisor]]),
      supervisor(Supervisor, [observer_spec, [id: Baumeister.ObserverSupervisor,
        strategy: :simple_one_for_one, name: Baumeister.ObserverSupervisor]]),
      worker(Baumeister.Coordinator, [[name: Baumeister.Coordinator.name()]]),
      worker(Baumeister.EventCenter, []),
      worker(Baumeister.EventLogger, [[subscribe_to: Baumeister.EventCenter.name(), verbose: false]]),
      worker(Baumeister.Config, [Application.get_env(:baumeister, :persistence)])
    ]
  end

  @doc """
  Creates the setup for a worker instance of Baumeister.
  """
  @spec setup_worker() :: [Supervisor.Spec.spec]
  def setup_worker() do
    import Supervisor.Spec, warn: false
    [
      # Starts a worker by calling: Baumeister.Worker.start_link(arg1, arg2, arg3)
      worker(Baumeister.Worker, []),
    ]
  end

end
