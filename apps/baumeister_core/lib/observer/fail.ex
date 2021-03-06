defmodule Baumeister.Observer.FailPlugin do

  alias Baumeister.Observer
  @moduledoc """
  An `Observer` Plugin that immediately fails. It is ideally suited
  for testing purposes.
  To use it, provide the `init` function with any value.
  """
  @behaviour Baumeister.Observer

  @doc """
  Provide the configuration as a pair of the repository URL and
  the content of a BaumeisterFile.
  """
  @spec init(config :: any) :: {:ok, any}
  def init(_config) do
    {:ok, :will_fail}
  end

  @doc """
  Returns immediately the configured URL and the content of the
  BaumeisterFile.
  """
  @spec observe(state :: any) :: Observer.observer_return_t
  def observe(:will_fail) do
    {:error, "will always fail", :will_fail}
  end

  @doc """
  A checkout cannot happen for the plugin. The call will fail.
  """
  def checkout(coord, _build_dir) do
    msg = "no checkout possible for #{inspect __MODULE__}. Coordinate is #{inspect coord}"
    raise ArgumentError, message: msg
  end
end
