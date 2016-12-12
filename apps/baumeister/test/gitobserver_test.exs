defmodule Baumeister.GitObserverTest do
  use ExUnit.Case

  require Logger
  alias Git, as: GitLib
  alias Baumeister.Observer.Git, as: GitObs

  # Setup the repository and the paths to their working spaces
  setup do
    {:ok, make_temp_git_repo_with_some_content()}
  end

  # test "our own repo does provide remotes from github" do
  #   # our own current directory, we are in ./apps/baumeister
  #   invalid_repo = GitLib.new("../..")
  #   {:error, _} = GitLib.ls_remote(invalid_repo)
  # end

  test "some git features", %{repo: repo} do
    # repo = context[:repo]
    {:ok, refstring} = GitLib.ls_remote(repo)
    refs = GitObs.parse_refs(refstring)

    assert %{} = refs
    IO.inspect(refs)
    assert Map.has_key?(refs, "HEAD")
    assert Map.has_key?(refs, "refs/heads/master")
  end

  test "Create new remote refs", context do
    repo = context[:repo]
    repo_path = context[:repo_path]
    parent_repo = context[:parent_repo]
    parent_repo_path = context[:parent_repo_path]

    {:ok, refstring} = GitLib.ls_remote(repo)
    refs = GitObs.parse_refs(refstring)

    # update the README.md on the parent, but on a branch
    {:ok, _} = GitLib.checkout(parent_repo, ["-b", "feature/branch1"])
    readme = Path.join(parent_repo_path, "README.md")
    :ok = File.touch(readme)
    {:ok, _} = GitLib.add(parent_repo, readme)
    {:ok, _}  = GitLib.commit(parent_repo, ["-m", "touched", "--allow-empty", readme])

    # check what has changed.
    {:ok, refstring} = GitLib.ls_remote(repo)
    new_refs = GitObs.parse_refs(refstring)

    assert refs != new_refs
    assert refs["refs/heads/master"] == new_refs["refs/heads/master"]
    assert Map.has_key?(new_refs, "refs/heads/feature/branch1")
    assert refs["HEAD"] != new_refs["HEAD"]
    assert new_refs["HEAD"] == new_refs["refs/heads/feature/branch1"]
  end

  @spec make_temp_git_repo_with_some_content() :: %{atom => any}
  def make_temp_git_repo_with_some_content() do
    dirs = for p <- ~w(baumeister_git_parent, baumeister_git) do
      path = Path.join(System.tmp_dir!, p)
      File.rm_rf!(path)
      :ok = File.mkdir_p(path)
      assert is_binary(path)
      path
    end
    parent_path = dirs |> Enum.at(0)
    {:ok, parent_repo} = GitLib.init(parent_path)

    readme = Path.join(parent_path, "README.md")
    assert is_binary(readme)
    :ok = File.touch(readme)
    {:ok, _} = GitLib.add(parent_repo, readme)
    {:ok, _} = GitLib.commit(parent_repo, ~w(-a -m initial-commit))

    path = dirs |> Enum.at(1)
    {:ok, repo} = GitLib.clone([parent_path, path])
    [repo: repo, parent_repo: parent_repo, repo_path: path, parent_repo_path: parent_path]
  end

end
