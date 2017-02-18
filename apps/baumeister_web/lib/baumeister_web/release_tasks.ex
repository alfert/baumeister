defmodule BaumeisterWeb.Release.Tasks do
  @moduledoc """
  All tasks that should be run after a release is started.
  """

  require Logger

  @doc """
  Create the mnesia database.
  """
  def create_mnesia_db do
    Logger.info "Stopping Mnesia for creating the schema"
    Ecto.Mnesia.Storage.stop()

    # ensure the database directory
    dir = "#{Confex.get(:mnesia, :dir)}"
    dir = if Path.relative(dir), do: Path.expand(dir)
    Logger.info "Create the mnesia dir at: #{dir}"
    File.mkdir_p!(dir)

    if :mnesia.system_info(:use_dir) do
      Logger.info "Mnesia dir is in use already"
    else
      conf = Ecto.Mnesia.Storage.conf()
      Logger.info("Start Mnesia for Schema creation with conf: #{inspect conf}")
      # Ecto.Mnesia.Storage.start()

      Logger.info "Create Schema with storage up"
      case Ecto.Mnesia.Storage.storage_up(conf) do
        :ok -> Logger.info "Schema created"
        {:ok, :already_created} -> Logger.info "Schema was already created"
        {:error, :already_up} -> Logger.error "Mnesia was already up -> continue!"
      end
      # stop mnesia for restarting later when the application starts
      Logger.info "Stopping Mnesia after schema creation"
      Ecto.Mnesia.Storage.stop()
    end
  end

  @doc """
  Run the migrations on the database.
  """
  def migrate do
    #Logger.info "Ensure that :baumeister_web is started"
    # {:ok, _} = Application.ensure_all_started(:baumeister_web)
    Logger.info("Start Mnesia for migration")
    :ok = Ecto.Mnesia.Storage.start()
    Logger.info "Waiting for all tables to come back"
    :ok = :mnesia.wait_for_tables(:mnesia.system_info(:tables), 5_000)

    path = Application.app_dir(:baumeister_web, "priv/repo/migrations")
    Logger.info "Run migrations from dir #{path}"
    Ecto.Migrator.run(BaumeisterWeb.Repo, path, :up, all: true)
  end
end
