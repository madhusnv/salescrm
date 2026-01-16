defmodule Backend.Repo.Migrations.CreateAnalyticsEvents do
  use Ecto.Migration

  def change do
    create table(:analytics_events) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:branch_id, references(:branches, on_delete: :nilify_all))
      add(:user_id, references(:users, on_delete: :nilify_all))
      add(:lead_id, references(:leads, on_delete: :nilify_all))
      add(:event_type, :string, null: false)
      add(:occurred_at, :utc_datetime, null: false)
      add(:metadata, :map)

      timestamps()
    end

    create(index(:analytics_events, [:organization_id, :occurred_at]))
    create(index(:analytics_events, [:branch_id, :occurred_at]))
    create(index(:analytics_events, [:event_type, :occurred_at]))
    create(index(:analytics_events, [:lead_id]))
  end
end
