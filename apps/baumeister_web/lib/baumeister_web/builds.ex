defmodule BaumeisterWeb.Builds do

  @moduledoc """
  This is a bounded context `Builds` for accessing projects together
  with their builds. Essentially, it abstracts the way of joining
  projects and builds instead of accessing both directly
  via an Ecto.Repo from a controller.

  TODO:

  * [x] Project as in Builds.Project with cached `last_build` values. This
    used for Showing a simple project list (`list_projects()`).
  * [x] Project with embedded Build-Schema.  Used for the list of all builds
    of a project. Read-only. Created by joining in-memory the builds of a
    project.
  * [ ] Build with a Log-Entry. Used for the detailed view of a single build.
  * [x] Create/Update Build of a project, used by BuildListener. Calculates
    the cached `last_build` values.

  """

  import Ecto.Query, only: [from: 2]
  alias BaumeisterWeb.Repo
  require Logger

  alias BaumeisterWeb.Builds.Project
  alias BaumeisterWeb.Builds.Build
  alias BaumeisterWeb.ProjectBridge
  alias BaumeisterWeb.Web.Project, as: WP
  alias BaumeisterWeb.Web.Build, as: WB
  alias Ecto.Changeset
  alias Ecto.Multi
  alias Baumeister.BuildEvent

  @doc """
  Inserts the project into the database and the baumeister coordinator.
  It is excpected that `last_build` is empty and that no `builds` are
  embedded: A new project has no build yet.
  """
  @spec insert_project(Changeset.t) :: {:ok, Project.t} | {:error, any}
  def insert_project(p_changeset) do
    changeset = validate_no_values(p_changeset, [:last_build, :builds])
    # Make a downcast from Project to WP and insert the data
    do_insert_project(changeset)
  end

  @spec do_insert_project(Changeset.t) :: {:ok, Project.t} | {:error, Changeset.t}
  defp do_insert_project(%Changeset{errors: []} = p_changeset) do
    changeset = WP.changeset(%WP{}, p_changeset.changes)
    case Repo.insert(changeset) do
      {:ok, project} ->
        case ProjectBridge.add_project_to_coordinator(project) do
          :ok -> enabled = project.enabled
                 ^enabled = ProjectBridge.set_status(project)
                 {:ok, convert_up project}
          {:error, msg} ->
            Logger.error("Error inserting project into core: #{inspect changeset}")
            Repo.delete!(project)
            {:error, Ecto.Changeset.add_error(%{changeset | action: :insert}, :name, msg)}
        end
      {:error, new_changeset} -> {:error, new_changeset}
    end
  end
  defp do_insert_project(p_changeset) do
    {:error, p_changeset}
  end

  @doc """
  Validates that the given fields have no values or do not exist in the changeset.
  """
  @spec validate_no_values(Changeset.t, atom | [atom]) :: Changeset.t
  def validate_no_values(changeset, field) when is_atom(field),
    do: validate_no_values(changeset, [field])
  def validate_no_values(changeset, fields) do
    fields
    |> Enum.reduce(changeset, fn f, chs ->
        case Changeset.fetch_field(chs, f) do
          :error -> chs # field is not there
          {:data, :nil} -> chs # embeds_one with no value (default)
          {:data, []} -> chs # embeds_may with no values (default)
          {origin, v} when origin in [:data, :changes] ->
            m = "Error: Field #{inspect f} has value #{inspect v} but no value allowed"
            Logger.error m
            Changeset.add_error(%{chs | action: :insert}, :name, m)
        end
      end)
  end

  @doc """
  Converts the structs from lower abstraction into their counterparts
  of the Builds Context.
  """
  @spec convert_up(WP.t|WB.t) :: Project.t | Build.t
  defp convert_up(p = %WP{}) do
    fields = [:name, :url, :plugins, :enabled, :delay, :id,
      :updated_at, :inserted_at]
    |> Enum.map(fn f -> {f, Map.get(p, f)} end)
    new_p = struct!(%Project{}, fields)
    if is_nil(p.last_build_id) do
      new_p
    else
      # Logger.debug "convert_up: load last_build #{p.last_build_id}"
      last_build = Repo.get_by(WB, [number: p.last_build_id, project_id: p.id]) |> convert_up
      # Logger.debug "last_build is #{inspect last_build}"
      %Project{new_p | last_build: last_build}
    end
  end
  defp convert_up(b = %WB{}) do
    fields = [:number, :log, :coordinate, :config, :status, :id,
      :updated_at, :inserted_at, :project_id]
    |> Enum.map(fn f -> {f, Map.get(b, f)} end)
    struct!(%Build{}, fields)
  end
  defp convert_up(nil), do: nil

  @doc """
  Returns all projects.
  """
  @spec list_projects() :: [Project.t]
  def list_projects() do
    Repo.all(WP) |> Enum.map &convert_up/1
  end

  @doc """
  Returns all builds belonging to the project.
  """
  @spec builds_for_project(Project.t) :: [Build.t]
  def builds_for_project(project) do
    q = from(b in Build,
        where: b.project_id == ^project.id,
        order_by: [desc: b.number])
    Repo.all(q)
  end


  @doc """
  Gets a project by its id.
  """
  @spec get_project(integer) :: Project
  def get_project(id) when is_integer(id) do
    Repo.get!(WP, id)
    |> convert_up()
  end

  @doc """
  Creates a new build from the build event and stores into the database.
  The project is updated accordingly. If the referenced project does
  not exist, the call fails.
  """
  @spec create_build_from_event(BuildEvent.t) :: {:ok, any} | {:error, any}
  def create_build_from_event(ev = %BuildEvent{build_counter: counter, coordinate: coord}) do
    Logger.debug("create_build_from_event with ev=#{inspect ev}")
    project = Repo.get_by!(WP, name: coord.project_name)
    Logger.debug("Found project: #{inspect project}")
    build_changeset = project
    |> create_build(counter)
    |> WB.changeset(summerize_build_event(ev))
    Logger.debug("build changeset: #{inspect build_changeset}")
    project_changeset = WP.changeset(project, %{last_build_id: counter})
    {:ok, b} = Repo.insert_or_update(build_changeset)
    {:ok, _p} = Repo.update(project_changeset)
    {:ok, convert_up b}
  end

  @doc """
  Creates or retrieves an `Build` for the given `project` and the given
  `build_counter`. If there already exists a build entity in the database,
  it is returned otherwise a new build struct is created.
  """
  @spec create_build(WP.t, integer) :: Build.t
  defp create_build(project = %WP{}, build_counter) do
    case Repo.get_by(WB, [project_id: project.id, number: build_counter]) do
      nil -> %WB{project_id: project.id, number: build_counter, id: nil}
      build -> build
    end
  end

  @doc """
  Transforms a build event to a build struct to used in a changeset.
  """
  @spec summerize_build_event(BuildEvent.t) :: %{atom => any}
  defp summerize_build_event(build_event = %BuildEvent{coordinate: coord}) do
    [coordinate: "#{inspect coord}",
      status: status(build_event),
      log: log(build_event)]
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Enum.into(%{})
  end

  @doc """
  Converts the status from the build event to the build struct
  """
  defp status(%BuildEvent{action: nil}), do: 0
  defp status(%BuildEvent{action: :start}), do: 1
  defp status(%BuildEvent{action: :result, data: :ok}), do: 2
  defp status(%BuildEvent{action: :result}), do: 3
  defp status(_), do: nil

  defp log(%BuildEvent{action: :log, data: log_data}), do: log_data
  defp log(_), do: nil

end
