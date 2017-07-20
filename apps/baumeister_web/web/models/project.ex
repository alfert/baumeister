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

    has_many :builds, BaumeisterWeb.Build
    has_one :last_build_id, BaumeisterWeb.Build, [defaults: -1]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :plugins, :enabled, :delay])
    |> cast_assoc(:last_build_id)
    |> validate_required([:name, :url, :plugins, :enabled, :delay])
    |> unique_constraint(:name)
  end
end
