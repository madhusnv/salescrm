defmodule Backend.Repo.Migrations.CreateRolesAndPermissions do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :is_system, :boolean, null: false, default: false

      timestamps()
    end

    create unique_index(:roles, [:organization_id, :name])
    create index(:roles, [:organization_id])

    create table(:permissions) do
      add :key, :string, null: false
      add :description, :text
      add :category, :string

      timestamps()
    end

    create unique_index(:permissions, [:key])

    create table(:role_permissions) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:role_permissions, [:role_id, :permission_id])
  end
end
