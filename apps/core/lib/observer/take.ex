defmodule Baumeister.Observer.Take do

  alias Baumeister.Observer
  @moduledoc """
  An `Observer` Plugin that runs only a defined number of times before
  the entire execution is properly stopped.

  """
  @behaviour Baumeister.Observer

  @doc """
  Provide a number of
  """
  @spec init(non_neg_integer) :: {:ok, any}
  def init(number) when is_integer(number) and number >= 0 do
    {:ok, number}
  end

  @doc """
  Decrements the counter and stops after the counter reaches `0`.
  """
  @spec observe(state :: non_neg_integer) :: Observer.observer_return_t
  def observe(0), do: {:stop, 0}
  def observe(n), do: {:ok, n - 1}

  @doc """
  A checkout cannot happen for the  plugin. The call will fail.
  """
  def checkout(coord, _build_dir) do
    msg = "no checkout possible for #{inspect __MODULE__}. Coordinate is #{inspect coord}"
    raise ArgumentError, message: msg
  end
end
