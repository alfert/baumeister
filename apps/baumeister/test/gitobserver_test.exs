defmodule Baumeister.GitObserverTest do
  use ExUnit.Case

  require Logger
  alias Git, as: GitLib
  alias Baumeister.Observer.Git, as: GitObs
  alias Baumeister.Observer.Coordinate
  alias Baumeister.Test.GitRepos

  # Setup the repository and the paths to their working spaces
  setup do
    {:ok, GitRepos.make_temp_git_repo_with_some_content()}
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
    # IO.inspect(refs)
    assert Map.has_key?(refs, "refs/heads/master")
  end

  test "Create new remote refs", context do
    repo = context[:repo]
    parent_repo = context[:parent_repo]
    parent_repo_path = context[:parent_repo_path]

    {:ok, refstring} = GitLib.ls_remote(repo)
    refs = GitObs.parse_refs(refstring)

    # modify files on a brnach
    GitRepos.update_the_parent(parent_repo, parent_repo_path, "feature/branch1")

    # check what has changed.
    {:ok, refstring} = GitLib.ls_remote(repo)
    new_refs = GitObs.parse_refs(refstring)

    branch1 = "refs/heads/feature/branch1"
    assert refs != new_refs
    assert refs["refs/heads/master"] == new_refs["refs/heads/master"]
    assert Map.has_key?(new_refs, branch1)
    # assert refs["HEAD"] != new_refs["HEAD"]
    # assert new_refs["HEAD"] == new_refs[branch1]

    # and now test changed_refs
    changed_refs = GitObs.changed_refs(refs, new_refs)
    assert length(Map.keys(changed_refs)) == 1
    assert Map.has_key?(changed_refs, branch1)
    assert changed_refs[branch1] == new_refs[branch1]
  end

  test "Check the observer functions", context do
    parent_repo = context[:parent_repo]
    parent_repo_path = context[:parent_repo_path]

    {:ok, state} = GitObs.init(parent_repo.path)
    # nothin has changed
    assert {:ok, state} == GitObs.observe(state)

    # modify files on a branch
    branch =  "feature/branch1"
    GitRepos.update_the_parent(parent_repo, parent_repo_path, branch)
    {:ok, refs, _new_state} = GitObs.observe(state)
    # IO.inspect(refs)
    assert Enum.count(refs) == 1
    assert [{coord, "BaumeisterFile"}] = refs
    assert coord.url == parent_repo_path
    assert coord.observer == GitObs
    [{c, _}] = refs
    # IO.inspect c
    %Coordinate{version: v} = c
    # IO.inspect v
    assert v.name == "Branch " <> branch
  end

end
