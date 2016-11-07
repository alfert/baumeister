defmodule Baumeister.BaumeisterFile do
  @moduledoc """
  Definition of the `BaumeisterFile` representation in Elixir.
  """

  defmodule InvalidSyntax do
    defexception [:message]
  end

  @type os_type :: :macos | :linux | :windows

  defstruct(
    [command: "", os: :macos])

  @type t :: %__MODULE__{command: String.t, os: os_type}

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
