defmodule Baumeister.Observer.Git do

  alias Baumeister.Observer
  @moduledoc """
  An `Observer` Plugin that checks if new commits are available for
  the given repository. It uses a polling approach.

  Design questions are:

  * Do we have a repository locally, which mirrors the remote repo, required
    for all sorts of `git fetch`?
  * Do we need to store locally a last hash value to ask for any changes after
    that hash?
  * Are we interested in a specific set of branches or simply all branches?
    Assumption: This is in option, per default configured to match all branches
    (`.*` as a regexp)
  * Do we really need to poll? Why not use a `post-receive` hook in git
    to do a curl towards the Baumeister server. This would mean that we may
    need to provide a more general web-hook framework for Baumeister, but
    that's generally ok and required for integrating GitHub or BitBucket.
  * Use fast remote polling via `git ls-remote`

  """
  @behaviour Baumeister.Observer

  @type hash_t :: String.t

  @type t :: %__MODULE__{
    url: String.t,
    refs: %{String.t => hash_t}
  }
  defstruct url: "", refs: %{}

  @doc """
  Configure the plugin with URL of the repository
  """
  @spec init(String.t) :: {:ok, any}
  def init(url) do
    refs = url
    |> Git.ls_remote()
    |> parse_refs()
    {:ok, %__MODULE__{url: url, refs: refs}}
  end

  @doc """
  Checks the remote references and returns for each modified
  or new reference a positive return, such that a build is triggered.
  """
  @spec observe(state :: t) :: Observer.observer_return_t
  def observe(_url), do: {:error, :not_implemented_yet}

  @doc """
  Parses the output of `git ls-remote` and returns a mapping
  of remote references and their sha1 values.
  """
  @spec parse_refs(String.t) :: %{String.t => hash_t}
  def parse_refs({:ok, refs}), do: parse_refs(refs)
  def parse_refs(refs) do
    refs
    |> String.split("\n")
    |> Stream.map(fn s -> s |> String.split("\t") end)
    |> Stream.filter(&match?([_,_], &1))
    |> Stream.map(fn [ref, k] -> {k, ref} end)
    |> Enum.into(%{})
  end

  def changed_refs(old_refs, new_refs) do
    changed_keys = new_refs
    |> Map.keys()
    |> Stream.filter(fn k ->
      # take only new refs or changed refs
      case Map.fetch(old_refs, k) do
        :error -> true
        _ -> Map.fetch!(old_refs, k) != Map.fetch!(new_refs, k)
      end
    end)
    Map.take(new_refs, changed_keys)
  end

end
