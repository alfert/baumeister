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

  alias BaumeisterWeb.Builds.Project
  alias BaumeisterWeb.Builds.Build

  def list_projects() do
    # TODO: This does not work, we must also access the other Build
    # table. OR: We need to update the table during an update/insert of
    # a build.
    Repo.all(BaumeisterWeb.Project)
  end

  @spec builds_for_project(Project) :: [Build]
  def builds_for_project(project) do
    q = from(b in Build,
        where: b.project_id == ^project.id,
        order_by: [desc: b.build_id])
    Repo.all(q)
  end

end
