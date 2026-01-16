defmodule Backend.Repo.Migrations.AddLeadIdToImportRows do
  use Ecto.Migration

  def change do
    alter table(:import_rows) do
      add :lead_id, references(:leads, on_delete: :nilify_all)
    end

    create index(:import_rows, [:lead_id])
  end
end
