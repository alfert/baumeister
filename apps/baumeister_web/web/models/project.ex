defmodule BaumeisterWeb.Project do
  use BaumeisterWeb.Web, :model

  @moduledoc """
  The ecto-based model for a project.
  """

  schema "projects" do
    field :name, :string
    field :url, :string
    field :plugins, :string
    field :enabled, :boolean, default: false
    field :delay, :integer, default: 0

    has_many :builds, BaumeisterWeb.Build, [defaults: []]
    # has_one :last_build, BaumeisterWeb.Build, [defaults: nil]
    # has_one would introduce last_build_id, but requires preloading
    # which is not supported by MnesiaEcto.
    field :last_build_id, :integer, default: nil

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :plugins, :enabled, :delay, :last_build_id])
    # |> cast_assoc(:last_build)
    |> cast_assoc(:builds)
    |> validate_required([:name, :url, :plugins, :enabled, :delay])
    |> unique_constraint(:name)
  end
end
