defmodule Baumeister.Observer.Git do

  alias Baumeister.Observer
  alias Baumeister.Observer.Coordinate
  @moduledoc """
  An `Observer` Plugin that checks if new commits are available for
  the given remote repository. It uses a polling approach.

  Design decisions are:

  * using local repository, cloned from the remote repository to detect the BaumeisterFiles.
  * all remote references from the remote repository are considered, this means
    usually all branches, tags and pull requests. Remote references are detected
    with the `git ls-remote` command.
  * Currently, there is no possibility of reducing the set of interesting
    references with regexp or similar. This may come in future versions.
  * Each call of `observe` function checks for remote references and detects
    any differences. If they exist, they will be returned as `t:Baumeister.Observer.Coordinate.t/0`.
    Since this plugin uses polling, the `observe` function has not delay functionality.
    For that reason the `Baumeister.Observer.Delay` plugin can be used.

  Instead of polling, we could use the `post-receive` hook of Git to sent a
  notification to Baumeister. This would require a web-server approach inside
  of Baumeister. An interesting idea for future versions of Baumeister.

  """
  @behaviour Baumeister.Observer

  @typedoc """
  A type for sha values.
  """
  @type hash_t :: String.t

  @typedoc """
  The state of the Git Plugin:

  * `url`: the URL of the remote Git repository
  * `repo`: the repository datastructure for of the remote repo
  * `local_path`: the path to the locally cloned repository
  * `local_repo`: the repository datastructure for of the local repo
  * `refs`: a mapping of remote references to their hased from the remote repo
  """
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
      * `ref`: the reference from the remote repository
      * `sha`: the sha value of the version
      * `name`: a human understandable name of the version

    """
    @type t :: %__MODULE__{ref: String.t, sha: Observer.Git.hash_t, name: String.t}
    defstruct ref: "", sha: "", name: ""

    @doc """
    Creates a proper Version out of `ref` and `sha`. Identifies
    the branch, tag, GitHub Pull Request, BitBucket Pull Request.
    If `ref` points to something different, the full `ref` will
    become the name.
    """
    @spec make(String.t, Observer.Git.hash_t) :: t
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
  Configure the plugin with the URL of the remote repository.
  """
  @spec init(String.t) :: {:ok, any}
  def init(url) when is_binary(url) do
    state = init_repos(url)
    refs = state.local_repo
    |> Git.ls_remote()
    |> parse_refs()
    {:ok, %__MODULE__{state | refs: refs}}
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
    set_user_config(local_repo)
    %__MODULE__{url: url, repo: repo, local_path: local_path, local_repo: local_repo}
  end

  @doc """
  Sets the email address and the user for the git repository. The settings
  are taken from the Application's configuration with the keys `:git_email` and
  `git_user`.
  """
  def set_user_config(repo) do
    email = Application.get_env(:baumeister, :git_email, "baumeister@example.com")
    user = Application.get_env(:baumeister, :git_user, "Baumeister")
    {:ok, _} = Git.config(repo, ["--local", "user.email", email])
    {:ok, _} = Git.config(repo, ["--local", "user.name", user])
  end

  @doc """
  Checks the remote references and returns for each modified
  or new reference a positive return, such that a build is triggered.
  """
  @spec observe(state :: t) :: Observer.observer_return_t
  def observe(state = %__MODULE__{refs: refs}) do
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

  @doc """
  Creates a new coordinate from the plugin's state and the given
  remote Git reference `ref` and its sha value `sha`.
  """
  def make_coordinate(state = %__MODULE__{}, ref, sha) do
    %Observer.Coordinate{
      observer: __MODULE__,
      url: state.url,
      version: Version.make(ref, sha)
    }
  end

  @doc """
  Updates the local repository `repo` from the remote repository `remote_repo`
  and checks out the reference `ref` and the sha value `sha`.

  The `fetch` command runs against the remote repository, merges the remote
  reference in the corresponding local branch even if not fast-forward merge is
  possible (`+` in the reference). Finally, the checkout results in a
  detached head, which is no problem, since we do not checkin anything in
  this repository.
  """
  @spec update_from_remote(Git.Repository.t, Git.Repository.t, String.t, hash_t) :: :ok
  def update_from_remote(repo, remote_repo, ref, sha) do
    {:ok, _} = Git.fetch(repo, [remote_repo.path, "+" <> ref])
    {:ok, _} = Git.checkout(repo, [sha]) # |> IO.inspect
    :ok
  end

  @doc """
  Updates the local repository `repo` from the remote repository `remote_repo`
  and returns the BaumeisterFile from version `sha`.
  """
  @spec read_baumeister_file(Git.Repository.t, Git.Repository.t, String.t, hash_t) :: String.t
  def read_baumeister_file(repo, remote_repo, ref, sha) do
    :ok = update_from_remote(repo, remote_repo, ref, sha)
    {:ok, content} = File.read(Path.join(repo.path, "BaumeisterFile"))
    content
  end


  @doc """
  Parses the output of `git ls-remote` and returns a mapping
  of remote references and their sha1 values.
  """
  @spec parse_refs({:ok, String.t}) :: %{String.t => hash_t}
  def parse_refs({:ok, refs}), do: parse_refs(refs)
  @spec parse_refs(String.t) :: %{String.t => hash_t}
  def parse_refs(refs) do
    refs
    |> String.split("\n")
    |> Stream.map(fn s -> s |> String.split("\t") end)
    # this filters the origin address information (without \t)
    |> Stream.filter(&match?([_,_], &1))
    |> Stream.filter(fn [_ref, k] -> k != "HEAD" end)
    |> Stream.map(fn [ref, k] when is_binary(ref)-> {k, ref} end)
    |> Enum.into(%{})
  end

  @doc """
  Calculates the changed reference sets between `old_refs` and `new_refs`.

  Changed references have either a new name, i.e. the key is new, or the
  sha value has changed.
  """
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

  @doc """
  Does a checkout of the given `coordinate`, relative to the `workdir` given.
  The newly created directory is returned.
  """
  @spec checkout(Coordinate.t, String.t) :: String.t
  def checkout(coordinate, workdir) do
    local_path = workdir
    |> Path.expand()
    |> Path.join(coordinate.version.sha)
    # remove the directory, if it already exists otherwise clone will fail
    {:ok, _} = File.rm_rf(local_path)
    {:ok, local_repo} = Git.clone([coordinate.url, local_path])
    {:ok, _} = Git.checkout(local_repo, [coordinate.version.sha])
    local_path
  end
end
