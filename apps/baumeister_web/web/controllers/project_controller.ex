defmodule BaumeisterWeb.ProjectController do
  use BaumeisterWeb.Web, :controller

  alias BaumeisterWeb.Project
  alias BaumeisterWeb.ProjectBridge

  require Logger

  def index(conn, _params) do
    projects = Repo.all(Project)
    render(conn, "index.html", projects: projects)
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

    case Repo.update(changeset) do
      {:ok, project} ->
        ProjectBridge.update(project)
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
