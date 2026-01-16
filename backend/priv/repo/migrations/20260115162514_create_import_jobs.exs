defmodule Backend.Repo.Migrations.CreateImportJobs do
  use Ecto.Migration

  def change do
    create table(:import_jobs) do
      add(:organization_id, references(:organizations, on_delete: :delete_all), null: false)
      add(:branch_id, references(:branches, on_delete: :nilify_all))
      add(:university_id, references(:universities, on_delete: :nilify_all), null: false)
      add(:created_by_user_id, references(:users, on_delete: :nilify_all))
      add(:import_type, :string, null: false, default: "leads")
      add(:status, :string, null: false, default: "pending")
      add(:original_filename, :string)
      add(:total_rows, :integer, null: false, default: 0)
      add(:valid_rows, :integer, null: false, default: 0)
      add(:invalid_rows, :integer, null: false, default: 0)
      add(:inserted_rows, :integer, null: false, default: 0)
      add(:error_summary, :map)
      add(:started_at, :utc_datetime)
      add(:completed_at, :utc_datetime)

      timestamps()
    end

    create table(:import_rows) do
      add(:import_job_id, references(:import_jobs, on_delete: :delete_all), null: false)
      add(:row_number, :integer, null: false)
      add(:student_name, :string)
      add(:phone_number, :string)
      add(:normalized_phone_number, :string)
      add(:status, :string, null: false, default: "valid")
      add(:errors, :map)
      add(:raw_data, :map)

      timestamps()
    end

    create(index(:import_rows, [:import_job_id]))
    create(index(:import_rows, [:normalized_phone_number]))
    create(unique_index(:import_rows, [:import_job_id, :row_number]))
  end
end
