defmodule BaumeisterWeb do
  use Application

  @moduledoc """
  Application callback module. We use different start phases to
  separate out the initialization with mnesia updates from
  the regular operating mode.
  """

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
      worker(BaumeisterWeb.BuildListener, [[subscribe_to: Baumeister.EventCenter.name()]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BaumeisterWeb.Supervisor]
    Supervisor.start_link(children, opts)
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
    BaumeisterWeb.ProjectBridge.load_all_projects()
    :ok
  end
end
