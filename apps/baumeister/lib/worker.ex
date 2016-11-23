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
    coordinator_ref: nil | reference,
    processes: %{pid => String.t},
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

  def start_link() do
    Logger.debug "Starting Worker"
    coordinator = Coordinator.name()
    GenServer.start_link(__MODULE__, [coordinator])
  end

  @doc """
  Detects the capabilites of `worker_pid`.
  """
  @spec capabilities(pid) :: %{atom => any}
  def capabilities(worker_pid) do
    GenServer.call(worker_pid, :capabilities)
  end

  @doc """
  Executes the given BaumeisterFile and returns a reference
  to the process execution. Eventually, the a message of the form
  `{:executed, {out, rc, ref}}` is send to the current process, to inform
  about the resut of the asynchronous running BaumeisterFile execution process.
  """
  @spec execute(pid, String.t, Baumeister.BaumeisterFile.t) :: {:ok, reference}
  def execute(pid, url, bmf) do
    GenServer.call(pid, {:execute, url, bmf})
  end

  ##############################################################################
  ##
  ## Callbacks and internals
  ##
  ##############################################################################

  def init([coordinator]) do
    Logger.debug "Initializing Worker"
    Process.flag(:trap_exit, true)
    EventCenter.sync_notify({:worker, :start, self})
    :ok = Coordinator.register(self)
    :ok = Coordinator.update_capabilities(self, detect_capabilities())
    ref = Process.monitor(GenServer.whereis(Coordinator.name))
    base = Application.get_env(:baumeister, :workspace_base, System.tmp_dir!)
    state = %__MODULE__{coordinator: coordinator,
      coordinator_ref: ref,
      workspace_base: base
    }
    {:ok, state}
  end

  def handle_call(:capabilities, _from, state) do
    {:reply, detect_capabilities(), state}
  end
  def handle_call({:execute, url, bmf}, from, state = %__MODULE__{processes: processes}) do
    ref = make_ref()
    EventCenter.sync_notify({:worker, :execute, {:start, url}})
    {state, workspace} = workspace_path(state)
    {:ok, exec_pid} = Task.start_link(fn ->
      EventCenter.sync_notify({:worker_job, :spawned, self})
      {out, rc} = execute_bmf(url, bmf, workspace)
      case rc do
        0 -> EventCenter.sync_notify({:worker, :execute, {:ok, url}})
        _ -> EventCenter.sync_notify({:worker, :execute, {:error, url}})
      end
      EventCenter.sync_notify({:worker, :execute, {:log, url, out}})
      send_exec_return(from, out, rc, ref)
    end)
    new_state = %__MODULE__{state | processes: processes |> Map.put(exec_pid, url)}
    {:reply, {:ok, ref}, new_state}
  end

  defp send_exec_return({pid, _from_ref} , out, rc, ref) do
    pid |> send({:executed, {out, rc, ref}})
  end

  @spec workspace_path(t) :: {t, String.t}
  def workspace_path(state = %__MODULE__{job_counter: job, workspace_base: base}) do
    new_state = %__MODULE__{state | job_counter: job + 1}
    path = Path.join([base, Atom.to_string(node), "#{job}"])
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
  def handle_info({:EXIT, pid, _reason}, state = %__MODULE__{processes: processes}) do
    new_state = case processes |> Map.get(pid) do
      nil -> Logger.error ("Unknown linked pid #{inspect pid}")
             Logger.error "State: #{inspect state}"
             state
      url -> EventCenter.sync_notify({:worker, :execute, {:crashed, url}})
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

  @doc """
  __Internal function!__

  Execute a BaumeisterFile. The following steps are required:

  * Create a new workspace directory
  * extract the workspace from the url with the proper SCM plugin
  * cd into the directory
  * execute the command from the `bmf`
  * remove the workspace directory
  * return the output and returncode from the command
  """
  @spec execute_bmf(String.t, Baumeister.BaumeisterFile.t, String.t) :: {String.t, integer}
  def execute_bmf(url, bmf) do
    tmpdir = System.tmp_dir!()
    workspace = Path.join(tmpdir, "baumeister_workspace")
    execute_bmf(url, bmf, workspace)
  end
  def execute_bmf(url, bmf, workspace) do
    # make workspace dir
    :ok = File.mkdir_p!(workspace)
    # extract from `url`
    # cd into workspace ==> siehe System.cmd!
    # execute command
    {shell, arg1}  = case bmf.os do
      :windows -> {"cmd.exe", "/c"}
      _unix -> {"/bin/sh", "-c"}
    end
    {out, rc} = System.cmd(shell, [arg1, bmf.command], [cd: workspace, stderr_to_stdout: true])
    # remove the directory
    :ok = File.rmdir! workspace
    {out, rc}
  end

  @doc """
  __Internal function!__

  Detects the capabilities of the current worker. Initial set
  considers the operating system, the CPU, and the existence of
  git and mix. Future version may have many more capabilities
  to be checked.
  """
  @spec detect_capabilities() :: %{atom => any}
  def detect_capabilities() do
    [:os, :cpu, :git, :mix]
    |> Enum.map(&detect_capability/1)
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
