defmodule Backend.Repo.Migrations.CreateLeadDedupeCandidates do
  use Ecto.Migration

  def change do
    create table(:lead_dedupe_candidates) do
      add :lead_id, references(:leads, on_delete: :delete_all), null: false
      add :matched_lead_id, references(:leads, on_delete: :delete_all), null: false
      add :import_row_id, references(:import_rows, on_delete: :nilify_all)
      add :match_type, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :decision_by_user_id, references(:users, on_delete: :nilify_all)
      add :decided_at, :utc_datetime
      add :notes, :string

      timestamps()
    end

    create index(:lead_dedupe_candidates, [:lead_id])
    create index(:lead_dedupe_candidates, [:matched_lead_id])
    create index(:lead_dedupe_candidates, [:status])
    create unique_index(:lead_dedupe_candidates, [:lead_id, :matched_lead_id])
  end
end
