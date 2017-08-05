defmodule BaumeisterWeb.BuildListener do
  @moduledoc """
  This is a GenStage consumer for build events. It subscribes to the
  GenStage `EventCenter` and stores build events as build data into the
  database. At the same time it also broadcasts these events to the
  `BuildChannel` such that any web clients receive build events immediately.
  """

  use GenStage
  require Logger

  alias BaumeisterWeb.Web.BuildChannel
  alias BaumeisterWeb.Builds

  @doc """
  Starts the `BuildChannel` as consumer of the `EventCenter`.
  As parameter only `subscribe_to: prod` is
  allowed, which automatically subscribes to producer `prod`.
  """
  @spec start_link(Keyword.t) :: {:ok, pid}
  def start_link(opts \\ []) when is_list(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @doc """
  Initialize the `GenStage` consumer.
  """
  @impl GenStage
  def init(opts) do
    Logger.info "initialize the GenStage Consumer for Build Events"
    if Keyword.has_key?(opts, :subscribe_to) do
      prod = Keyword.fetch!(opts, :subscribe_to)
      Logger.info "subscribe to #{inspect prod}"
      {:consumer, opts, subscribe_to: [{prod, cancel: :temporary}]}
    else
      Logger.error "Build Listener without subscription"
      {:error, "subscription missing"}
    end
  end


  @doc """
  We need to take care of subscription cancellations.
  TODO: resubscribe if EventCenter dies.
  """
  @impl GenStage
  def handle_subscribe(:producer, _options, _to_or_from, state) do
    # this is the default implementation.
    {:automatic, state}
  end

  @doc """
  Handles events from the `GenStage`, i.e. from the backend
  to store build events in the database and to propagate them
  towards the client browsers.
  """
  @impl GenStage
  def handle_events(events, _from, _state) do
    Logger.debug("Build Listener received #{inspect Enum.count(events)} events")
    Enum.each(events, fn ev ->
      with {:ok, _project} <- Builds.create_build_from_event(ev) do
        # broadcast the event only, it is properly stored in the database
        BuildChannel.broadcast_event(ev)
      end
    end)
    {:noreply, [], nil}
  end

end
