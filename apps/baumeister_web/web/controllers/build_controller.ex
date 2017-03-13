defmodule BaumeisterWeb.BuildController do
  use BaumeisterWeb.Web, :controller

  alias BaumeisterWeb.Build

  def index(conn, _params) do
    builds = Repo.all(Build)
    render(conn, "index.html", builds: builds)
  end

  def new(conn, _params) do
    changeset = Build.changeset(%Build{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"build" => build_params}) do
    changeset = Build.changeset(%Build{}, build_params)

    case Repo.insert(changeset) do
      {:ok, _build} ->
        conn
        |> put_flash(:info, "Build created successfully.")
        |> redirect(to: build_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    build = Repo.get!(Build, id)
    render(conn, "show.html", build: build)
  end

end
