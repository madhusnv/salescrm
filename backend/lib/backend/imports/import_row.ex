defmodule Backend.Imports.ImportRow do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(valid invalid)a

  schema "import_rows" do
    field :row_number, :integer
    field :student_name, :string
    field :phone_number, :string
    field :normalized_phone_number, :string
    field :normalized_student_name, :string
    field :status, Ecto.Enum, values: @statuses, default: :valid
    field :errors, :map
    field :raw_data, :map
    field :assignment_status, :string, default: "pending"
    field :assignment_error, :map
    field :dedupe_status, :string, default: "none"
    field :dedupe_reason, :string

    belongs_to :import_job, Backend.Imports.ImportJob
    belongs_to :assigned_counselor, Backend.Accounts.User
    belongs_to :lead, Backend.Leads.Lead
    belongs_to :dedupe_matched_lead, Backend.Leads.Lead, foreign_key: :dedupe_matched_lead_id

    timestamps()
  end

  def changeset(row, attrs) do
    row
    |> cast(attrs, [
      :import_job_id,
      :row_number,
      :student_name,
      :phone_number,
      :normalized_phone_number,
      :normalized_student_name,
      :status,
      :errors,
      :raw_data,
      :assignment_status,
      :assignment_error,
      :assigned_counselor_id,
      :lead_id,
      :dedupe_status,
      :dedupe_reason,
      :dedupe_matched_lead_id
    ])
    |> validate_required([:import_job_id, :row_number])
  end
end
