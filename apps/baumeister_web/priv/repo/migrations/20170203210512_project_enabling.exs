defmodule BaumeisterWeb.Repo.Migrations.ProjectEnabling do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :enabled, :boolean, default: false
      add :delay, :integer, default: 0
    end

    constraint(:projects, :delay_must_be_positive, check: "delay >= 0")
  end
end
