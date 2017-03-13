defmodule BaumeisterWeb.Repo.Migrations.CreateBuild do
  use Ecto.Migration

  def change do
    create table(:builds) do
      add :project_id, :integer
      add :number, :integer
      add :log, :text
      add :coordinate, :string
      add :config, :string

      timestamps()
    end

  end
end
