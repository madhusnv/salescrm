defmodule Backend.AssignmentRulePropertyTest do
  use Backend.DataCase, async: false
  use ExUnitProperties

  alias Backend.Accounts
  alias Backend.Assignments
  alias Backend.Assignments.AssignmentRule
  alias Backend.Organizations.{Branch, Organization, University}
  alias Backend.Access.Role
  alias Backend.Repo

  property "picks counselor when rule is active and last assigned was before today" do
    check all(
            assigned_count <- integer(0..20),
            daily_cap <- integer(1..20)
          ) do
      uniq = System.unique_integer([:positive])

      organization =
        Repo.insert!(%Organization{
          name: "Org #{uniq}",
          country: "IN",
          timezone: "Asia/Kolkata"
        })

      branch = Repo.insert!(%Branch{organization_id: organization.id, name: "Branch #{uniq}"})
      role = Repo.insert!(%Role{organization_id: organization.id, name: "Counselor #{uniq}"})

      university =
        Repo.insert!(%University{organization_id: organization.id, name: "Uni #{uniq}"})

      {:ok, counselor} =
        Accounts.register_user(%{
          full_name: "Counselor #{uniq}",
          email: "counselor#{uniq}@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          organization_id: organization.id,
          branch_id: branch.id,
          role_id: role.id
        })

      yesterday = DateTime.utc_now(:second) |> DateTime.add(-86_400, :second)

      Repo.insert!(%AssignmentRule{
        organization_id: organization.id,
        branch_id: branch.id,
        university_id: university.id,
        counselor_id: counselor.id,
        is_active: true,
        priority: 1,
        daily_cap: daily_cap,
        assigned_count: assigned_count,
        last_assigned_at: yesterday
      })

      assert {:ok, counselor_id} =
               Assignments.pick_counselor(organization.id, branch.id, university.id)

      assert counselor_id == counselor.id
    end
  end
end
