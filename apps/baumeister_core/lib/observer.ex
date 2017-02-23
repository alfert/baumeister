defmodule Baumeister.Observer do
  @moduledoc """
  The `Observer` module defines the observer process for each repository, but
  all particular observation processes require Observer plugins. These plugins
  must implement `Observer` behaviour.

  The observer come in two flavours:

  * a full observer plugin implements access to a repository and is used by
  both, observer and worker processes. Example: `Baumeister.Observer.Git`
  * an observer plugin takes part in the observation process, e.g. for a
  delay to reduce the amount of polling (`Baumeister.Observer.Delay`). These
  plugins do not implement the `checkout` function used by the worker processes.

  """
  alias Baumeister.EventCenter
  alias Baumeister.BaumeisterFile
  alias Baumeister.Observer

  defmodule Coordinate do
    @moduledoc """
    A Coordinate is a polymorphic reference to a repository
    and a specific version inside, depending on the repository
    and thus on the observer type.
    """

    @typedoc """
    A Baumeister coordinate holds a reference to repository by its
    `url`. The observer plugin, which is capable of handling the coordinate,
    is stored in the `observer` field. The `version` holds a specific
    version specicification, which can be interpreted properly by the
    `observer` plugin.
    """
    @type t :: %__MODULE__{
      url: String.t,
      observer: module,
      version: any
    }
    defstruct url: "",
      observer: nil,
      version: nil

  end

  @typedoc """
  The state of a plugin can by any value.
  """
  @type plugin_state :: any

  @typedoc """
  A mapping between plugin name and its current state.
  """
  @type plugin_state_map :: %{module => plugin_state}

  @typedoc """
  A plugin and its initial configuration.
  """
  @type plugin_config_t :: {module, any}

  @typedoc """
  A pair of the repository Coordinate to checkout and corresponding
  BaumeisterFile
  """
  @type result_t :: {Coordinate.t, String.t}

  @typedoc """
  Allowed return values for an Observer Plugin:
  * `{:ok, results, state}`: A list of coordinates and BaumeisterFiles is returned
  which will be executed in the next step.
  * `{:ok, state}`: everything went fine, but no changes occured in the observed
  repository. The next round of observation will follow.
  * `:error` somethings fails. Stops the Observer with a crash.
  * `:stop` The plugin list decides, that the Observer should stop.
  """
  @type observer_return_t ::
    {:ok, [result_t, ...], plugin_state} |
    {:ok, plugin_state} |
    {:error, any, any} |
    {:stop, any}


  @doc """
  Initializes the observer plugin. It is called with the observer's
  configuration as parameter. The return value is the state
  of the oberserver plugin, which is passed to the `observer` function
  later on.
  """
  @callback init(config :: any) :: {:ok, plugin_state}

  @doc """
  The observer calls this function to observe the target repository.
  If anything interesting has happended, the functions returns with
  the URL of the target repository and the content of the `BaumeisterFile`,
  which is used to determine the nodes to execute the build.
  """
  @callback observe(state :: plugin_state) :: observer_return_t


  @doc """
  Implements the checkout command for a build directory for
  the given coordinate. The newly created directory is returned.
  """
  @callback checkout(coord :: Coordinate.t, work_dir :: String.t) :: String.t

  ###################################################
  ##
  ## Observer API
  ##
  ###################################################

  use GenServer
  require Logger

  defstruct state: %{}, observer_pid: nil,
    observer_fun: nil, init_fun: nil, name: "anonymous observer",
    executor_fun: nil

  @doc """
  Starts the oberver process with the given name. The observer
  is not configured yet.
  """
  @spec start_link(String.t, (Coordinate.t, String.t -> :ok)) :: {:ok, pid}
  def start_link(name \\ "anonymous observer", exec_fun \\ &run_baumeister/2)
  def start_link(name, exec_fun)  do
    # Logger.debug "Start Observer #{name} with exec_fun #{inspect exec_fun}"
    GenServer.start_link(__MODULE__, [name, exec_fun])
  end

  defp run_baumeister(coord, baumeister_file) do
    job = BaumeisterFile.parse!(baumeister_file)
    Baumeister.execute(coord, job)
  end

  @doc """
  Configures the observer with a single plugin `mod` and
  configuration `config`.
  """
  @spec configure(pid, module, any) :: :ok
  def configure(observer, mod, config) do
    configure(observer, [{mod, config}])
  end

  @doc """
  Configures the Observer with a list of plugin names and their
  initializations. This list is executed in reverse order.
  """
  @spec configure(pid, [plugin_config_t]) :: :ok
  def configure(observer, plug_list) when is_list(plug_list) do
    GenServer.call(observer, {:configure, plug_list})
  end

  @doc """
  Starts operating the observer: The sequence of configured plugins
  is executed until the process stops.
  """
  def run(observer) when is_pid(observer) do
    GenServer.cast(observer, :run)
  end

  @doc """
  Executes an observer, taking a coodinate and baumeister file.
  The BaumeisterFile is parsed and given together with the
  coordinate to the Baumeister Coordinator to find a worker
  for executionn.
  """
  def execute(observer, %Coordinate{} = coordinate, baumeister_file) when
    is_binary(baumeister_file) do
    GenServer.cast(observer, {:execute, coordinate, baumeister_file})
  end

  @doc """
    Stops the observer. Reason can either be `:stop` for normal
    stops, and `:error` for failing observers.
  """
  @spec stop(pid, reason :: :stop | :error) :: :ok
  def stop(observer, :stop) do
    :ok = GenServer.stop(observer)
  end
  def stop(observer, :error) do
    :ok = GenServer.stop(observer, :error)
  end

  ###################################################
  ##
  ## Observer Callback Implementation
  ##
  ###################################################

  @doc false
  def init([name, exec_fun]) do
    # Logger.debug("Observer init for #{name} with exec_fun #{inspect exec_fun}")
    {:ok, %__MODULE__{name: name, executor_fun: exec_fun}}
  end

  @doc false
  def handle_call({:configure, plug_list}, _from, state) do
    # create pipelines of plugins
    {observer_fun, init_fun} =
        Enum.reduce(plug_list, {fn s -> {:ok, s} end, fn s -> s end},
    fn {plug, config}, {combined_plug, combined_init} ->
      obs = fn(s) -> case do_observe(plug, s) do
          {:ok, s_new} ->
            combined_plug.(s_new)
          other ->
            # Logger.debug("abort plug execution after: #{inspect other}")
            other # abort any other operations
        end
      end
      init = fn(s) ->
        {:ok, s_init} = plug.init(config)
        s
        |> Map.put(plug, s_init)
        |> combined_init.()
      end
      {obs, init}
    end)
    # Reset any plugin state information. The plugin state will be
    # initialized when the pipeline is run the first time
    {:reply, :ok, %__MODULE__{state |
      observer_fun: observer_fun, init_fun: init_fun, state: %{}}}
  end

  @doc """
  __INTERNAL FUNCTION: NO API __

  This is the function which is called for each step within the plugin
  pipeline. It manages the state and coordinates the execution of
  plugin.
  """
  @spec do_observe(atom, plugin_state_map) :: observer_return_t
  def do_observe(plug, state) do
    # Logger.debug("do_observe: plug = #{inspect plug}, state = #{inspect state}")
    case state |> Map.fetch!(plug) |> plug.observe() do
      {:ok, result, s} when is_list(result) ->
        # Logger.debug("got coordinate and bmf from plug #{inspect plug}")
        {:ok, state
          |> Map.put(:"$result", result)
          |> Map.put(plug, s)
        }
      {:ok, s} -> {:ok, Map.put(state, plug, s)}
      {:error, reason, s} ->
        {:error, reason, Map.put(state, plug, s)}
      {:stop, s} ->
        {:stop, Map.put(state, plug, s)}
    end
  end

  @doc false
  def handle_cast(:run, s = %__MODULE__{name: name, state: state, observer_pid: nil}) do
    # Start the oberserver as a distinct process, under supervision
    # control and linked to this server process
    parent_pid = self()
    {:ok, pid} = Task.Supervisor.start_child(Baumeister.ObserverTaskSupervisor,
      fn ->
        EventCenter.sync_notify({:observer, :start_observer, name})
        obs_state = s.init_fun.(state)
        exec_plugin(obs_state, s.observer_fun, name, parent_pid)
      end)
    {:noreply, %__MODULE__{s | observer_pid: pid}}
  end
  def handle_cast({:execute, coordinate, baumeister_file}, state) do
    EventCenter.sync_notify({:observer, :execute, coordinate})
    # job = BaumeisterFile.parse!(baumeister_file)
    # Baumeister.execute(coordinate, job)
    state.executor_fun.(coordinate, baumeister_file)
    # This works only, if `run()` is asynchronous
    # Baumeister.Observer.run(self)
    {:noreply, %__MODULE__{state | observer_pid: nil}}
  end

  @doc """
  __INTERNAL FUNCTION__

  Executes a plugin with a given `state` and `observer_function`.
  In events, the `observer_name` is used for reference and
  to the `observer` the results are communicated. That either leads
  to executing the bmf or to stop the `observer`.
  """
  @spec exec_plugin(plugin_state_map, (plugin_state_map -> observer_return_t), any, pid) :: :ok
  def exec_plugin(state, observer_fun, observer_name, observer) do
    EventCenter.sync_notify({:observer, :exec_observer, observer_name})
    case observer_fun.(state) do
      {:ok, new_s} ->
          # Logger.debug("exec_plugin: new_s = #{inspect new_s}")
          new_s
          |> Map.get(:"$result", [])
          |> Enum.each(fn {coordinate, baumeister_file} ->
            Observer.execute(observer, coordinate, baumeister_file)
          end)
          plug_state = Map.drop(new_s, [:"$result"])
          exec_plugin(plug_state, observer_fun, observer_name, observer)
      {:error, _reason, _new_s} -> EventCenter.sync_notify{:observer, :failed_observer, observer_name}
          Observer.stop(observer, :error)
      {:stop, _new_s} -> EventCenter.sync_notify{:observer, :stopped_observer, observer_name}
          Observer.stop(observer, :stop)
    end
    :ok
  end

end
