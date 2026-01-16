defmodule Backend.Repo.Migrations.AddDedupeFieldsToImportRows do
  use Ecto.Migration

  def change do
    alter table(:import_rows) do
      add :normalized_student_name, :string
      add :dedupe_status, :string, null: false, default: "none"
      add :dedupe_reason, :string
      add :dedupe_matched_lead_id, references(:leads, on_delete: :nilify_all)
    end

    create index(:import_rows, [:dedupe_status])
    create index(:import_rows, [:dedupe_matched_lead_id])
  end
end
