defmodule BaumeisterWeb.Builds do

  @moduledoc """
  This is a bounded context `Builds` for accessing projects together
  with their builds. Essentially, it abstracts the way of joining
  projects and builds instead of accessing both directly
  via an Ecto.Repo from a controller.

  TODO:

  * [x] Project as in Builds.Project with cached `last_build` values. This
    used for Showing a simple project list (`list_projects()`).
  * [ ] Project with embedded Build-Schema.  Used for the list of all builds
    of a project. Read-only. Created by joining in-memory the builds of a
    project.
  * [ ] Build with a Log-Entry. Used for the detailed view of a single build.
  * [ ] Create/Update Build of a project, used by BuildListener. Calculates
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
    fields = [:name, :url, :plugins, :enabled, :delay, :id, :updated_at, :inserted_at]
    |> Enum.map(fn f -> {f, Map.get(p, f)} end)
    new_p = struct!(%Project{}, fields)
    if is_nil(p.last_build_id) do
      new_p
    else
      last_build = Repo.get(WB, p.last_build_id) |> convert_up
      %Project{new_p | last_build: last_build}
    end
  end
  defp convert_up(b = %WB{}) do
    fields = [:number, :log, :coordinate, :config, :status, :id, :updated_at, :inserted_at]
    |> Enum.map(fn f -> {f, Map.get(b, f)} end)
    struct!(%Build{}, fields)
  end

  @doc """
  Returns all projects.
  """
  @spec list_projects() :: [Project.t]
  def list_projects() do
    # TODO: This does not work, we must also access the other Build
    # table. OR: We need to update the table during an update/insert of
    # a build.
    Repo.all(BaumeisterWeb.Project)
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

end
