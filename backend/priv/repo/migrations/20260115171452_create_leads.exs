defmodule Backend.Repo.Migrations.CreateLeads do
  use Ecto.Migration

  def change do
    create table(:leads) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :branch_id, references(:branches, on_delete: :delete_all), null: false
      add :university_id, references(:universities, on_delete: :nilify_all), null: false
      add :assigned_counselor_id, references(:users, on_delete: :nilify_all)
      add :created_by_user_id, references(:users, on_delete: :nilify_all)
      add :import_row_id, references(:import_rows, on_delete: :nilify_all)

      add :student_name, :string, null: false
      add :phone_number, :string, null: false
      add :normalized_phone_number, :string
      add :status, :string, null: false, default: "new"
      add :source, :string, null: false, default: "import"
      add :last_activity_at, :utc_datetime
      add :next_follow_up_at, :utc_datetime

      timestamps()
    end

    create index(:leads, [:organization_id])
    create index(:leads, [:branch_id])
    create index(:leads, [:university_id])
    create index(:leads, [:assigned_counselor_id])
    create index(:leads, [:status])
    create index(:leads, [:normalized_phone_number])
  end
end
