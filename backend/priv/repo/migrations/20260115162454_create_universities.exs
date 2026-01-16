defmodule Backend.Repo.Migrations.CreateUniversities do
  use Ecto.Migration

  def change do
    create table(:universities) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create index(:universities, [:organization_id])
    create unique_index(:universities, [:organization_id, :name])
  end
end
