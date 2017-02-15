defmodule BaumeisterWeb do
  use Application

  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(type, args) do
    import Supervisor.Spec

    Logger.info("BaumeisterWeb.start(type=#{inspect type}, args=#{inspect args})")

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(BaumeisterWeb.Repo, []),
      # Start the endpoint when the application starts
      supervisor(BaumeisterWeb.Endpoint, []),
      # Start your own worker by calling: BaumeisterWeb.Worker.start_link(arg1, arg2, arg3)
      # worker(BaumeisterWeb.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BaumeisterWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BaumeisterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @doc """
  Different Start Phases for configuring and starting
  """
  def start_phase(:mnesia_up, _, _) do
    Logger.info("BaumeisterWeb.start_phase(:mnesia_up, _, _)")
    BaumeisterWeb.Release.Tasks.create_mnesia_db()
    BaumeisterWeb.Release.Tasks.migrate()
    :ok
  end
  def start_phase(start_phase, start_type, args) do
    Logger.info("BaumeisterWeb.start_phase(start_phase=#{inspect start_phase}, "
        <> "start_type=#{inspect start_type}, args=#{inspect args})")
    :ok
  end
end
