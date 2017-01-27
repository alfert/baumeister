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

  @doc false
  def init(opts) do
    if Keyword.has_key?(opts, :subscribe_to) do
      prod = Keyword.fetch!(opts, :subscribe_to)
      {:consumer, opts, subscribe_to: [prod]}
    else
      {:consumer, opts}
    end
  end

  @doc false
  def handle_events(events, _from, state) do
    verbose = Keyword.get(state, :verbose, false)
    events
    |> Enum.each(fn(ev) ->
        if verbose, do: Logger.info("EventLogger: event = #{inspect ev}") end)
    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end

end
