defmodule BackendWeb.AssignmentRulesLiveTest do
  use BackendWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Backend.Accounts
  alias Backend.Access
  alias Backend.Access.Role
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

    Access.seed_permissions!()
    Access.assign_default_permissions!(role)

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

    _university =
      Repo.insert!(%University{organization_id: organization.id, name: "Uni #{uniq}"})

    {:ok, conn: log_in_user(conn, admin)}
  end

  test "renders assignment rules page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assignments/rules")
    assert has_element?(view, "#assignment-rule-form")
  end
end
