defmodule Baumeister.Test.GitRepos do
  @moduledoc """
  Some convenience functions for setting up test Git repositories.
  """

  alias Git, as: GitLib
  alias Baumeister.Observer.Git, as: GitObs
  import ExUnit.Assertions

  @doc """
  Update the README.md on the parent, but on a branch
  """
  def update_the_parent(parent_repo, parent_repo_path, branch_name) do
    {:ok, _} = GitLib.checkout(parent_repo, ["-b", branch_name])
    ~w(README.md BaumeisterFile)
    |> Enum.each(fn filename ->
      file = Path.join(parent_repo_path, filename)
      :ok = File.write(file, filename)
      {:ok, _} = GitLib.add(parent_repo, file)
    end)
    {:ok, _}  = GitLib.commit(parent_repo, ["-m", "with content", "--allow-empty"])
  end

  @doc """
  Creates a repository and its local clone. Returns
  URLs and `Git` repos as `t:Keyword.t/0` to be used in
  the ExUnit `setup` function.
  """
  @spec make_temp_git_repo_with_some_content() :: Keyword.t
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
    GitObs.set_user_config(parent_repo)

    readme = Path.join(parent_path, "README.md")
    assert is_binary(readme)
    :ok = File.touch(readme)
    {:ok, _} = GitLib.add(parent_repo, readme)
    {:ok, _} = GitLib.commit(parent_repo, ~w(-a -m initial-commit))

    path = dirs |> Enum.at(1)
    {:ok, repo} = GitLib.clone([parent_path, path])
    GitObs.set_user_config(repo)
    [repo: repo, parent_repo: parent_repo, repo_path: path, parent_repo_path: parent_path]
  end


end
