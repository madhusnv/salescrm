defmodule BackendWeb.LeadIndexLiveTest do
  use BackendWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Backend.Accounts
  alias Backend.Accounts.Scope
  alias Backend.Access.Role
  alias Backend.Leads
  alias Backend.Organizations.{Branch, Organization, University}
  alias Backend.Repo

  setup %{conn: conn} do
    {admin, counselor_a, counselor_b, university} = setup_users()
    scope = Scope.for_user(admin)

    {:ok,
     conn: log_in_user(conn, admin),
     scope: scope,
     counselor_a: counselor_a,
     counselor_b: counselor_b,
     university: university}
  end

  test "assigns a lead from the list", %{
    conn: conn,
    scope: scope,
    counselor_a: counselor_a,
    counselor_b: counselor_b,
    university: university
  } do
    {:ok, lead} =
      Leads.create_lead(scope, %{
        student_name: "Lead Student",
        phone_number: "9000000101",
        university_id: university.id,
        assigned_counselor_id: counselor_a.id
      })

    {:ok, view, _html} = live(conn, ~p"/leads")

    assert has_element?(view, "#assign-form-#{lead.id}")

    view
    |> element("#assign-form-#{lead.id}")
    |> render_submit(%{
      "assignment" => %{
        "lead_id" => to_string(lead.id),
        "counselor_id" => to_string(counselor_b.id)
      }
    })

    updated = Leads.get_lead!(scope, lead.id)
    assert updated.assigned_counselor_id == counselor_b.id
  end

  defp setup_users do
    uniq = System.unique_integer([:positive])

    organization =
      Repo.insert!(%Organization{
        name: "Org #{uniq}",
        country: "IN",
        timezone: "Asia/Kolkata"
      })

    branch = Repo.insert!(%Branch{organization_id: organization.id, name: "Branch #{uniq}"})

    admin_role =
      Repo.insert!(%Role{organization_id: organization.id, name: "Super Admin", is_system: true})

    counselor_role =
      Repo.insert!(%Role{organization_id: organization.id, name: "Counselor", is_system: true})

    {:ok, admin} =
      Accounts.register_user(%{
        full_name: "Admin User",
        email: "admin#{uniq}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        organization_id: organization.id,
        branch_id: branch.id,
        role_id: admin_role.id
      })

    {:ok, counselor_a} =
      Accounts.register_user(%{
        full_name: "Counselor A",
        email: "counselor.a#{uniq}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        organization_id: organization.id,
        branch_id: branch.id,
        role_id: counselor_role.id
      })

    {:ok, counselor_b} =
      Accounts.register_user(%{
        full_name: "Counselor B",
        email: "counselor.b#{uniq}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        organization_id: organization.id,
        branch_id: branch.id,
        role_id: counselor_role.id
      })

    university =
      Repo.insert!(%University{organization_id: organization.id, name: "Uni #{uniq}"})

    {admin, counselor_a, counselor_b, university}
  end
end
