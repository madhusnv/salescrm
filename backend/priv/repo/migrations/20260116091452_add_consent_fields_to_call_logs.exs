defmodule Backend.Repo.Migrations.AddConsentFieldsToCallLogs do
  use Ecto.Migration

  def change do
    alter table(:call_logs) do
      add(:consent_granted, :boolean, default: false, null: false)
      add(:consent_recorded_at, :utc_datetime)
      add(:consent_source, :string)
    end
  end
end
