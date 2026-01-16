defmodule BackendWeb.LeadShowLiveTest do
  use BackendWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Backend.Accounts
  alias Backend.Access.Role
  alias Backend.Leads
  alias Backend.Recordings.CallRecording
  alias Backend.Organizations.{Branch, Organization, University}
  alias Backend.Repo

  setup %{conn: conn} do
    uniq = System.unique_integer([:positive])

    organization =
      Repo.insert!(%Organization{
        name: "Org #{uniq}",
        country: "IN",
        timezone: "Asia/Kolkata"
      })

    branch = Repo.insert!(%Branch{organization_id: organization.id, name: "Branch #{uniq}"})

    role =
      Repo.insert!(%Role{
        organization_id: organization.id,
        name: "Super Admin",
        is_system: true
      })

    {:ok, admin} =
      Accounts.register_user(%{
        full_name: "Admin #{uniq}",
        email: "admin#{uniq}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        organization_id: organization.id,
        branch_id: branch.id,
        role_id: role.id
      })

    university =
      Repo.insert!(%University{organization_id: organization.id, name: "Uni #{uniq}"})

    {:ok, lead} =
      Leads.create_lead(Backend.Accounts.Scope.for_user(admin), %{
        student_name: "Lead #{uniq}",
        phone_number: "900000#{uniq}",
        university_id: university.id
      })

    recording =
      Repo.insert!(%CallRecording{
        organization_id: organization.id,
        branch_id: branch.id,
        lead_id: lead.id,
        counselor_id: admin.id,
        status: :uploaded,
        storage_key: "recordings/test/#{uniq}.m4a",
        file_url: "/uploads/recordings/test/#{uniq}.m4a",
        duration_seconds: 120,
        recorded_at: DateTime.utc_now(:second)
      })

    {:ok, conn: log_in_user(conn, admin), lead: lead, recording: recording}
  end

  test "shows recordings section", %{conn: conn, lead: lead, recording: recording} do
    {:ok, view, _html} = live(conn, ~p"/leads/#{lead.id}")

    assert has_element?(view, "#lead-recordings")
    assert has_element?(view, "#recordings-#{recording.id}")
  end
end
