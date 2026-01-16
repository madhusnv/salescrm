defmodule Backend.Calls.CallLog do
  use Ecto.Schema
  import Ecto.Changeset

  @call_types ~w(incoming outgoing missed rejected blocked unknown)a

  schema "call_logs" do
    field(:phone_number, :string)
    field(:normalized_phone_number, :string)
    field(:call_type, Ecto.Enum, values: @call_types)
    field(:device_call_id, :string)
    field(:started_at, :utc_datetime)
    field(:ended_at, :utc_datetime)
    field(:duration_seconds, :integer)
    field(:consent_granted, :boolean, default: false)
    field(:consent_recorded_at, :utc_datetime)
    field(:consent_source, :string)
    field(:metadata, :map)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:lead, Backend.Leads.Lead)
    belongs_to(:counselor, Backend.Accounts.User)

    timestamps()
  end

  def call_types, do: @call_types

  def changeset(call_log, attrs) do
    call_log
    |> cast(attrs, [
      :organization_id,
      :branch_id,
      :lead_id,
      :counselor_id,
      :phone_number,
      :normalized_phone_number,
      :call_type,
      :device_call_id,
      :started_at,
      :ended_at,
      :duration_seconds,
      :consent_granted,
      :consent_recorded_at,
      :consent_source,
      :metadata
    ])
    |> validate_required([
      :organization_id,
      :branch_id,
      :counselor_id,
      :phone_number,
      :normalized_phone_number,
      :call_type,
      :device_call_id,
      :started_at
    ])
    |> validate_length(:phone_number, min: 6, max: 20)
    |> validate_length(:device_call_id, min: 3, max: 120)
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
  end
end
