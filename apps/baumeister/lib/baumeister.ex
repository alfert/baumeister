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


  defstruct name: "", url: "", plugins: [], enabled: false, observer: nil

  @doc """
  Executes the commands defined in the BaumeisterFile on a node that
  fits to the settings (e.g. OS) and on which the repository at the
  Coordinate will be checked out.
  """
  @spec execute(Coordinate.t, BaumeisterFile.t) :: :ok
  def execute(_coord, _job) do
    :ok
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
        {:ok, observer} = Supervisor.start_child(Baumeister.ObserverSupervisor,
          [project_name])
        :ok = Observer.configure(observer, plugin_list)
        :ok = Config.put(project_name,
          %__MODULE__{name: project_name, url: url, plugins: plugin_list,
            observer: observer})
    end
  end

  @doc """
  Enables the project and let the observer do its work.
  """
  def enable(project_name) do
    with {:ok, project} = Config.config(project_name),
      false = project.enabled
      do
        :ok = Observer.run(project.observer)
      end
  end
end
