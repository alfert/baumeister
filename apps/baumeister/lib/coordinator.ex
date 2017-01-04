defmodule Baumeister.Coordinator do
  @moduledoc """
  The Coordinator manages all workers and distributes jobs to the workers.

  The coordinator matches a BaumeisterFile in its Elixir representation (see
  `BaumeisterFile`) to the capabilities of the node, to find suitables nodes
  which are able to execute the BaumeisterFile.
  """

  @typedoc """
  * `workers` is mapping from process ids to Worker Specifications. It holds
  all registered workers.
  * `monitors` is mapping from monitor references to process ids, to detect
  aborting worker processes.
  """
  @type t :: %__MODULE__{
    workers: %{required(pid) => WorkerSpec.t},
    monitors: %{required(reference) => pid}
  }
  defstruct workers: %{}, monitors: %{}

  defmodule WorkerSpec do
    @moduledoc """
    Data about a worker
    """
    @typedoc """
    A worker specification contains:
    * the process id of the worker
    * the monitor reference to worker process
    * the worker's capabilities
    """
    @type t :: %__MODULE__{
      pid: nil | pid,
      monitor_ref: nil | reference,
      capabilities: Baumeister.Worker.capabilities_t
    }
    defstruct pid: nil, monitor_ref: nil,
      capabilities: %{}
 end


  use GenServer
  require Logger
  use Elixometer

  alias Baumeister.EventCenter
  alias Baumeister.Worker
  alias Baumeister.BaumeisterFile

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
  @spec all_workers() :: [WorkerSpec.t]
  def all_workers() do
    GenServer.call(name(), :workers)
  end

  @doc """
  Updates the capabilities of worker to assign proper jobs. Should
  only be used from the worker for updating its capabilities.
  """
  @spec update_capabilities(pid | tuple, Worker.capabilities_t) :: :ok | {:error, any}
  def update_capabilities(worker, capabilities) when is_map(capabilities)do
    GenServer.call(name(), {:update_capabilities, worker, capabilities})
  end

  ##############################################################################
  ##
  ## Internal Functions & Callbacks
  ##
  ##############################################################################

  @doc false
  def init([]) do
    Logger.info "Initialize the Coordinator"
    {:ok, %__MODULE__{}}
  end

  @doc false
  def handle_call({:register, worker}, _from, state) do
    Logger.debug "Register worker #{inspect worker}"
    EventCenter.sync_notify({:coordinator, :register, worker})
    do_register(worker, state)
    |> reply(:ok)
  end
  def handle_call({:unregister, worker}, _from, state) do
    Logger.debug "Unregister worker #{inspect worker}"
    EventCenter.sync_notify({:coordinator, :runegister, worker})
    do_unregister(worker, state)
    |> reply(:ok)
  end
  def handle_call(:workers, _from, state = %__MODULE__{workers: workers}) do
    state
    |> reply(workers |> Map.values())
  end
  def handle_call({:update_capabilities, worker, capa}, _from,
                            state = %__MODULE__{workers: workers}) do
    case Map.fetch(workers, worker) do
      {:ok, spec} ->
          s = %WorkerSpec{spec | capabilities: capa}
          state
          |> Map.put(:workers, workers |> Map.put(worker, s))
          |> reply(:ok)
      :error -> {:replay, {:error, :unknown_worker}, state}
    end
  end

  # OTP reply for nice pipelines
  @spec reply(t, any) :: {:reply, any, t}
  defp reply(state = %__MODULE__{}, return_value) do
    {:reply, return_value, state}
  end

  # Handle the monitoring messages from Workers
  @doc false
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, do_crashed_worker(ref, state)}
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
    # capabilities = Worker.capabilities(worker)
    spec = %WorkerSpec{monitor_ref: monitor, pid: worker}
    new_workers = Map.put(workers, worker, spec)
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

  @doc """
  Identifies the worker processes that match the requirements of
  the Baumeister file.
  """
  @spec match_workers(%{pid => WorkerSpec.t}, BaumeisterFile.t) :: [pid]
  def match_workers(workers, baumeisterfile) do
    workers
    |> Map.to_list
    |> Enum.filter_map(
      fn {_pid, w} -> match_worker?(w.capabilities, baumeisterfile) end,
      fn {pid, _w} -> pid end)
  end

  @doc """
  Matches a single worker `capa` to the Baumeister file `bmf`.
  Returns true, if worker matches the Baumeister file.
  """
  @spec match_worker?(Worker.capabilities_t, BaumeisterFile.t) :: boolean
  def match_worker?(capa, bmf) do
    Logger.debug "bmf : #{inspect bmf}"
    Logger.debug "capa: #{inspect capa}"
    bmf.os == Map.fetch!(capa, :os) and
      (bmf.language == "elixir" and Map.fetch!(capa, :mix))
   end
end
