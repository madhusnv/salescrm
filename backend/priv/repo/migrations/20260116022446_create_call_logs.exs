defmodule Backend.Repo.Migrations.CreateCallLogs do
  use Ecto.Migration

  def change do
    create table(:call_logs) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:branch_id, references(:branches, on_delete: :nilify_all), null: false)
      add(:lead_id, references(:leads, on_delete: :nilify_all))
      add(:counselor_id, references(:users, on_delete: :delete_all), null: false)
      add(:phone_number, :string, null: false)
      add(:normalized_phone_number, :string, null: false)
      add(:call_type, :string, null: false)
      add(:device_call_id, :string, null: false)
      add(:started_at, :utc_datetime, null: false)
      add(:ended_at, :utc_datetime)
      add(:duration_seconds, :integer)
      add(:metadata, :map)

      timestamps()
    end

    create(index(:call_logs, [:organization_id]))
    create(index(:call_logs, [:branch_id]))
    create(index(:call_logs, [:lead_id]))
    create(index(:call_logs, [:counselor_id]))
    create(index(:call_logs, [:normalized_phone_number]))
    create(index(:call_logs, [:started_at]))

    create(unique_index(:call_logs, [:organization_id, :device_call_id]))
  end
end
