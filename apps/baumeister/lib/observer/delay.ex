defmodule Baumeister.Observer.Delay do

  alias Baumeister.Observer
  @moduledoc """
  An `Observer` Plugin that waits a given amount of time before
  letting the process to move forward.

  """
  @behaviour Baumeister.Observer

  @doc """
  Provide a number of milliseconds as delay.
  """
  @spec init(non_neg_integer) :: {:ok, any}
  def init(number) when is_integer(number) and number >= 0 do
    {:ok, number}
  end

  @doc """
  Sleeps for the given number of `n` milliseconds.
  """
  @spec observe(state :: non_neg_integer) :: Observer.observer_return_t
  def observe(n) do
    Process.sleep(n)
    {:ok, n}
  end

end
