defmodule Backend.Analytics.AnalyticsEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analytics_events" do
    field(:event_type, :string)
    field(:occurred_at, :utc_datetime)
    field(:metadata, :map)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:user, Backend.Accounts.User)
    belongs_to(:lead, Backend.Leads.Lead)

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :branch_id,
      :user_id,
      :lead_id,
      :event_type,
      :occurred_at,
      :metadata
    ])
    |> validate_required([:organization_id, :event_type, :occurred_at])
    |> validate_length(:event_type, max: 64)
  end
end
