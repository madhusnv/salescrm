defmodule Backend.Imports.ImportJob do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending processing completed failed)a

  schema "import_jobs" do
    field(:import_type, :string, default: "leads")
    field(:status, Ecto.Enum, values: @statuses, default: :pending)
    field(:original_filename, :string)
    field(:total_rows, :integer, default: 0)
    field(:valid_rows, :integer, default: 0)
    field(:invalid_rows, :integer, default: 0)
    field(:inserted_rows, :integer, default: 0)
    field(:error_summary, :map)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:university, Backend.Organizations.University)
    belongs_to(:created_by_user, Backend.Accounts.User)

    has_many(:rows, Backend.Imports.ImportRow)

    timestamps()
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :organization_id,
      :branch_id,
      :university_id,
      :created_by_user_id,
      :import_type,
      :status,
      :original_filename,
      :total_rows,
      :valid_rows,
      :invalid_rows,
      :inserted_rows,
      :error_summary,
      :started_at,
      :completed_at
    ])
    |> validate_required([:organization_id, :created_by_user_id, :university_id])
    |> validate_length(:import_type, max: 40)
  end
end
