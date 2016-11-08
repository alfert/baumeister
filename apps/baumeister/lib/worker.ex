defmodule Baumeister.Worker do
  @moduledoc """
  A Baumeister node is the working horse of Baumeister. Usually running on its
  own Erlang VM, a node is connected with a Baumeister server and waits for
  jobs to done.

  ## Capabilities
  A worker has certain capabilities, used for assigning a proper job, since
  job execution makes only sense, if the worker has all required capabilities
  for executing the particular job.

  The following capabilities are checked and communicated to the coordinator:

  * `os`: either `windows`, `linux` or `macos`
  * `cpu`: `x86_64` (default value)
  * `git`: `true` if the `git` executable is available
  * `mix`: `true` if the `mix` executable for building Elixir is available
  """

  alias Baumeister.Coordinator
  alias Baumeister.EventCenter

  @type t :: %__MODULE__{
    coordinator: nil | pid,
    coordinator_ref: nil | reference
  }
  defstruct coordinator: nil, coordinator_ref: nil

  use GenServer
  require Logger

  ##############################################################################
  ##
  ## API
  ##
  ##############################################################################

  def start_link() do
    Logger.debug "Starting Worker"
    coordinator = Coordinator.name()
    GenServer.start_link(__MODULE__, [coordinator])
  end

  @doc """
  Detects the capabilites of `worker_pid`.
  """
  def capabilities(worker_pid) do
    GenServer.call(worker_pid, :capabilities)
  end

  ##############################################################################
  ##
  ## Callbacks and internals
  ##
  ##############################################################################

  def init([coordinator]) do
    Logger.debug "Initializing Worker"
    EventCenter.sync_notify({:worker, :start, self})
    :ok = Coordinator.register(self)
    :ok = Coordinator.update_capabilities(self, detect_capabilities())
    ref = Process.monitor(GenServer.whereis(Coordinator.name))
    state = %__MODULE__{coordinator: coordinator, coordinator_ref: ref}
    {:ok, state}
  end

  def handle_call(:capabilities, _from, state) do
    {:reply, detect_capabilities(), state}
  end

  # Handle the monitoring messages from Workers
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    if ref == state.coordinator_ref do
      Logger.info("Coordinator has stopped working. This nodes goes down.")
      {:stop, :coordinator_is_down, %__MODULE__{state | coordinator: nil, coordinator_ref: nil}}
    else
      Logger.info "Unknown monitor went down. Ignored."
      {:noreply, state}
    end
  end
  def handle_info(msg, state) do
    Logger.debug "Coordinator: got unknown info message: #{inspect msg}"
    {:noreply, state}
  end

  def terminate(reason, _state) do
    EventCenter.sync_notify({:worker, :terminate, reason})
    :ok
  end

  def detect_capabilities() do
    [:os, :cpu, :git, :mix]
    |> Enum.map(fn key -> detect_capability(key) end)
    |> Enum.into(%{})
  end

  def detect_capability(:os) do
    case :os.type do
      {:unix, :darwin} -> {:os, :macos}
      {:unix, :linux}  -> {:os, :linux}
      {:win32, :nt}    -> {:os, :windows}
    end
  end
  def detect_capability(:git) do
    case System.find_executable("git") do
      nil -> {:git, false}
      _path -> {:git, true}
    end
  end
  def detect_capability(:mix) do
    case System.find_executable("mix") do
      nil -> {:mix, false}
      _path -> {:mix, true}
    end
  end
  def detect_capability(:cpu) do
    {:cpu, :x86_64}
  end
end
