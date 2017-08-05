defmodule BaumeisterWeb.Builds.Project do
  @moduledoc """
  A Baumeister Project within the Context of Builds. In particular,
  it contains information about the last builds.
  """
  use BaumeisterWeb.Web, :model

  alias BaumeisterWeb.Builds.Build

  schema "projects" do
    field :name, :string
    field :url, :string
    field :plugins, :string
    field :enabled, :boolean, default: false
    field :delay, :integer, default: 0

    # these fields describe the last build results
    embeds_one :last_build, Build

    # this is the list of the builds. It must be loaded explicetely
    embeds_many :builds, Build
    timestamps()
  end

  @type t :: %__MODULE__{}
  
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
