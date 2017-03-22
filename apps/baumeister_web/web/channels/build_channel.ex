alias Experimental.GenStage
defmodule BaumeisterWeb.BuildChannel do
  use BaumeisterWeb.Web, :channel

  alias Baumeister.BuildEvent
  alias Baumeister.Observer.Coordinate

  @moduledoc """
  The Channel for build events is listener of the EventCenter
  and a channel at the same time.
  """

  use GenStage
  require Logger

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
  def init(opts) do
    Logger.info "initialize the GenStage Consumer for Build Events"
    if Keyword.has_key?(opts, :subscribe_to) do
      prod = Keyword.fetch!(opts, :subscribe_to)
      Logger.info "subscribe to #{inspect prod}"
      {:consumer, opts, subscribe_to: [{prod, cancel: :temporary}]}
    else
      Logger.error "Build Channel without subscription"
      1 = 0
      {:consumer, opts}
    end
  end

  @doc """
  We need to take care of subscription cancellations.
  TODO: resubscribe of EventCenter dies.
  """
  def handle_subscribe(:producer, _options, _to_or_from, state) do
    # this is the default implementation.
    {:automatic, state}
  end

  def handle_events(events, _from, _state) do
    Logger.debug("Build Channel received #{inspect Enum.count(events)} events")
    Enum.each(events, fn ev -> broadcast_event(ev) end)
    {:noreply, [], nil}
  end

  def join("build:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
  def handle_in("build_event", payload, socket) do
    push(socket, "build_event", payload)
    {:noreply, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (build:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  @doc """
  Broadcast an event. Currently, we use the default topic `build:lobby`.
  """
  def broadcast_event(ev = %BuildEvent{}) do
    BaumeisterWeb.Endpoint.broadcast("build:lobby", "build_event", event_to_map(ev))
  end
  def broadcast_event(ev = {role, action, step}) do
    BaumeisterWeb.Endpoint.broadcast("build:lobby", "old_build_event", event_to_map(ev))
  end

  def event_to_map(%BuildEvent{action: action, data: data, coordinate: coord}) do
    %{"role" => "worker",
      "action" => Atom.to_string(action),
      "data" => "#{inspect data}",
      "coordinate" => "#{inspect coord}"
    }
  end
  def event_to_map({role, action, step}) do
    %{"role" => Atom.to_string(role),
      "action" => Atom.to_string(action),
      "step" => "#{inspect step}"
    }
  end
end
