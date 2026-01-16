defmodule Backend.Repo.Migrations.AddAssignmentFieldsToImportRows do
  use Ecto.Migration

  def change do
    alter table(:import_rows) do
      add :assigned_counselor_id, references(:users, on_delete: :nilify_all)
      add :assignment_status, :string, null: false, default: "pending"
      add :assignment_error, :map
    end

    create index(:import_rows, [:assigned_counselor_id])
  end
end
