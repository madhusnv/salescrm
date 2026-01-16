defmodule Backend.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    field(:action, :string)
    field(:metadata, :map)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:user, Backend.Accounts.User)
    belongs_to(:lead, Backend.Leads.Lead)
    belongs_to(:recording, Backend.Recordings.CallRecording)

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :organization_id,
      :branch_id,
      :user_id,
      :lead_id,
      :recording_id,
      :action,
      :metadata
    ])
    |> validate_required([:organization_id, :action])
    |> validate_length(:action, max: 64)
  end
end
