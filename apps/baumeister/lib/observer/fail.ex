defmodule Baumeister.Observer.FailPlugin do

  alias Baumeister.Observer
  @moduledoc """
  An `Observer` Plugin that imeeditaly fails. It is ideally suited
  for testing purposes.
  To use it, provide the `init` function with two p
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

end
