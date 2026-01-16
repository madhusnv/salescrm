defmodule Backend.Repo.Migrations.CreateLeadActivities do
  use Ecto.Migration

  def change do
    create table(:lead_activities) do
      add :lead_id, references(:leads, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :activity_type, :string, null: false
      add :body, :string
      add :metadata, :map
      add :occurred_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:lead_activities, [:lead_id])
    create index(:lead_activities, [:user_id])
    create index(:lead_activities, [:activity_type])
  end
end
