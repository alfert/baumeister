defmodule BaumeisterWeb.Web.Test.Builds.Project do
  @moduledoc """
  Tests of Projects and Builds within the Builds-Context.
  """
  use BaumeisterWeb.Web.ModelCase

  alias BaumeisterWeb.Web.Builds.Project
  alias BaumeisterWeb.Web.Builds.Build
  alias BaumeisterWeb.Web.Builds
  require Logger

  test "insert a project" do
    flunk "Not implemented yet"
  end

  test "Retrieve all projects" do
    ps = Builds.list_projects()
    assert ps == []
  end

  test "Retrieve all builds of project" do
    p = %Project{}
    Logger.debug "p = #{inspect p}"
    bs = Builds.builds_for_project(p)
    assert bs == []
  end
end
