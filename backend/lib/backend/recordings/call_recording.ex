defmodule Backend.Recordings.CallRecording do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending uploaded failed expired)a

  schema "call_recordings" do
    field(:status, Ecto.Enum, values: @statuses, default: :pending)
    field(:storage_key, :string)
    field(:file_url, :string)
    field(:content_type, :string)
    field(:file_size_bytes, :integer)
    field(:duration_seconds, :integer)
    field(:consent_granted, :boolean, default: false)
    field(:recorded_at, :utc_datetime)
    field(:metadata, :map)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:lead, Backend.Leads.Lead)
    belongs_to(:call_log, Backend.Calls.CallLog)
    belongs_to(:counselor, Backend.Accounts.User)

    timestamps()
  end

  def statuses, do: @statuses

  def init_changeset(recording, attrs) do
    recording
    |> cast(attrs, [
      :organization_id,
      :branch_id,
      :lead_id,
      :call_log_id,
      :counselor_id,
      :status,
      :storage_key,
      :content_type,
      :consent_granted,
      :recorded_at,
      :metadata
    ])
    |> validate_required([
      :organization_id,
      :branch_id,
      :counselor_id,
      :status
    ])
    |> validate_length(:storage_key, max: 255)
  end

  def complete_changeset(recording, attrs) do
    recording
    |> cast(attrs, [
      :status,
      :file_url,
      :file_size_bytes,
      :duration_seconds,
      :metadata
    ])
    |> validate_required([:status])
    |> validate_number(:file_size_bytes, greater_than_or_equal_to: 0)
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
  end
end
