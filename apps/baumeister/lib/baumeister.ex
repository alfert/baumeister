defmodule Baumeister do

  alias Baumeister.BaumeisterFile
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Baumeister.Worker.start_link(arg1, arg2, arg3)
      # worker(Baumeister.Worker, [arg1, arg2, arg3]),
      supervisor(Task.Supervisor, [[name: Baumeister.ObserverSupervisor]]),
      worker(Baumeister.Coordinator, [[name: Baumeister.Coordinator.name()]]),
      worker(Baumeister.EventCenter, []),
      worker(Baumeister.EventLogger, [[subscribe_to: Baumeister.EventCenter, verbose: false]]),
      worker(Baumeister.Config, [Application.get_env(:baumeister, :persistence)])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Baumeister.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Executes the commands defined in the BaumeisterFile on a node that
  fits to the settings (e.g. OS) and on which the repository at the
  URL will be checked out.
  """
  @spec execute(String.t, BaumeisterFile.t) :: :ok
  def execute(_url, _job) do
    :ok
  end
end
