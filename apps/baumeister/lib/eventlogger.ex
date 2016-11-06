alias Experimental.GenStage

defmodule Baumeister.EventLogger do
  @moduledoc """
  A simple event consumer, which is used for debugging and simple
  logging processes, such that at least one consumer is attached
  to the `EventCenter.`
  """

  use GenStage
  require Logger

  ###################################################
  ##
  ## EventLogger API
  ##
  ###################################################

  def start_link() do
    GenStage.start_link(__MODULE__, :ok, [])
  end

  ###################################################
  ##
  ## EventLogger Callbacks
  ##
  ###################################################

  def init(:ok) do
    {:consumer, :the_state_does_not_matter}
  end

  def handle_events(events, _from, state) do
    events
    |> Enum.map(fn(ev) -> Logger.info("EventLogger: event = #{ev}") end)
    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end

end
