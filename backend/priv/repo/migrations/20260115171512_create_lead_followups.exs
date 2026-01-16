defmodule Backend.Repo.Migrations.CreateLeadFollowups do
  use Ecto.Migration

  def change do
    create table(:lead_followups) do
      add :lead_id, references(:leads, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :status, :string, null: false, default: "pending"
      add :note, :string
      add :due_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:lead_followups, [:lead_id])
    create index(:lead_followups, [:user_id])
    create index(:lead_followups, [:status])
    create index(:lead_followups, [:due_at])
  end
end
