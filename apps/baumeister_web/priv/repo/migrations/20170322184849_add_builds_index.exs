defmodule BaumeisterWeb.Repo.Migrations.AddBuildsIndex do
  use Ecto.Migration

  def change do
    index :builds, :project_id
    index :project, :name
  end
end
