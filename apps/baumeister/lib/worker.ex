defmodule Baumeister.Worker do
  @moduledoc """
  A Baumeister node is the working horse of Baumeister. Usually running on its
  own Erlang VM, a node is connected with a Baumeister server and waits for
  jobs to done.
  """

  alias Baumeister.Coordinator

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
    Logger.info "Starting Worker"
    coordinator = Coordinator.name()
    GenServer.start_link(__MODULE__, [coordinator])
  end

  ##############################################################################
  ##
  ## Callbacks and internals
  ##
  ##############################################################################

  def init([coordinator]) do
    Logger.info "Initializing Worker"
    :ok = Coordinator.register(self)
    ref = Process.monitor(GenServer.whereis(Coordinator.name))
    state = %__MODULE__{coordinator: coordinator, coordinator_ref: ref}
    {:ok, state}
  end

  # TODO: Implement the handle_info function for the DOWN message
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

end
