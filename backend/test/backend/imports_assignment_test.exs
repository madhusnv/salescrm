defmodule Backend.ImportsAssignmentTest do
  use Backend.DataCase

  import Ecto.Query
  import Backend.AccountsFixtures

  alias Backend.Imports
  alias Backend.Imports.{ImportJob, ImportRow}
  alias Backend.Leads.Lead
  alias Backend.Organizations.University
  alias Backend.Repo

  test "assign_rows_to_counselor/2 assigns unassigned rows and creates leads" do
    user = user_fixture()

    university =
      Repo.insert!(%University{organization_id: user.organization_id, name: "Bulk University"})

    job =
      Repo.insert!(%ImportJob{
        organization_id: user.organization_id,
        branch_id: user.branch_id,
        university_id: university.id,
        created_by_user_id: user.id,
        status: :completed
      })

    for row_number <- 1..2 do
      Repo.insert!(%ImportRow{
        import_job_id: job.id,
        row_number: row_number,
        student_name: "Student #{row_number}",
        phone_number: "99999999#{row_number}0",
        normalized_phone_number: "99999999#{row_number}0",
        normalized_student_name: "student #{row_number}",
        status: :valid,
        dedupe_status: "none",
        assignment_status: "pending"
      })
    end

    assert {:ok, 2} = Imports.assign_rows_to_counselor(job, user.id)

    assigned_rows =
      ImportRow
      |> where([r], r.import_job_id == ^job.id)
      |> Repo.all()

    assert Enum.all?(assigned_rows, &(&1.assignment_status == "assigned"))
    assert Enum.all?(assigned_rows, &(&1.assigned_counselor_id == user.id))
    assert Repo.aggregate(Lead, :count, :id) == 2
  end
end
