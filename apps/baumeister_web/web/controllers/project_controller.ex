defmodule BaumeisterWeb.ProjectController do
  use BaumeisterWeb.Web, :controller

  alias BaumeisterWeb.Project
  alias BaumeisterWeb.ProjectBridge

  require Logger

  def index(conn, _params) do
    #####################
    ##
    # Nochmal genauer schauen, wie und wo die
    # Build-Nummer und der Build-Status abgelegt wird. Diese Informationen
    # müssten eigentlich bei jedem Zugriff auf ein Projekt ermittelt
    # und angezeigt werden. Sowas als `last_build_state` und `last_build_id`
    # und wohl auch `last_build_date`
    #
    # ==> Reference the build number as `last_build` in `Project` and
    # join via the reference. This gives explicit pairs.
    #
    # ==> Mechanismus ist ok, aber wg. EctoMnesia funktioniert es nicht
    # auf die einfache Weise mit Assoziationen und preloads. D.h., diese
    # Dinge müssen explizit mit eigenen Queries geladen werden, aber halt
    # ohne JOINS (Einschränkung von EctoMnesia)
    # >>>> Der Build ist dann: Repo.get_by!(Build, [project_id: project.id, number: project.last_build_id])
    ##
    #####################
    projects = Repo.all(Project)
    render(conn, "index.html", projects: projects)
  end

  # join of projects and builds order project_id, build.number
  defp projects_and_builds() do
    from p in Project,
      join: b in Build
      #### TODO: Joins do not work with MnesiaEcto
      #### TODO: Select only the row with max(b.number)
  end

  def new(conn, _params) do
    changeset = Project.changeset(%Project{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"project" => project_params}) do
    changeset = Project.changeset(%Project{}, project_params)

    case insert(changeset) do
      {:ok, _project} ->
        conn
        |> put_flash(:info, "Project created successfully.")
        |> redirect(to: project_path(conn, :index))
      {:error, changeset} ->
        Logger.error("Error inserting project: #{inspect changeset}")
        render(conn, "new.html", changeset: changeset)
    end
  end

  @doc """
  Inserts the project into the database and the baumeister coordinator.
  """
  @spec insert(Project.t | %{}) :: {:ok, Project.t} | {:error, any}
  def insert(changeset) do
    case Repo.insert(changeset) do
      {:ok, project} ->
        case ProjectBridge.add_project_to_coordinator(project) do
          :ok -> enabled = project.enabled
                 ^enabled = ProjectBridge.set_status(project)
                 {:ok, project}
          {:error, msg} ->
            Logger.error("Error inserting project into core: #{inspect changeset}")
            Repo.delete!(project)
            {:error, Ecto.Changeset.add_error(%{changeset | action: :insert}, :name, msg)}
        end
      {:error, new_changeset} -> {:error, new_changeset}
    end
  end

  def show(conn, %{"id" => id}) do
    project = Repo.get!(Project, id)
    render(conn, "show.html", project: project)
  end

  def edit(conn, %{"id" => id}) do
    project = Repo.get!(Project, id)
    changeset = Project.changeset(project)
    render(conn, "edit.html", project: project, changeset: changeset)
  end

  def update(conn, %{"id" => id, "project" => project_params}) do
    project = Repo.get!(Project, id)
    changeset = Project.changeset(project, project_params)
    Logger.debug "Changeset for project: #{inspect changeset}"

    case Repo.update(changeset) do
      {:ok, project} ->
        with :ok = ProjectBridge.update(project) do
          Logger.debug "Set status of project #{inspect project}"
          ProjectBridge.set_status(project)
        end
        conn
        |> put_flash(:info, "Project updated successfully.")
        |> redirect(to: project_path(conn, :show, project))
      {:error, changeset} ->
        render(conn, "edit.html", project: project, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    project = Repo.get!(Project, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(project)
    ProjectBridge.delete_project_from_coordinator!(project)

    conn
    |> put_flash(:info, "Project deleted successfully.")
    |> redirect(to: project_path(conn, :index))
  end
end
