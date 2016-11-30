defmodule Baumeister.Observer.NoopPlugin do

  @moduledoc """
  An `Observer` Plugin that does virtually nothing. It is ideally suited
  for testing purposes and it is the lower bound of provided functionality.

  To use it, provide the `init` function with two p
  """
  @behaviour Baumeister.Observer

  @doc """
  Provide the configuration as a pair of the repository URL and
  the content of a BaumeisterFile.
  """
  @spec init(config :: {String.t, String.t}) :: {:ok, any}
  def init(config = {url, baumeisterfile}) do
    {:ok, config}
  end

  @doc """
  Returns immediately the configured URL and the content of the
  BaumeisterFile.
  """
  @spec observe(state :: any) :: {:ok, String.t, String.t} | :error
  def observe({url, bmf}) do
    {:ok, url, bmf}
  end

end
