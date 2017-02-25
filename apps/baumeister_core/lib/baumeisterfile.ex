defmodule Baumeister.BaumeisterFile do
  @moduledoc """
  Definition of the `BaumeisterFile` representation in Elixir.

  The source of a BaumeisterFile is a YAML-File, which is very closely
  defined to type `t`.
  """

  defmodule InvalidSyntax do
    defexception [:message]
  end

  @type os_type :: :macos | :linux | :windows

  defstruct command: "",
    os: :macos,
    language: ""

  @typedoc """
  The fields of a BaumeisterFile:
  * `command`: the command to build the project
  * `os`: the required operating sytem. Either `windows`, `linux` or `macos`
  * `language:` The required programming language environment. This is an open
  value, which is used to detect matching capabilities of the worker nodes.
  """
  @type t :: %__MODULE__{command: String.t, os: os_type, language: String.t}

  @doc """
  Parses a BaumeisterFile string representation and returns its
  internal representation. In case of an invalid file, the exception
  `InvalidSyntax` is raised.

    iex> Baumeister.BaumeisterFile.parse!("command: hey")
    %Baumeister.BaumeisterFile{command: "hey"}
  """
  @spec parse!(String.t) :: BaumeisterFile.t
  def parse!(contents) do
    map = YamlElixir.read_from_string(contents)
    # {map, _bindings} = Code.eval_string(contents, [], [])
    if not is_map(map), do: raise InvalidSyntax,
      message: "Must be a mapping with strings as keys!"
    assign!(map)
  end

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
        value = map
          |> Map.fetch!(key)
          |> canonized_values(atom_key)
        Map.put(acc, atom_key, value)
      else
        raise(InvalidSyntax, message: "Unknown key #{key}")
      end
    end)
  end

  @doc """
  Maps value variations to their proper Baumeister values. Currently,
  only operating system names are mapped.
  """
  @spec canonized_values(any, atom) :: atom | any
  def canonized_values("macos", :os), do: :macos
  def canonized_values("darwin", :os), do: :macos
  def canonized_values("windows", :os), do: :windows
  def canonized_values("linux", :os), do: :linux
  def canonized_values(value, _), do: value

end # of Baumeister.BaumeisterFile
