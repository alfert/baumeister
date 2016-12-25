defmodule Baumeister.Test.TestListener do
  @moduledoc """
  A simple listener for the Event Center
  """
  alias Experimental.GenStage

  use GenStage

  def start(), do: GenStage.start_link(__MODULE__, :ok)
  def init(_), do: {:consumer, []}
  def handle_events(events, _, state) do
    {:noreply, [], state ++ events}
  end

  def get(stage), do: GenStage.call(stage, :get)
  def clear(stage), do: GenStage.call(stage, :clear)
  # {:reply, result, events, state}
  def handle_call(:get, _, state), do: {:reply, state, [], state}
  def handle_call(:clear, _, state), do: {:reply, length(state), [], []}
end
