defmodule Backend.Leads.Lead do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(new follow_up applied not_interested)a

  schema "leads" do
    field(:student_name, :string)
    field(:phone_number, :string)
    field(:normalized_phone_number, :string)
    field(:normalized_student_name, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :new)
    field(:source, :string)
    field(:last_activity_at, :utc_datetime)
    field(:next_follow_up_at, :utc_datetime)
    field(:merged_at, :utc_datetime)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:university, Backend.Organizations.University)
    belongs_to(:assigned_counselor, Backend.Accounts.User)
    belongs_to(:created_by_user, Backend.Accounts.User)
    belongs_to(:import_row, Backend.Imports.ImportRow)
    belongs_to(:merged_into_lead, __MODULE__)

    has_many(:activities, Backend.Leads.LeadActivity)
    has_many(:followups, Backend.Leads.LeadFollowup)
    has_many(:call_logs, Backend.Calls.CallLog)

    timestamps()
  end

  def statuses, do: @statuses

  def changeset(lead, attrs) do
    lead
    |> cast(attrs, [
      :student_name,
      :phone_number,
      :normalized_phone_number,
      :normalized_student_name,
      :status,
      :source,
      :last_activity_at,
      :next_follow_up_at,
      :assigned_counselor_id,
      :university_id,
      :merged_into_lead_id,
      :merged_at
    ])
    |> validate_required([:student_name, :phone_number, :status, :university_id])
    |> validate_length(:student_name, min: 2, max: 120)
    |> validate_length(:phone_number, min: 6, max: 20)
  end
end
