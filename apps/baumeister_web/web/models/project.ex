defmodule BaumeisterWeb.Project do
  use BaumeisterWeb.Web, :model

  schema "projects" do
    field :name, :string
    field :url, :string
    field :plugins, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :url, :plugins])
    |> validate_required([:name, :url, :plugins])
  end
end
