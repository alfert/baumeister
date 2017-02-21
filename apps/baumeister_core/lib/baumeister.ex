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
  @spec execute(Coordinate.t, BaumeisterFile.t) :: {:ok, reference} | {:error, any}
  def execute(coordinate, bmf) do
    Logger.info("Execute bmf #{inspect bmf} for coord #{inspect coordinate}")
    case Coordinator.add_job(coordinate, bmf) do
      {:ok, ref} -> {:ok, ref}
      {:unsupported_feature, feature} ->
        Logger.error("An unsupported feature <#{inspect feature}> was requested for coordinate #{inspect coordinate}")
        {:error, :unsupported_feature}
    end
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
      {:ok, _} -> {:error, "Project '#{project_name}' already exists"}
      _ ->
        :ok = Config.put(project_name,
          %__MODULE__{name: project_name, url: url, plugins: plugin_list})
    end
  end

  @doc """
  Enables the project and let the observer do its work.
  """
  @spec enable(String.t) :: boolean
  def enable(project_name) do
    with {:ok, project} <- Config.config(project_name),
      false <- project.enabled
      do
        {:ok, observer} = Supervisor.start_child(Baumeister.ObserverSupervisor,
          [project_name])
        # spawn a process that monitors the observers and
        # updates the status in the config database
        _pid = spawn(fn -> ref = Process.monitor(observer)
          receive do
            {:DOWN, ^ref, :process, _whatever_pid, _reason} -> put_disabled_project(project_name)
          end
        end)
        :ok = Observer.configure(observer, project.plugins)
        :ok = Config.put(project_name, %__MODULE__{project | enabled: true,
          observer: observer})
        :ok = Observer.run(observer)
        true
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
  @spec disable(String.t) :: boolean | :error
  def disable(project_name) do
    with {:ok, project} = Config.config(project_name),
      true <- project.enabled
      do
        :ok = Observer.stop(project.observer, :stop)
        put_disabled_project(project_name, project)
      end
  end

  @doc """
  Disables and deletes a project. Returns `:error` if the project does
  not exist.
  """
  @spec delete(String.t) :: :ok | :error
  def delete(project_name) do
    unless :error == disable(project_name), do:
      Config.remove(project_name)
  end

  @doc """
  Updates the project. For that reason the project is disabled,
  to stop observers and workers. After that, the project is updated
  in the configuration and and the project in enabled again, if it
  enabled before.
  """
  def update(project_name, url, plugin_list) do
    case Config.config(project_name) do
      {:ok, project} ->
        disable(project_name)
        :ok = Config.put(project_name,
          %__MODULE__{name: project_name, url: url, plugins: plugin_list})
        enable(project.enabled)
      _ -> add_project(project_name, url, plugin_list)
    end
  end
end
