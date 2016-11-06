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

  @doc """
  Starts the `EventLogger`. As parameter ony `subscribe_to: prod` is
  allowed, which automatically subscribes to producer `prod`.
  """
  @spec start_link(Keyword.t) :: {:ok, pid}
  def start_link(opts \\ []) when is_list(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  ###################################################
  ##
  ## EventLogger Callbacks
  ##
  ###################################################

  def init([subscribe_to: prod]) do
    {:consumer, :the_state_does_not_matter, subscribe_to: [prod]}
  end
  def init([]), do: {:consumer, :the_state_does_not_matter}

  def handle_events(events, _from, state) do
    events
    |> Enum.map(fn(ev) -> Logger.info("EventLogger: event = #{inspect ev}") end)
    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end

end
