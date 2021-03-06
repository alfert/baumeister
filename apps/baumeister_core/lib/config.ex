defmodule Baumeister.Config do
  @moduledoc """
  This is the storage of all current source configurations.
  Adding or removing a source to a running Baumeister system changes
  the state of this server.
  """

  use GenServer

  @type key :: any
  @type value :: any

  @doc """
  Starts the configuration server and configures a persistency
  solution. The default setting runs in memory only, and is
  currently the only configuration.
  """
  def start_link(persistence_config \\ :in_memory) do
    GenServer.start_link(__MODULE__, [persistence_config], name: __MODULE__)
  end

  @doc """
  All keys stored in the server.
  """
  @spec keys() :: [key]
  def keys() do
    GenServer.call(__MODULE__, :keys)
  end

  @doc """
  Put a key and a value into the server. It overwrites
  an existing value of the key.
  """
  @spec put(key, value) :: :ok
  def put(key, config) do
    GenServer.cast(__MODULE__, {:put, key, config})
  end

  @doc """
  Removes the key and its value.
  """
  @spec remove(key) :: :ok
  def remove(key) do
    GenServer.cast(__MODULE__, {:remove, key})
  end

  @doc """
  Returns the configuration for `key`. If `key` is not found,
  we return `:error`, otherwise `{:ok, config}`.
  """
  @spec config(key) :: {:ok, value} | :error
  def config(key) do
    GenServer.call(__MODULE__, {:config, key})
  end

  @doc """
  Stops the configuration server.
  """
  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  @doc """
  Removes all entries of the configuration server.
  """
  def remove_all() do
    GenServer.cast(__MODULE__, :remove_all)
  end

  ###################################################
  ##
  ## Callbacks
  ##
  ###################################################

  # only `:in_memory` is currently supported
  def init([:in_memory]) do
    {:ok, %{}}
  end

  def handle_call(:keys, _from, state) do
    {:reply, Map.keys(state), state}
  end
  def handle_call({:config, key}, _from, state) do
    {:reply, Map.fetch(state, key), state}
  end

  def handle_cast({:put, key, config}, state) do
    new_state = Map.put(state, key, config)
    {:noreply, new_state}
  end
  def handle_cast({:remove, key}, state) do
    {:noreply, Map.delete(state, key)}
  end
  def handle_cast(:remove_all, _state) do
    {:noreply, %{}}
  end

end
