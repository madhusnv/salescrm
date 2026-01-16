defmodule Backend.Leads.LeadFollowup do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending completed canceled)a

  schema "lead_followups" do
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :note, :string
    field :due_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :lead, Backend.Leads.Lead
    belongs_to :user, Backend.Accounts.User

    timestamps()
  end

  def statuses, do: @statuses

  def changeset(followup, attrs) do
    followup
    |> cast(attrs, [:status, :note, :due_at, :completed_at])
    |> validate_required([:status, :due_at])
    |> validate_length(:note, max: 400)
  end
end
