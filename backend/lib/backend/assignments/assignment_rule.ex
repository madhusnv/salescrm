defmodule Backend.Assignments.AssignmentRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "assignment_rules" do
    field(:is_active, :boolean, default: true)
    field(:priority, :integer, default: 0)
    field(:daily_cap, :integer)
    field(:assigned_count, :integer, default: 0)
    field(:last_assigned_at, :utc_datetime)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:university, Backend.Organizations.University)
    belongs_to(:counselor, Backend.Accounts.User)

    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :organization_id,
      :branch_id,
      :university_id,
      :counselor_id,
      :is_active,
      :priority,
      :daily_cap
    ])
    |> validate_required([:organization_id, :university_id, :counselor_id])
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_number(:daily_cap, greater_than_or_equal_to: 1)
  end

  def system_changeset(rule, attrs) do
    rule
    |> cast(attrs, [:assigned_count, :last_assigned_at])
    |> validate_number(:assigned_count, greater_than_or_equal_to: 0)
  end
end
