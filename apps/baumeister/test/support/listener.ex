defmodule Baumeister.Test.TestListener do
  @moduledoc """
  A simple listener for the Event Center
  """
  alias Experimental.GenStage
  alias Baumeister.EventCenter
  
  use GenStage

  def start(), do: GenStage.start_link(__MODULE__, :ok)
  def init(_), do: {:consumer, []}
  def handle_events(events, _, state) do
    {:noreply, [], state ++ events}
  end

  def get(stage), do: GenStage.call(stage, :get)
  def handle_call(:get, _, state), do: {:reply, state, [], state}
end
