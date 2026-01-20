defmodule Backend.Repo.Migrations.ScopeCallLogsDeviceIdUniqueness do
  use Ecto.Migration

  def change do
    drop_if_exists(unique_index(:call_logs, [:organization_id, :device_call_id]))
    create(unique_index(:call_logs, [:organization_id, :counselor_id, :device_call_id]))
  end
end
