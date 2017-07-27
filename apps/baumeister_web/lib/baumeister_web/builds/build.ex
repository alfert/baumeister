defmodule BaumeisterWeb.Builds.Build do
  @moduledoc """
  The (embedded) schema for Builds.
  """
  use BaumeisterWeb.Web, :model

  alias BaumeisterWeb.Builds.Project

  schema "builds" do
    # field :project_id, :integer
    # belongs_to introduces project_id and allows to preload to
    # the project - which is not supported by MnesiaEcto
    belongs_to :project, Project
    field :number, :integer
    field :log, :string
    field :coordinate, :string
    field :config, :string
    # 0: unknown state
    # 1: build is running
    # 2: build completed, ok
    # 3: build completed with failures
    field :status, :integer
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:project_id, :number, :log, :coordinate, :config, :status])
    |> validate_required([:project_id, :number, :coordinate])
  end

end
