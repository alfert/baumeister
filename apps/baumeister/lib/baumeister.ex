defmodule Baumeister do

  defmodule BaumeisterFile do
    @moduledoc """
    Definition of the `BaumeisterFile` representation in Elixir.
    """

    defmodule InvalidSyntax do
      defexception [:message]
    end

    @type os_type :: :macos | :linux | :windows

    defstruct(
      [command: "", os: :macos])

    @type t :: %BaumeisterFile{command: String.t, os: os_type}

    @doc """
    Takes a map of strings to any values and assigns it to a
    `BaumeisterFile` struct. Only known keys are converted,
    an unknown key raises an `InvalidSyntax` error.
    """
    @spec assign!(%{String.t => any}) :: t
    def assign!(map) do
      bmf = %__MODULE__{}
      valid_keys =
        bmf
        |> Map.keys()
        |> Enum.map(&(Atom.to_string(&1)))
        |> MapSet.new()

      map
      |> Map.keys
      |> Enum.reduce(bmf, fn(key, acc) ->
        if MapSet.member?(valid_keys, key) do
          atom_key = String.to_atom(key)
          Map.put(acc, atom_key, Map.fetch!(map, key))
        else
          raise(InvalidSyntax, message: "Unknown key #{key}")
        end
      end)
    end

  end # of Baumeister.BaumeisterFile

  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Baumeister.Worker.start_link(arg1, arg2, arg3)
      # worker(Baumeister.Worker, [arg1, arg2, arg3]),
      supervisor(Task.Supervisor, [[name: Baumeister.ObserverSupervisor]]),
      worker(Baumeister.Coordinator, [[name: Baumeister.Coordinator.name()]]),
      worker(Baumeister.Config, [Application.get_env(:baumeister, :persistence)])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Baumeister.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Parses a BaumeisterFile string representation and returns its
  internal representation. In case of an invalid file, an exception
  is raised.

    iex> Baumeister.parse!("command: hey")
    %Baumeister.BaumeisterFile{command: "hey"}
  """
  @spec parse!(String.t) :: BaumeisterFile.t
  def parse!(contents) do
    map = YamlElixir.read_from_string(contents)
    # {map, _bindings} = Code.eval_string(contents, [], [])
    if not is_map(map), do: raise BaumeisterFile.InvalidSyntax,
      message: "Must be a mapping with strings as keys!"
    BaumeisterFile.assign!(map)
  end

  @doc """
  Executes the commands defined in the BaumeisterFile on a node that
  fits to the settings (e.g. OS) and on which the repository at the
  URL will be checked out.
  """
  @spec execute(String.t, BaumeisterFile.t) :: :ok
  def execute(_url, _job) do
    :ok
  end
end
