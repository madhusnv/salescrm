defmodule Backend.Repo.Migrations.AddDedupeFieldsToLeads do
  use Ecto.Migration

  def change do
    alter table(:leads) do
      add :normalized_student_name, :string
      add :merged_into_lead_id, references(:leads, on_delete: :nilify_all)
      add :merged_at, :utc_datetime
    end

    create index(:leads, [:normalized_student_name])
    create index(:leads, [:merged_into_lead_id])
  end
end
