defmodule Baumeister do

  alias Baumeister.BaumeisterFile
  alias Baumeister.Observer.Coordinate


  @doc """
  Executes the commands defined in the BaumeisterFile on a node that
  fits to the settings (e.g. OS) and on which the repository at the
  Coordinate will be checked out.
  """
  @spec execute(Coordinate.t, BaumeisterFile.t) :: :ok
  def execute(_coord, _job) do
    :ok
  end
end
