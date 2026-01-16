defmodule Backend.Repo.Migrations.CreateCallRecordings do
  use Ecto.Migration

  def change do
    create table(:call_recordings) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:branch_id, references(:branches, on_delete: :nilify_all), null: false)
      add(:lead_id, references(:leads, on_delete: :nilify_all))
      add(:call_log_id, references(:call_logs, on_delete: :nilify_all))
      add(:counselor_id, references(:users, on_delete: :delete_all), null: false)

      add(:status, :string, null: false)
      add(:storage_key, :string)
      add(:file_url, :string)
      add(:content_type, :string)
      add(:file_size_bytes, :bigint)
      add(:duration_seconds, :integer)
      add(:consent_granted, :boolean, default: false, null: false)
      add(:recorded_at, :utc_datetime)
      add(:metadata, :map)

      timestamps()
    end

    create(index(:call_recordings, [:organization_id]))
    create(index(:call_recordings, [:branch_id]))
    create(index(:call_recordings, [:lead_id]))
    create(index(:call_recordings, [:call_log_id]))
    create(index(:call_recordings, [:counselor_id]))
    create(index(:call_recordings, [:status]))
  end
end
