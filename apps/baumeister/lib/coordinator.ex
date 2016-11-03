defmodule Baumeister.Coordinator do
  @moduledoc """
  The Coordinator manages all workers and distributes jobs to the workers.
  """

  @type t :: %__MODULE__{
    workers: %{pid => WorkerSpec.t},
    monitors: %{reference => pid}
  }
  defstruct workers: %{}, monitors: %{}

  defmodule WorkerSpec do
    @moduledoc """
    Data about a worker
    """
    @type t :: %__MODULE__{
      pid: nil | pid,
      monitor_ref: nil | reference
    }
    defstruct pid: nil, monitor_ref: nil
 end


  use GenServer
  require Logger
  use Elixometer

  # Metrics
  @nb_of_workers "baumeister.nb_of_registered_workers"
  @start_workers "baumeister.nb_of_started_workers"

  ##############################################################################
  ##
  ## API
  ##
  ##############################################################################

  @doc "The name of the Coordinator Server"
  def name(), do: __MODULE__

  def start_link(opts \\ []) do
    Logger.info "Start the coordinator server"
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc """
  Registers a new worker
  """
  @spec register(pid | tuple) :: :ok | {:error, any}
  def register(worker) do
    GenServer.call(name(), {:register, worker})
  end

  @doc """
  Unregisters a worker
  """
  @spec unregister(pid | tuple) :: :ok | {:error, any}
  def unregister(worker) do
    GenServer.call(name(), {:unregister, worker})
  end

  @doc """
  Returns the list of worker specs
  """
  @spec workers() :: [WorkerSpec.t]
  def workers() do
    GenServer.call(name(), :workers)
  end

  ##############################################################################
  ##
  ## Internal Functions & Callbacks
  ##
  ##############################################################################

  def init([]) do
    Logger.info "Initialize the Coordinator"
    {:ok, %__MODULE__{}}
  end

  def handle_call({:register, worker}, _from, state) do
    Logger.info "Register worker #{inspect worker}"
    new_state = do_register(worker, state)
    {:reply, :ok, new_state}
  end
  def handle_call({:unregister, worker}, _from, state) do
    Logger.info "Unregister worker #{inspect worker}"
    {:reply, :ok, do_unregister(worker, state)}
  end
  def handle_call(:workers, _from, state = %__MODULE__{workers: workers}) do
    {:reply, workers |> Map.values(), state}
  end

  # Handle the monitoring messages from Workers
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:no_reply, do_crashed_worker(ref, state)}
  end
  def handle_info(msg, state) do
    Logger.debug "Coordinator: got unknown info message: #{inspect msg}"
    {:noreply, state}
  end

  @doc """
  _Internal Function!_

  Handles a crashed worker, i.e. where the monitor returns a
  `DOWN` message.
  """
  def do_crashed_worker(ref, %__MODULE__{workers: workers} = s) do
   crashed_worker =
     workers
     |> Enum.find(fn{_k, %WorkerSpec{monitor_ref: ^ref}} -> true
                                                      _ -> false end)
   case crashed_worker do
           nil -> s # we don't know the worker, just ignore it
           {pid, _spec} -> do_unregister(pid, s)
   end
  end

  @doc """
  _Internal Function!_

  Registers a new worker, starts monitoring the worker and updates
  the internal state
  """
  def do_register(worker, state = %__MODULE__{workers: workers, monitors: monitors}) do
    monitor = Process.monitor(worker)
    new_workers = Map.put(workers, worker, %WorkerSpec{monitor_ref: monitor, pid: worker})
    new_monitors = Map.put(monitors, monitor, worker)
    worker_no = new_workers |> Enum.count
    update_gauge(@nb_of_workers, worker_no)
    %__MODULE__{state | workers: new_workers, monitors: new_monitors}
  end
  @doc """
  _Internal Function!_

  Unregisters a worker, removing the worker from the state and
  distribute any new work to free workers.
  """
  @spec do_unregister(worker :: pid, state :: %__MODULE__{}) :: %__MODULE__{}
  def do_unregister(worker, state = %__MODULE__{workers: workers, monitors: monitors}) do
    # remove the worker and its associated data from workers
    worker_spec = workers |> Map.get(worker, %WorkerSpec{})
    Process.demonitor worker_spec.monitor_ref
    new_workers = workers |> Map.delete(worker)
    new_monitors = monitors |> Map.delete(worker_spec.monitor_ref)
    worker_no = new_workers |> Enum.count
    update_gauge(@nb_of_workers, worker_no)
    %__MODULE__{state | workers: new_workers, monitors: new_monitors}
  end

end
