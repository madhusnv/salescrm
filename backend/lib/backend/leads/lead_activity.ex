defmodule Backend.Leads.LeadActivity do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(note status_change assignment_change followup_scheduled followup_completed followup_canceled)a

  schema "lead_activities" do
    field :activity_type, Ecto.Enum, values: @types
    field :body, :string
    field :metadata, :map
    field :occurred_at, :utc_datetime

    belongs_to :lead, Backend.Leads.Lead
    belongs_to :user, Backend.Accounts.User

    timestamps()
  end

  def types, do: @types

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:activity_type, :body, :metadata, :occurred_at])
    |> validate_required([:activity_type, :occurred_at])
    |> validate_length(:body, max: 1000)
  end
end
