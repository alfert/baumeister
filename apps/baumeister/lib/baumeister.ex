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


  @doc """
  Executes the commands defined in the BaumeisterFile on a node that
  fits to the settings (e.g. OS) and on which the repository at the
  Coordinate will be checked out.
  """
  @spec execute(Coordinate.t, BaumeisterFile.t) :: :ok
  def execute(_coord, _job) do
    :ok
  end

  @spec add_project(String.t, String.t, [Observer.plugin_config_t]) :: :ok
  def add_project(project_name, url, plugin_list) do
    :ok
  end
end
