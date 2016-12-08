defmodule Baumeister.GitObserverTest do
  use ExUnit.Case

  require Logger
  alias Git, as: GitLib
  alias Baumeister.Observer.Git, as: GitObs



  test "some git features" do
    # our own current directory, we are in ./apps/baumeister
    invalid_repo = GitLib.new("../..")
    # {:error, _} = GitLib.ls_remote(invalid_repo)

    repos = make_temp_git_repo_with_some_content()
    %{repo: repo, parent_repo: parent} = repos
    # IO.inspect(repos)

    {:ok, refstring} = GitLib.ls_remote(repo)
    refs = GitObs.parse_refs(refstring)

    assert %{} = refs
    IO.inspect(refs)
    assert Map.has_key?(refs, "HEAD")
    assert Map.has_key?(refs, "refs/heads/master")
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
    %{repo: repo, parent_repo: parent_repo}
  end

end
