defmodule Backend.AssignmentsTest do
  use Backend.DataCase

  alias Backend.Assignments
  alias Backend.Assignments.AssignmentRule
  alias Backend.Organizations.{Branch, Organization, University}
  alias Backend.Access.Role
  alias Backend.Accounts
  alias Backend.Repo

  defp create_scope do
    organization =
      Repo.insert!(%Organization{name: "Scope Org", country: "IN", timezone: "Asia/Kolkata"})

    branch = Repo.insert!(%Branch{organization_id: organization.id, name: "Scope Branch"})
    role = Repo.insert!(%Role{organization_id: organization.id, name: "Counselor"})

    %{
      organization: organization,
      branch: branch,
      role: role
    }
  end

  defp create_user(scope, attrs \\ %{}) do
    Accounts.register_user(%{
      full_name: Map.get(attrs, :full_name, "Counselor"),
      email: Map.get(attrs, :email, "user#{System.unique_integer()}@example.com"),
      password: "password123",
      organization_id: scope.organization.id,
      branch_id: scope.branch.id,
      role_id: scope.role.id
    })
  end

  describe "pick_counselor/3" do
    test "picks highest priority rule and updates counters" do
      scope = create_scope()
      university = Repo.insert!(%University{organization_id: scope.organization.id, name: "Uni"})

      {:ok, counselor_a} = create_user(scope, %{full_name: "Alex"})
      {:ok, counselor_b} = create_user(scope, %{full_name: "Bela"})

      Repo.insert!(%AssignmentRule{
        organization_id: scope.organization.id,
        branch_id: scope.branch.id,
        university_id: university.id,
        counselor_id: counselor_a.id,
        priority: 0
      })

      high_rule =
        Repo.insert!(%AssignmentRule{
          organization_id: scope.organization.id,
          branch_id: scope.branch.id,
          university_id: university.id,
          counselor_id: counselor_b.id,
          priority: 10
        })

      assert {:ok, counselor_id} =
               Assignments.pick_counselor(scope.organization.id, scope.branch.id, university.id)

      assert counselor_id == counselor_b.id

      refreshed = Repo.get!(AssignmentRule, high_rule.id)
      assert refreshed.assigned_count == 1
      assert refreshed.last_assigned_at
    end

    test "skips counselors over daily cap for today" do
      scope = create_scope()
      university = Repo.insert!(%University{organization_id: scope.organization.id, name: "Uni"})

      {:ok, counselor_a} = create_user(scope, %{full_name: "Alex"})
      {:ok, counselor_b} = create_user(scope, %{full_name: "Bela"})

      today = DateTime.utc_now(:second)

      Repo.insert!(%AssignmentRule{
        organization_id: scope.organization.id,
        branch_id: scope.branch.id,
        university_id: university.id,
        counselor_id: counselor_a.id,
        priority: 10,
        daily_cap: 1,
        assigned_count: 1,
        last_assigned_at: today
      })

      Repo.insert!(%AssignmentRule{
        organization_id: scope.organization.id,
        branch_id: scope.branch.id,
        university_id: university.id,
        counselor_id: counselor_b.id,
        priority: 5
      })

      assert {:ok, counselor_id} =
               Assignments.pick_counselor(scope.organization.id, scope.branch.id, university.id)

      assert counselor_id == counselor_b.id
    end

    test "returns error when no rules exist" do
      scope = create_scope()
      university = Repo.insert!(%University{organization_id: scope.organization.id, name: "Uni"})

      assert {:error, :no_assignment_rules} =
               Assignments.pick_counselor(scope.organization.id, scope.branch.id, university.id)
    end
  end
end
