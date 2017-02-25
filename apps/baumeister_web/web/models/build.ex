defmodule BaumeisterWeb.Build do
  use BaumeisterWeb.Web, :model

  @moduledoc """
  The model and schema definition for the Build representation.
  """

  schema "builds" do
    field :project_id, :integer
    field :number, :integer
    field :log, :string
    field :coordinate, :string
    field :config, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:project_id, :number, :log, :coordinate, :config])
    |> validate_required([:project_id, :number, :log, :coordinate, :config])
  end
end
