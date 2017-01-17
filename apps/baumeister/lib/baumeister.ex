defmodule Baumeister do

  @moduledoc """
  This is the connecting module, that combines the observer part of Baumeister
  with the job execution part. It also provides the main API for Baumeister
  in terms of embedding it into other applications, such as a Phoenix-based
  Web UI.
  """
  alias Baumeister.BaumeisterFile
  alias Baumeister.Observer.Coordinate
  alias Baumeister.Observer
  alias Baumeister.Config
  alias Baumeister.Coordinator

  require Logger

  defstruct name: "", url: "", plugins: [], enabled: false, observer: nil

  @doc """
  Executes the commands defined in the BaumeisterFile on a node that
  fits to the settings (e.g. OS) and on which the repository at the
  Coordinate will be checked out.
  """
  @spec execute(Coordinate.t, BaumeisterFile.t) :: :ok
  def execute(coordinate, bmf) do
    Logger.info("Execute bmf #{inspect bmf} for coord #{inspect coordinate}")
    {:ok, ref} = Coordinator.add_job(coordinate, bmf)
  end

  @doc """
  Adds a new project.

  The `project_name` is the key and must be unique and not used. The `url`
  must be a valid Git URL, since Git is the only supported repository observer.
  The `plugin_list` configures the list of observer plugins. They must be given
  in the wished order of execution.
  """
  @spec add_project(String.t, String.t, [Observer.plugin_config_t]) :: :ok
  def add_project(project_name, url, plugin_list) when is_binary(project_name) do
    case Config.config(project_name) do
      {:ok, _} -> {:error, "Project #{project_name} already exists"}
      _ ->
        :ok = Config.put(project_name,
          %__MODULE__{name: project_name, url: url, plugins: plugin_list})
    end
  end

  @doc """
  Enables the project and let the observer do its work.
  """
  def enable(project_name) do
    with {:ok, project} = Config.config(project_name),
      false = project.enabled
      do
        {:ok, observer} = Supervisor.start_child(Baumeister.ObserverSupervisor,
          [project_name])
        # spawn a process that monitors the observers and
        # updates the status in the config database
        pid = spawn(fn -> ref = Process.monitor(observer)
          receive do
            {:DOWN, ^ref,:process, _pid, _reason} -> put_disabled_project(project_name)
          end
        end)
        :ok = Observer.configure(observer, project.plugins)
        :ok = Config.put(project_name, %__MODULE__{project | enabled: true,
          observer: observer})
        :ok = Observer.run(observer)
      end
  end

  defp put_disabled_project(project_name) do
    {:ok, project} = Config.config(project_name)
    put_disabled_project(project_name, project)
  end
  defp put_disabled_project(project_name, project) do
    :ok = Config.put(project_name, %__MODULE__{project | enabled: false,
      observer: nil})
  end

  @doc """
  Disables the project and stop the observer's work.
  """
  def disable(project_name) do
    with {:ok, project} = Config.config(project_name),
      true = project.enabled
      do
        :ok = Observer.stop(project.observer, :stop)
        put_disabled_project(project_name, project)
      end
  end
end
