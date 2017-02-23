defmodule Coordinator.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = Baumeister.App.setup_coordinator()
    worker = if node() == :nonode@nohost, do: Baumeister.App.setup_worker(), else: []
    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Coordinator.Supervisor]
    Supervisor.start_link(children ++ worker, opts)
  end
end
