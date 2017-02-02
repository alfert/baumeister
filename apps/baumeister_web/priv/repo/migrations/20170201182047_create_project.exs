defmodule BaumeisterWeb.Repo.Migrations.CreateProject do
  use Ecto.Migration

  def change do
    # engine is a flag for Mnesia as table type
    create table(:projects, engine: :set) do
      add :name, :string
      add :url, :string
      add :plugins, :string

      timestamps()
    end

  end
end
