defmodule Baumeister.Observer.Git do

  alias Baumeister.Observer
  @moduledoc """
  An `Observer` Plugin that checks if new commits are available for
  the given repository. It uses a polling approach.

  Design questions are:

  * Do we have a repository locally, which mirrors the remote repo, required
    for all sorts of `git fetch`? ==> YES!
  * Do we need to store locally a last hash value to ask for any changes after
    that hash? ==> YES
  * Are we interested in a specific set of branches or simply all branches?
    Assumption: This is in option, per default configured to match all branches
    (`.*` as a regexp)
  * Do we really need to poll? Why not use a `post-receive` hook in git
    to do a curl towards the Baumeister server. This would mean that we may
    need to provide a more general web-hook framework for Baumeister, but
    that's generally ok and required for integrating GitHub or BitBucket.
    ==> Hooks will come in another version of the Git Plugin
  * Use fast remote polling via `git ls-remote` ==> YES

  """
  @behaviour Baumeister.Observer

  @type hash_t :: String.t

  @type t :: %__MODULE__{
    url: String.t,
    repo: Git.Repository.t,
    local_path: String.t,
    local_repo: Git.Repository.t,
    refs: %{String.t => hash_t}
  }
  defstruct url: "", repo: nil,
    local_path: "",
    local_repo: nil,
    refs: %{}

  defmodule Version do
    @moduledoc """
    A version specifier for git:
      * the reference from the remote repository
      * the sha value of the version
      * a human understandable name of the version

    """
    defstruct ref: "", sha: "", name: ""

    @doc """
    Creates a proper Version out of `ref` and `sha`. Identifies
    the branch, tag, GitHub Pull Request, BitBucket Pull Request.
    If `ref` points to something different, the full `ref` will
    become the name.
    """
    def make(ref, sha) do
      name = case ref do
        "refs/heads/" <> branch -> "Branch " <> branch
        "refs/tags/" <> tag     -> "Tag " <> tag
        "refs/pull" <> pr -> "Pull Request " <> String.replace_suffix(pr, "/head", "")
        _ -> ref
      end
      %__MODULE__{ref: ref, sha: sha, name: name}
    end
  end

  @doc """
  Configure the plugin with URL of the repository
  """
  @spec init(String.t) :: {:ok, any}
  def init(url) when is_binary(url) do
    state = init_repos(url)
    refs = state.local_repo
    |> Git.ls_remote()
    |> parse_refs()
    {:ok, update_in(state.refs, fn _ -> refs end)}
  end

  # creates the local administrative repository and returns the observer state.
  defp init_repos(url) do
    repo = Git.new(url)

    admin_path = Application.get_env(:baumeister, :admin_data_dir,
      Path.join(System.tmp_dir!(), "baumeister_admin"))
    local_path = Path.join(admin_path, Path.basename(url))
    # remove the directory, if it already exists otherwise clone will fail
    {:ok, _} = File.rm_rf(local_path)
    {:ok, local_repo} = Git.clone([url, local_path])
    %__MODULE__{url: url, repo: repo, local_path: local_path, local_repo: local_repo}
  end

  @doc """
  Checks the remote references and returns for each modified
  or new reference a positive return, such that a build is triggered.
  """
  @spec observe(state :: t) :: Observer.observer_return_t
  def observe(state = %__MODULE__{repo: repo, refs: refs}) do
    # get new refs, check the difference and return the differences.
    # new state os the map of new refs.
    #
    new_refs = state.local_repo
    |> Git.ls_remote()
    |> parse_refs()
    changed = changed_refs(refs, new_refs)
    new_state =  %__MODULE__{state | refs: new_refs}
    case Map.keys(changed) do
      [] -> {:ok, new_state}
      _ -> result = changed
        |> Map.to_list()
        |> Enum.map(fn {ref, sha} ->
            {make_coordinate(state, ref, sha),
              read_baumeister_file(state.local_repo, state.repo, ref, sha)}
           end)
        {:ok, result, new_state}
    end
  end


  def make_coordinate(state = %__MODULE__{}, ref, sha) do
    %Observer.Coordinate{
      observer: __MODULE__,
      url: state.url,
      version: Version.make(ref, sha)
    }
  end

  def update_from_remote(repo, remote_repo, ref, sha) do
    "refs/heads/" <> branch = ref
    {:ok, _} = Git.fetch(repo, [remote_repo.path, ref <> ":" <> ref])
    {:ok, _} = Git.checkout(repo, sha) # |> IO.inspect
    :ok
  end

  def read_baumeister_file(repo, remote_repo, ref, sha) do
    :ok = update_from_remote(repo, remote_repo, ref, sha)
    {:ok, content} = File.read(Path.join(repo.path, "BaumeisterFile"))
    content
  end


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
    # this filters the origin address information (without \t)
    |> Stream.filter(&match?([_,_], &1))
    |> Stream.filter(fn [_ref, k] -> k != "HEAD" end)
    |> Stream.map(fn [ref, k] -> {k, ref} end)
    |> Enum.into(%{})
  end

  @spec changed_refs(%{String.t => hash_t}, %{String.t => hash_t}) :: %{String.t => hash_t}
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
