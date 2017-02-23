defmodule BaumeisterWeb.ProjectBridge do
  @moduledoc """
  The ProjectBridge connects the `BaumeisterWeb.Project` model with the
  project management from `:baumeister_core`. In particular, it translates
  between the project's plugins and the settable metadata from the Web UI.
  """
  alias Baumeister.Observer.DelayPlugin
  alias Baumeister.Observer.GitPlugin
  alias Baumeister.Observer.NoopPlugin
  alias BaumeisterWeb.Project

  require Logger

  @doc """
  Adds a project to the coordinator and prepares for the observers.
  """
  @spec add_project_to_coordinator(Project.t) :: :ok | {:error, any}
  def add_project_to_coordinator(project) do
    with {:ok, plugin_list} = plugins(project) do
      Baumeister.add_project(project.name, project.url, plugin_list)
    end
  end

  @doc "Enables or disables the project under control of the coordinator"
  @spec set_status(Project.t) :: :ok
  def set_status(%Project{enabled: true, name: name}) do
    Baumeister.enable(name)
  end
  def set_status(%Project{enabled: false, name: name}) do
    Baumeister.disable(name)
  end

  @doc """
  Updates the settings of project in the coordinator
  """
  def update(project = %Project{name: name, url: url, plugins: plugins}) do
    with {:ok, plugin_list} <- plugins(project),
      :ok <- Baumeister.update(project.name, project.url, plugin_list)
    do
      :ok
    end
  end

  @doc """
  Derives the list of plugins from the settings of a project
  """
  @spec plugins(Project.t) :: [Baumeister.Observer.plugin_config_t]
  def plugins(%Project{plugins: "Git", url: repo_url, delay: delay}) do
    {:ok, [{GitPlugin, repo_url}, {DelayPlugin, delay}]}
  end
  def plugins(_) do
    {:ok, [{NoopPlugin, {"no_url:///", "command: false"}}]}
  end

  @doc """
  Deletes the given `project` from Baumeister core coordinator.
  """
  @spec delete_project_from_coordinator!(Project.t) :: :ok | no_return
  def delete_project_from_coordinator!(project) do
    case Baumeister.delete(project.name) do
      :error -> Logger.error("Project #{inspect project.name} not available in Baumeister")
        :ok
      :ok -> set_status(project)
    end
  end

  def initialize_coordinator(all_projects) do
    all_projects
    |> Stream.each(fn project ->
        case add_project_to_coordinator(project) do
          {:error, msg} -> Logger.error "Cannot add project #{project.name} to the coordinator"
          :ok           -> set_status(project)
            Logger.info "Project #{project.name} loaded into the coordinator"
        end
      end)
    |> Stream.run()
  end

  def load_all_projects() do
    BaumeisterWeb.Repo.all(Project)
    |> initialize_coordinator()
  end
end
