alias Experimental.GenStage
defmodule BaumeisterWeb.BuildChannel do
  use BaumeisterWeb.Web, :channel

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
  def init(_) do
    Logger.debug "initialize the GenStage Consumer for Build Events"
    {:consumer, []}
  end

  def handle_events(events, _from, _state) do
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
  Broadcast an event. Currently, we use the dewfault topic `build:lobby`.
  """
  def broadcast_event(ev = {role, action, step}) do
    BaumeisterWeb.Endpoint.broadcast("build:lobby", "build_event", event_to_map(ev))
  end

  def event_to_map({role, action, step}) do
    %{"role" => Atom.to_string(role),
      "action" => Atom.to_string(action),
      "step" => "#{inspect step}"
    }
  end
end
