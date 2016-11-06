defmodule Baumeister.Observer do
  alias Baumeister.EventCenter

  @moduledoc """
  Defines the API, which a specific observer has to implement.
  """

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
  @callback observe(state :: any) :: {:ok, String.t, String.t} | :error

  ###################################################
  ##
  ## Observer API
  ##
  ###################################################

  use GenServer

  defstruct [:mod, :state, :observer_pid]

  def start_link(mod, configuration) when is_atom(mod) do
    GenServer.start_link(__MODULE__, [mod, configuration])
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

  ###################################################
  ##
  ## Observer Callback Implementation
  ##
  ###################################################

  def init([mod, configuration]) do
    {:ok, state} = mod.init(configuration)
    {:ok, %__MODULE__{mod: mod, state: state}}
  end

  def handle_cast(:run, s = %__MODULE__{mod: mod, state: state, observer_pid: nil}) do
    # Start the oberserver as a distinct process, under supervision
    # control and linked to this server process
    parent_pid = self
    {:ok, pid} = Task.Supervisor.start_child(Baumeister.ObserverSupervisor,
      fn ->
        EventCenter.sync_notify({:observer, :start_observer, mod})
        {:ok, url, baumeister_file} = mod.observe(state)
        Baumeister.Observer.execute(parent_pid, url, baumeister_file)
      end)
    {:noreply, %__MODULE__{s | observer_pid: pid}}
  end
  def handle_cast({:execute, url, baumeister_file}, state) do
    EventCenter.sync_notify({:observer, :execute, url})
    job = Baumeister.parse!(baumeister_file)
    Baumeister.execute(url, job)
    # This works only, if `run()` is asynchronous
    Baumeister.Observer.run(self)
    {:noreply, %__MODULE__{state | observer_pid: nil}}
  end

end
