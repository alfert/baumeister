defmodule BaumeisterWeb.BuildChannel do
  use BaumeisterWeb.Web, :channel

  alias Baumeister.BuildEvent
  alias BaumeisterWeb.Project
  alias BaumeisterWeb.Build

  @moduledoc """
  The Channel for build events.
  """

  require Logger

  @doc """
  Join the channel. For now, there is only the `build:lobby` without
  any further authorization and differentiation between users, projects
  and builds.
  """
  @impl Phoenix.Channel
  def join("build:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
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
  defp authorized?(_payload) do
    true
  end

  @doc """
  Broadcast an event. Currently, we use the default topic `build:lobby`.
  """
  @impl Phoenix.Channel
  def broadcast_event(ev = %BuildEvent{build_counter: counter, coordinate: coord}) do
    Logger.debug("broadcast_event called with ev=#{inspect ev}")
    project = Repo.get_by!(Project, name: coord.project_name)
    Logger.debug("Found project: #{inspect project}")
    build_changeset = project
    |> create_build(counter)
    |> Build.changeset(summerize_build_event(ev))
    Logger.debug("build changeset: #{inspect build_changeset}")

    case Repo.insert_or_update(build_changeset) do
      {:ok, build} ->
        Logger.debug("Inserted that build: #{inspect build}")
        {:ok, _pr} = project
        |> IO.inspect()
        |> Project.changeset(%{last_build_id: build.id})
        |> IO.inspect()
        |> Repo.update()
        BaumeisterWeb.Endpoint.broadcast("build:lobby", "build_event", event_to_map(ev))
      {:error, build_changeset} ->
        {:error, build_changeset}
    end
  end
  def broadcast_event(ev = {_role, _action, _step}) do
    BaumeisterWeb.Endpoint.broadcast("build:lobby", "old_build_event", event_to_map(ev))
  end

  @doc """
  Transforms a build event to a build struct to used in a changeset.
  """
  def summerize_build_event(build_event = %BuildEvent{coordinate: coord}) do
    [coordinate: "#{inspect coord}",
      status: status(build_event),
      log: log(build_event)]
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Enum.into(%{})
  end

  @doc """
  Creates or retrieves an `Build` for the given `project` and the given
  `build_counter`. If there already exists a build entity in the database,
  it is returned otherwise a new build struct is created.
  """
  @spec create_build(Project.t, integer) :: Build.t
  def create_build(project = %Project{}, build_counter) do
    case Repo.get_by(Build, [project_id: project.id, number: build_counter]) do
      nil -> %Build{project_id: project.id, number: build_counter}
      build -> build
    end
  end

  @doc """
  Converts the status from the build event to the build struct
  """
  def status(%BuildEvent{action: nil}), do: 0
  def status(%BuildEvent{action: :start}), do: 1
  def status(%BuildEvent{action: :result, data: :ok}), do: 2
  def status(%BuildEvent{action: :result}), do: 3
  def status(_), do: nil

  def log(%BuildEvent{action: :log, data: log_data}), do: log_data
  def log(_), do: nil

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
