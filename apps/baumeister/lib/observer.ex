defmodule Baumeister.Observer do
  @moduledoc """
  Defines the API, which a specific observer has to implement.
  """
  alias Baumeister.EventCenter
  alias Baumeister.BaumeisterFile
  alias Baumeister.Observer

  @typedoc """
  A mapping between plugin name and its current state.
  """
  @type plugin_state :: %{atom => any}

  @typedoc """
  Allowed return values for an Observer Plugin:
  * `:ok` if everything went fine. We return the URL and BaumeisterFile.
  * `:error` somethings fails. Stops the Observer with a crash
  * `:stop` The Plugin decides, that the Observer should stop.
  """
  @type observer_return_t ::
    {:ok, String.t, String.t, any} |
    {:ok, any} |
    {:error, any, any} |
    {:stop, any}


  @doc """
  Initializes the observer. It is called with the observer's
  configuration as parameter. The return value is the state
  of the oberserver, which is passed to the `observer` function
  later on.
  """
  @callback init(config :: any) :: {:ok, any}

  @doc """
  The observer calls this function to observe the target repository.
  If anything interesting has happended, the functions returns with
  the URL of the target repository and the content of the `BaumeisterFile`,
  which is used to determine the nodes to execute the build.
  """
  @callback observe(state :: any) :: observer_return_t

  ###################################################
  ##
  ## Observer API
  ##
  ###################################################

  use GenServer
  require Logger

  defstruct state: %{}, observer_pid: nil,
    observer_fun: nil, init_fun: nil, name: "anonymous observer"

  @doc """
  Convenience function to start the observer and configure
  it with the singleton plugin `mod`.
  """
  def start_link(mod, configuration) when is_atom(mod) do
    {:ok, pid} = start_link(Atom.to_string(mod))
    :ok = configure(pid, mod, configuration)
    {:ok, pid}
  end
  @doc """
  Starts the oberver process
  """
  def start_link(name \\ "anonymous observer")  do
    Logger.debug "Start Observer #{name}"
    GenServer.start_link(__MODULE__, [name])
  end

  @doc """
  Configures the Observer with a list of plugin names and their
  initializations. This list is executed in reverse order.
  """
  def configure(observer, mod, config) do
    configure(observer, [{mod, config}])
  end
  def configure(observer, {mod, config}) do
    configure(observer, [{mod, config}])
  end
  def configure(observer, plug_list) when is_list(plug_list) do
    GenServer.call(observer, {:configure, plug_list})
  end

  @doc """
  Starts operating the observer.
  """
  def run(observer) when is_pid(observer) do
    GenServer.cast(observer, :run)
  end

  @doc """
  Executes an observer.
  """
  def execute(observer, url, baumeister_file) do
    GenServer.cast(observer, {:execute, url, baumeister_file})
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

  def init([name]) do
    {:ok, %__MODULE__{name: name}}
  end

  def handle_call({:configure, plug_list}, _from, state) do
    # create pipelines of plugins
    {observer_fun, init_fun} = plug_list
    |> Enum.reduce({fn s -> {:ok, s} end, fn s -> s end},
    fn {plug, config}, {combined_plug, combined_init} ->
      obs = fn(s) -> case do_observe(plug, s) do
          {:ok, s_new} ->
            combined_plug.(s_new)
          other ->
            Logger.debug("abort plug execution after: #{inspect other}")
            other # abort any other operations
        end
      end
      init = fn(s) ->
        {:ok, s_init} = plug.init(config)
        Map.put(s, plug, s_init)
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
  pipelin. It manages the state and coordinates the execution of
  plugin
  """
  @spec do_observe(atom, plugin_state) :: observer_return_t
  def do_observe(plug, state) do
    Logger.debug("do_observe: plug = #{inspect plug}, state = #{inspect state}")
    case state |> Map.fetch!(plug) |> plug.observe() do
      {:ok, url, bmf, s} ->
        Logger.debug("got url and bmf from plug #{inspect plug}")
        {:ok, state
          |> Map.put(:"$url", url)
          |> Map.put(:"$bmf", bmf)
          |> Map.put(plug, s)
        }
      {:ok, s} -> {:ok, Map.put(state, plug, s)}
      {:error, reason, s} ->
        {:error, reason, Map.put(state, plug, s)}
      {:stop, s} ->
        {:stop, Map.put(state, plug, s)}
    end
  end

  def handle_cast(:run, s = %__MODULE__{name: name, state: state, observer_pid: nil}) do
    # Start the oberserver as a distinct process, under supervision
    # control and linked to this server process
    parent_pid = self
    {:ok, pid} = Task.Supervisor.start_child(Baumeister.ObserverSupervisor,
      fn ->
        EventCenter.sync_notify({:observer, :start_observer, name})
        obs_state = s.init_fun.(state)
        exec_plugin(obs_state, s.observer_fun, name, parent_pid)
      end)
    {:noreply, %__MODULE__{s | observer_pid: pid}}
  end
  def handle_cast({:execute, url, baumeister_file}, state) do
    EventCenter.sync_notify({:observer, :execute, url})
    job = BaumeisterFile.parse!(baumeister_file)
    Baumeister.execute(url, job)
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
  @spec exec_plugin(plugin_state, (plugin_state -> observer_return_t), any, pid) :: :ok
  def exec_plugin(state, observer_fun, observer_name, observer) do
    EventCenter.sync_notify({:observer, :exec_observer, observer_name})
    case observer_fun.(state) do
      {:ok, new_s} ->
          url = Map.fetch!(new_s, :"$url")
          baumeister_file = Map.fetch!(new_s, :"$bmf")
          plug_state = new_s |> Map.drop([:"$url", :"$bmf"])
          Observer.execute(observer, url, baumeister_file)
          exec_plugin(plug_state, observer_fun, observer_name, observer)
      {:error, _reason, new_s} -> EventCenter.sync_notify{:observer, :failed_observer, observer_name}
          Observer.stop(observer, :error)
      {:stop, new_s } -> EventCenter.sync_notify{:observer, :stopped_observer, observer_name}
          Observer.stop(observer, :stop)
    end
    :ok
  end

end
