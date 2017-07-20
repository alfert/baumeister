defmodule BaumeisterWeb.Repo.Migrations.AddLastBuild do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :last_build_id, references(:builds) 
    end
  end
end
