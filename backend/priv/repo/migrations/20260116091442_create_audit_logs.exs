defmodule Backend.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:branch_id, references(:branches, on_delete: :nilify_all))
      add(:user_id, references(:users, on_delete: :nilify_all))
      add(:lead_id, references(:leads, on_delete: :nilify_all))
      add(:recording_id, references(:call_recordings, on_delete: :nilify_all))
      add(:action, :string, null: false)
      add(:metadata, :map)

      timestamps()
    end

    create(index(:audit_logs, [:organization_id, :inserted_at]))
    create(index(:audit_logs, [:recording_id]))
  end
end
