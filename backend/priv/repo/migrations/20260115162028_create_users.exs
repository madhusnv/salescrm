defmodule Backend.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :branch_id, references(:branches, on_delete: :nilify_all)
      add :role_id, references(:roles, on_delete: :restrict), null: false
      add :full_name, :string, null: false
      add :email, :string, null: false
      add :phone_number, :string
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
      add :last_login_at, :utc_datetime
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:users, [:email])
    create index(:users, [:organization_id])
    create index(:users, [:branch_id])
    create index(:users, [:role_id])
  end
end
