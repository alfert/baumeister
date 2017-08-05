defmodule Baumeister do

  @moduledoc """
  This is the connecting module, that combines the observer part of Baumeister
  with the job execution part. It also provides the main API for Baumeister
  in terms of embedding it into other applications, such as a Phoenix-based
  Web UI.
  """
  alias Baumeister.BaumeisterFile
  alias Baumeister.Observer.Coordinate
  alias Baumeister.Observer
  alias Baumeister.Config
  alias Baumeister.Coordinator

  require Logger

  defmodule BuildEvent do
    @moduledoc """
    Defines the event structure emitted during a build.
    """

    @typedoc """
    The action events during a build, counted by `event_counter`:
    * `start`: the build has just started, nothing has happened yet
    * `log`: some information about build activities. `data` is either a
      a single row as string or many lines depending on the operating system
      and build job running
    * `result`: the final event, `data` contains the return code where
      a `0` means success and anything else means failure.
    """
    @type action_type :: nil | :start | :log | :result

    @type t :: %__MODULE__{
      build_counter: non_neg_integer,
      coordinate: Coordinate.t,
      event_counter: non_neg_integer,
      action: action_type,
      data: nil | integer | String.t | [String.t]
    }
    defstruct build_counter: 0, coordinate: %Coordinate{},
      event_counter: 0, action: nil, data: nil

    @doc """
    Creates a new build event, typically used as the start of of
    sequence of actions.
    """
    @spec new(Coordinate.t, pos_integer) :: t
    def new(%Coordinate{} = coordinate, build_number) when
          is_integer(build_number) and build_number > 0 do
      %__MODULE__{coordinate: coordinate, build_counter: build_number}
    end

    @doc """
    Takes a build event and adds build action information. The
    `event_counter` is incremented.
    """
    @spec action(t, action_type, any) :: t
    def action(be = %__MODULE__{event_counter: ec}, action, data \\ nil) do
      %__MODULE__{be | event_counter: ec + 1, action: action, data: data}
    end
  end

  defmodule LogEvent do
    @moduledoc """
    Defines the event structure of observers and working for events unrelated
    to a build execution.
    """
    @type t :: %__MODULE__{}

    defstruct role: :nil, action: nil, data: nil
  end

  # Storing some information about projects in the in-memory configuration store.
  defstruct name: "", url: "", plugins: [], enabled: false, observer: nil,
    build_counter: 0

  @doc """
  Executes the commands defined in the BaumeisterFile on a node that
  fits to the settings (e.g. OS) and on which the repository at the
  Coordinate will be checked out.
  """
  @spec execute(Coordinate.t, BaumeisterFile.t) :: {:ok, reference} | {:error, any}
  def execute(coordinate, bmf) do
    Logger.info("Execute bmf #{inspect bmf} for coord #{inspect coordinate}")
    with {:ok, build} <- increment_build_counter(coordinate) do
      case Coordinator.add_job(coordinate, bmf, build) do
        {:ok, ref} -> {:ok, ref}
        {:unsupported_feature, feature} ->
          Logger.error("An unsupported feature <#{inspect feature}> was requested for coordinate #{inspect coordinate}")
          {:error, :unsupported_feature}
      end
    end
  end

  @doc """
  Adds a new project.

  The `project_name` is the key and must be unique and not used. The `url`
  must be a valid Git URL, since Git is the only supported repository observer.
  The `plugin_list` configures the list of observer plugins. They must be given
  in the wished order of execution.
  """
  @spec add_project(String.t, String.t, [Observer.plugin_config_t]) :: :ok
  def add_project(project_name, url, plugin_list) when is_binary(project_name) do
    case Config.config(project_name) do
      {:ok, _} -> {:error, "Project '#{project_name}' already exists"}
      _ ->
        :ok = Config.put(project_name,
          %__MODULE__{name: project_name, url: url, plugins: plugin_list})
    end
  end

  @doc """
  Enables the project and let the observer do its work.
  """
  @spec enable(String.t) :: boolean
  def enable(project_name) do
    with {:ok, project} <- Config.config(project_name),
      false <- project.enabled
      do
        {:ok, observer} = Supervisor.start_child(Baumeister.ObserverSupervisor,
          [project_name])
        # spawn a process that monitors the observers and
        # updates the status in the config database
        _pid = spawn(fn -> ref = Process.monitor(observer)
          receive do
            {:DOWN, ^ref, :process, _whatever_pid, _reason} -> put_disabled_project(project_name)
          end
        end)
        :ok = Observer.configure(observer, project.plugins)
        :ok = Config.put(project_name, %__MODULE__{project | enabled: true,
          observer: observer})
        :ok = Observer.run(observer)
        true
      end
  end

  defp put_disabled_project(project_name) do
    {:ok, project} = Config.config(project_name)
    put_disabled_project(project_name, project)
  end
  defp put_disabled_project(project_name, project) do
    :ok = Config.put(project_name, %__MODULE__{project | enabled: false,
      observer: nil})
  end

  @doc """
  Disables the project and stop the observer's work.
  """
  @spec disable(String.t) :: boolean | :error
  def disable(project_name) do
    with {:ok, project} <- Config.config(project_name),
      true <- project.enabled
      do
        :ok = Observer.stop(project.observer, :stop)
        put_disabled_project(project_name, project)
      end
  end

  @doc """
  Disables and deletes a project. Returns `:error` if the project does
  not exist.
  """
  @spec delete(String.t) :: :ok | :error
  def delete(project_name) do
    case disable(project_name) do
      :error -> :error
      _      -> Config.remove(project_name)
    end
  end

  @doc """
  Updates the project. For that reason the project is disabled,
  to stop observers and workers. After that, the project is updated
  in the configuration and and the project in enabled again, if it
  enabled before.
  """
  def update(project_name, url, plugin_list) do
    case Config.config(project_name) do
      {:ok, project} ->
        disable(project_name)
        :ok = Config.put(project_name,
          %__MODULE__{name: project_name, url: url, plugins: plugin_list})
        enable(project.enabled)
        :ok
      _ -> add_project(project_name, url, plugin_list)
    end
  end

  @doc """
  Increments the build_job in the configuration and returns
  the new build number.
  """
  @spec increment_build_counter(String.t | Coordinate.t) :: {:ok, pos_integer} | {:error, any}
  def increment_build_counter(%Coordinate{project_name: project_name}) do
    increment_build_counter(project_name)
  end
  def increment_build_counter(project_name) do
    with {:ok, project} <- Config.config(project_name) do
        new_project = %__MODULE__{project | build_counter: 1 + project.build_counter}
        :ok = Config.put(project_name, new_project)
        {:ok, new_project.build_counter}
    end
  end
end
