defmodule BaumeisterWeb.Project do
  use BaumeisterWeb.Web, :model

  schema "projects" do
    field :name, :string
    field :url, :string
    field :plugins, :string
    field :enabled, :boolean, default: false
    field :delay, :integer, default: 0

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :plugins, :enabled, :delay])
    |> validate_required([:name, :url, :plugins, :enabled, :delay])
    |> unique_constraint(:name)
  end
end
