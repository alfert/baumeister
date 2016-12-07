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

  @type hash :: String.t

  @doc """
  Configure the plugin with URL of the repository
  """
  @spec init(String.t) :: {:ok, any}
  def init(url) do
    {:ok, url}
  end

  @doc """
  Decrements the counter and stops after the counter reaches `0`.
  """
  @spec observe(state :: String.t) :: Observer.observer_return_t
  def observe(_url), do: {:error, :not_implemented_yet}

  @spec parse_refs(String.t) :: %{String.t => hash}
  def parse_refs(refs) do
    refs
    |> String.split("\n")
    |> Stream.map(fn s -> s |> String.split("\t") end)
    |> Stream.filter(&match?([_,_], &1))
    |> Stream.map(fn [ref, k] -> {k, ref} end)
    |> Enum.into(%{})
  end

end
