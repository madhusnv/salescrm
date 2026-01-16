defmodule Backend.Repo.Migrations.CreateOrganizationsAndBranches do
  use Ecto.Migration

  def change do
    create table(:organizations) do
      add :name, :string, null: false
      add :country, :string, null: false, default: "IN"
      add :timezone, :string, null: false, default: "Asia/Kolkata"
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create table(:branches) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :city, :string
      add :state, :string
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create index(:branches, [:organization_id])
    create unique_index(:branches, [:organization_id, :name])
  end
end
