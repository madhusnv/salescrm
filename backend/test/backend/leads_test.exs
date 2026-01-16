defmodule Backend.LeadsTest do
  use Backend.DataCase

  import Backend.AccountsFixtures

  alias Backend.Leads
  alias Backend.Organizations.University
  alias Backend.Repo

  test "update_lead_status/3 logs activity and updates lead" do
    user = user_fixture()
    scope = user_scope_fixture(user)

    university =
      Repo.insert!(%University{organization_id: user.organization_id, name: "Test University"})

    {:ok, lead} =
      Leads.create_lead(scope, %{
        student_name: "Sam Student",
        phone_number: "9876543210",
        university_id: university.id,
        assigned_counselor_id: user.id,
        source: "manual"
      })

    {:ok, {lead, activity}} = Leads.update_lead_status(scope, lead, :follow_up)

    assert lead.status == :follow_up
    assert activity.activity_type == :status_change
  end

  test "add_note/3 creates activity and refreshes last_activity_at" do
    user = user_fixture()
    scope = user_scope_fixture(user)

    university =
      Repo.insert!(%University{organization_id: user.organization_id, name: "Notes University"})

    {:ok, lead} =
      Leads.create_lead(scope, %{
        student_name: "Note Student",
        phone_number: "9999999999",
        university_id: university.id,
        assigned_counselor_id: user.id,
        source: "manual"
      })

    {:ok, {lead, activity}} = Leads.add_note(scope, lead, "Reached out via call.")

    assert activity.activity_type == :note
    assert lead.last_activity_at != nil
  end

  test "schedule_followup/3 and complete_followup/2 update followup status" do
    user = user_fixture()
    scope = user_scope_fixture(user)

    university =
      Repo.insert!(%University{organization_id: user.organization_id, name: "Followup University"})

    {:ok, lead} =
      Leads.create_lead(scope, %{
        student_name: "Follow Up Student",
        phone_number: "8888888888",
        university_id: university.id,
        assigned_counselor_id: user.id,
        source: "manual"
      })

    due_at = DateTime.add(DateTime.utc_now(:second), 3600, :second)

    {:ok, {_lead, followup, _activity}} =
      Leads.schedule_followup(scope, lead, %{due_at: due_at, note: "Call tomorrow."})

    assert followup.status == :pending

    {:ok, {_lead, followup, _activity}} = Leads.complete_followup(scope, followup)

    assert followup.status == :completed
  end
end
