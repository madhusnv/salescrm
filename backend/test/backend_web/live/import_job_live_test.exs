defmodule BackendWeb.ImportJobLiveTest do
  use BackendWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Backend.Accounts
  alias Backend.Access
  alias Backend.Access.Role
  alias Backend.Imports.{ImportJob, ImportRow}
  alias Backend.Organizations.{Branch, Organization, University}
  alias Backend.Repo

  setup %{conn: conn} do
    {admin, counselor, university} = setup_users()

    job =
      Repo.insert!(%ImportJob{
        organization_id: admin.organization_id,
        branch_id: admin.branch_id,
        university_id: university.id,
        created_by_user_id: admin.id,
        status: :completed
      })

    Repo.insert!(%ImportRow{
      import_job_id: job.id,
      row_number: 1,
      student_name: "Pending Lead",
      phone_number: "9000000202",
      normalized_phone_number: "9000000202",
      normalized_student_name: "pending lead",
      status: :valid,
      dedupe_status: "none",
      assignment_status: "pending"
    })

    {:ok, conn: log_in_user(conn, admin), job: job, counselor: counselor}
  end

  test "bulk assigns from import job view", %{conn: conn, job: job, counselor: counselor} do
    {:ok, view, _html} = live(conn, ~p"/imports/leads/#{job.id}")

    assert has_element?(view, "#bulk-assign-form")

    view
    |> element("#bulk-assign-form")
    |> render_submit(%{"assignment" => %{"counselor_id" => to_string(counselor.id)}})

    row = Repo.get_by!(ImportRow, import_job_id: job.id, row_number: 1)
    assert row.assignment_status == "assigned"
    assert row.assigned_counselor_id == counselor.id
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

    Access.seed_permissions!()
    Access.assign_default_permissions!(admin_role)
    Access.assign_default_permissions!(counselor_role)

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

    {:ok, counselor} =
      Accounts.register_user(%{
        full_name: "Counselor",
        email: "counselor#{uniq}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        organization_id: organization.id,
        branch_id: branch.id,
        role_id: counselor_role.id
      })

    university =
      Repo.insert!(%University{organization_id: organization.id, name: "Uni #{uniq}"})

    {admin, counselor, university}
  end
end
