defmodule Baumeister.Worker do
  @moduledoc """
  A Baumeister node is the working horse of Baumeister. Usually running on its
  own Erlang VM, a node is connected with a Baumeister server and waits for
  jobs to done.

  ## Capabilities
  A worker has certain capabilities, used for assigning a proper job, since
  job execution makes only sense, if the worker has all required capabilities
  for executing the particular job.

  The following capabilities are checked and communicated to the coordinator
  (see `t:capabilities_t/0`):

  * `os`: either `windows`, `linux` or `macos`
  * `cpu`: `x86_64` (default value)
  * `git`: `true` if the `git` executable is available
  * `mix`: `true` if the `mix` executable for building Elixir is available
  """

  alias Baumeister.Coordinator
  alias Baumeister.EventCenter
  alias Baumeister.Observer.Coordinate

  @typedoc """
  The capabilities are a map of keys of type `atom` to any value.
  """
  @type capabilities_t :: %{
    git: boolean,
    mix: boolean,
    cpu: atom,
    os: atom,
    }


  @typedoc """
  The internal state of a worker:

  * `coordinator`: the process id of the `coordinator` process
  * `coordinator_ref`: a monitor reference to the coordinator process
  * `processes` map all running tasks to their originitating Observer coordinator
  * `job_counter` holds the total number of jobs executed by this worker
  * `workspace_base` holds the path to the workspace into the repositories
  are checked out for building.
  """
  @type t :: %__MODULE__{
    coordinator: nil | pid,
    coordinator_ref: nil | reference,
    processes: %{pid => Coordinate.t},
    job_counter: pos_integer,
    workspace_base: String.t
  }
  defstruct coordinator: nil, coordinator_ref: nil,
    processes: %{}, job_counter: 0, workspace_base: ""

  use GenServer
  require Logger

  ##############################################################################
  ##
  ## API
  ##
  ##############################################################################

  @doc """
  Starts a new worker process and connect the process with
  the Coordinator.
  """
  @spec start_link() :: {:ok, pid}
  def start_link() do
    Logger.debug "Starting Worker"
    coordinator = Coordinator.name()
    GenServer.start_link(__MODULE__, [coordinator])
  end

  @doc """
  Detects the capabilites of `worker_pid`.
  """
  @spec capabilities(pid) :: capabilities_t
  def capabilities(worker_pid) do
    GenServer.call(worker_pid, :capabilities)
  end

  @doc """
  Executes the given BaumeisterFile and returns a reference
  to the process execution. Eventually, a message of the form
  `{:executed, {out, rc, ref}}` is send to the current process, to inform
  about the result of the asynchronous running BaumeisterFile execution process.
  """
  @spec execute(pid, Coordinate.t, Baumeister.BaumeisterFile.t) :: {:ok, reference}
  def execute(pid, %Coordinate{} = coordinate, bmf) do
    GenServer.call(pid, {:execute, coordinate, bmf})
  end

  @doc """
  Connects to the global coordinator, thereby enabling the worker to
  receive jobs to work on.

  It requires that a connection to the node with the coordinator is established,
  thus this function is usually called during the internal startup process of the
  worker only.
  """
  @spec connect(pid) :: :ok
  def connect(pid) do
    GenServer.call(pid, :connect)
  end

  ##############################################################################
  ##
  ## Callbacks and internals
  ##
  ##############################################################################


  def init([coordinator]) do
    Logger.debug "Initializing Worker"
    Process.flag(:trap_exit, true)
    ############
    #
    # TODO: we should use fuse as a circuit breaker
    # to handle net splits properly for calls to EventCenter
    # and to the Coordinator
    #
    #############

    base = Application.get_env(:baumeister_core, :workspace_base, System.tmp_dir!)
    state = %__MODULE__{coordinator: coordinator,
      workspace_base: base
    }
    me = self()
    spawn_link(fn -> register(me) end)
    {:ok, state}
  end

  def handle_call(:capabilities, _from, state) do
    {:reply, detect_capabilities(), state}
  end
  def handle_call({:execute, coordinate, bmf}, from, state = %__MODULE__{processes: processes}) do
    ref = make_ref()
    EventCenter.sync_notify({:worker, :execute, {:start, coordinate}})
    {state, workspace} = workspace_path(state)
    {:ok, exec_pid} = Task.start_link(fn ->
      EventCenter.sync_notify({:worker_job, :spawned, self()})
      {out, rc} = execute_bmf(coordinate, bmf, workspace)
      case rc do
        0 -> EventCenter.sync_notify({:worker, :execute, {:ok, coordinate}})
        _ -> EventCenter.sync_notify({:worker, :execute, {:error, coordinate}})
      end
      EventCenter.sync_notify({:worker, :execute, {:log, coordinate, out}})
      send_exec_return(from, out, rc, ref)
    end)
    new_state = %__MODULE__{state | processes: processes |> Map.put(exec_pid, coordinate)}
    {:reply, {:ok, ref}, new_state}
  end
  def handle_call(:connect, _from, state = %__MODULE__{}) do
    Logger.debug("Worker #{inspect self()} connects to Coordinator")
    EventCenter.sync_notify({:worker, :start, self()})
    :ok = Coordinator.register(self(), detect_capabilities())
    # :ok = Coordinator.update_capabilities(self(), detect_capabilities())
    ref = Process.monitor(GenServer.whereis(Coordinator.name))
    Logger.debug("Worker #{inspect self()} has properly connected to Coordinator")
    {:reply, :ok, %__MODULE__{ state | coordinator_ref: ref}}
  end

  defp send_exec_return({pid, _from_ref} , out, rc, ref) do
    pid |> send({:executed, {out, rc, ref}})
  end

  @doc """
  Computes the workspace for the next job and returns a new worker state.

  The `job_counter` is incremented and the path is a combination of
  `workspace_base` and the `job_counter`.
  """
  @spec workspace_path(t) :: {t, String.t}
  def workspace_path(state = %__MODULE__{job_counter: job, workspace_base: base}) do
    new_state = %__MODULE__{state | job_counter: job + 1}
    path = Path.join([base, Atom.to_string(node()), "#{job}"])
    {new_state, path}
  end

  # Handle the monitoring messages from Coordinators
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    if ref == state.coordinator_ref do
      Logger.info("Coordinator has stopped working. This nodes goes down.")
      {:stop, :coordinator_is_down, %__MODULE__{state | coordinator: nil, coordinator_ref: nil}}
    else
      Logger.info "Unknown monitor went down. Ignored."
      {:noreply, state}
    end
  end
  def handle_info({:EXIT, pid, reason}, state = %__MODULE__{processes: processes}) do
    new_state = case processes |> Map.get(pid) do
      nil -> Logger.error ("Unknown linked pid #{inspect pid}")
             Logger.error "State: #{inspect state}"
             state
      coordinate ->
             if reason != :normal, do:
              EventCenter.sync_notify({:worker, :crashed, {reason, coordinate}})
             %__MODULE__{state | processes: processes |> Map.delete(pid)}
    end
    {:noreply, new_state}
  end
  def handle_info(msg, state) do
    Logger.debug "Worker: got unknown info message: #{inspect msg}"
    {:noreply, state}
  end

  def terminate(reason, _state) do
    EventCenter.sync_notify({:worker, :terminate, reason})
    :ok
  end

  def register(worker) do
    master = Application.get_env(:baumeister_core, :coordinator_node, :unknown)
    # if connect fails, we can also fail.
    true = connect_to_coordinator(master, 5)
    :ok = connect(worker)
  end

  def connect_to_coordinator(_, 0) do
    Logger.warn("No success in contacting the coordinator node. Giving up")
    false
   end
  def connect_to_coordinator(:unknown, _count) do
    Logger.warn("No coordinator node configured. Trying local coordinator")
    ensure_coordinator_processes()
  end
  def connect_to_coordinator(master, count) do
    case Node.connect(master) do
      true ->
        Logger.info("Connected to coordinator node #{inspect master}")
        ensure_coordinator_processes()
      _ ->
        Logger.warn("Failed to connect to the coordinator node #{inspect master}.")
        Process.sleep(30_000)
        connect_to_coordinator(master, count - 1)
    end
  end

  defp ensure_coordinator_processes() do
    :global.sync()
    pid = GenServer.whereis(Coordinator.name())
    Logger.info("Coordinator #{inspect Coordinator.name()} is #{inspect pid}")
    ec_pid = GenServer.whereis(EventCenter.name())
    Logger.info("EventCenter #{inspect EventCenter.name()} is #{inspect ec_pid}")
    is_pid(pid) and is_pid(ec_pid)
  end

  @doc """
    __Internal function!__

    See `execute_bmf/3`, where the missing parameter `workspace`
    is set to directory `baumeister_workspace` in the system's temp dir.
  """
  @spec execute_bmf(Coordinate.t, Baumeister.BaumeisterFile.t) :: {String.t, integer}
  def execute_bmf(coordinate, bmf) do
    tmpdir = System.tmp_dir!()
    workspace = Path.join(tmpdir, "baumeister_workspace")
    execute_bmf(coordinate, bmf, workspace)
  end

  @doc """
  __Internal function!__

  Execute a BaumeisterFile. The following steps are required:

  * Create a new workspace directory
  * extract the workspace from the coordinate with the proper SCM plugin
  * cd into the directory
  * execute the command from the `bmf`
  * remove the workspace directory
  * return the output and returncode from the command

    """
  @spec execute_bmf(Coordinate.t, Baumeister.BaumeisterFile.t, String.t) :: {String.t, integer}
  def execute_bmf(coordinate, bmf, workspace) do
    # make workspace dir
    :ok = File.mkdir_p!(workspace)
    # checkout from `coordinate` into build_dir
    build_dir = coordinate.observer.checkout(coordinate, workspace)
    # execute command and cd into build_dir
    {shell, arg1}  = case bmf.os do
      :windows -> {"cmd.exe", "/c"}
      _unix -> {"/bin/sh", "-c"}
    end
    {out, rc} = System.cmd(shell, [arg1, bmf.command], [cd: build_dir, stderr_to_stdout: true])
    # remove the build directory
    {:ok, _files} = File.rm_rf(build_dir)
    {out, rc}
  end

  @doc """
  __Internal function!__

  Detects the capabilities of the current worker. Initial set
  considers the operating system, the CPU, and the existence of
  git and mix. Future version may have many more capabilities
  to be checked.
  """
  @spec detect_capabilities() :: capabilities_t
  def detect_capabilities() do
    [:os, :cpu, :git, :mix]
    |> Enum.map(&detect_capability/1)
    |> Enum.into(%{})
  end
  @doc false
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
