defmodule BaumeisterWeb.Web.BuildChannel do
  use BaumeisterWeb.Web, :channel

  alias Baumeister.BuildEvent

  @moduledoc """
  The Channel for build events.
  """

  require Logger
  alias BaumeisterWeb.Builds

  @doc """
  Join the channel. For now, there is only the `build:lobby` without
  any further authorization and differentiation between users, projects
  and builds.
  """
  @impl Phoenix.Channel
  def join("build:lobby", payload, socket) do
    case authorized?(payload) do
      true -> {:ok, socket}
      _    -> {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl Phoenix.Channel
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
  def handle_in("build_event", payload, socket) do
    push(socket, "build_event", payload)
    {:noreply, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (build:lobby).
  @impl Phoenix.Channel
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  @spec authorized?(any) :: boolean
  defp authorized?(_payload) do
    true
  end

  @doc """
  Broadcast an event. Currently, we use the default topic `build:lobby`.
  """
  def broadcast_event(ev = %BuildEvent{}) do
    case Builds.create_build_from_event(ev) do
      {:ok, _} ->
        BaumeisterWeb.Web.Endpoint.broadcast("build:lobby",
          "build_event", event_to_map(ev))
      {:error, build_changeset} ->
        {:error, build_changeset}
    end
  end

  @doc """
  Formats an event as a map for encoding as JSON object.
  """
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
