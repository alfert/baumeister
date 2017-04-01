defmodule BaumeisterWeb.Repo.Migrations.AddStatus do
  use Ecto.Migration

  def change do
    alter table(:builds) do
      # 0: unknown state
      # 1: build is running
      # 2: build completed, ok
      # 3: build completed with failures
      add :status, :integer, default: 0
    end
  end
end
