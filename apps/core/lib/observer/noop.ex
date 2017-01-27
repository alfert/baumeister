defmodule Baumeister.Observer.NoopPlugin do

  alias Baumeister.Observer
  alias Baumeister.Observer.Coordinate

  @moduledoc """
  An `Observer` Plugin that does virtually nothing. It is ideally suited
  for testing purposes and it is the lower bound of provided functionality.

  To use it, provide the `init` function with a repository URL and the
  content of a BaumeisterFile. When running the plugin, the return value
  is a coordinate is created out of the URL and the BaumeisterFile. 
  """
  @behaviour Baumeister.Observer

  @doc """
  Provide the configuration as a pair of the repository URL and
  the content of a BaumeisterFile.
  """
  @spec init(config :: Observer.result_t) :: {:ok, any}
  def init(config = {_url, _baumeisterfile}) do
    {:ok, config}
  end

  @doc """
  Returns immediately the configured URL and the content of the
  BaumeisterFile.
  """
  @spec observe(state :: any) :: Observer.observer_return_t
  def observe(s = {url, bmf}) do
    {:ok, [{make_coordinate(url), bmf}], s}
  end

  @doc """
  A little helper to create a noop coordinate, where no real checkout
  happens, when a checkout is done with this coordinate.
  """
  def make_coordinate(url) do
    %Coordinate{url: url, observer: __MODULE__}
  end

  @doc """
  Does a checkout of the given `coordinate`, relative to the `workdir` given.
  Since this is the NoopPlugin, any values of the coordinate are silently
  ignored.
  The newly created directory is returned.
  """
  @spec checkout(Coordinate.t, String.t) :: String.t
  def checkout(_coordinate, workdir) do
    build_dir = Path.join(workdir, "build")
    File.mkdir_p!(build_dir)
    build_dir
  end
end
