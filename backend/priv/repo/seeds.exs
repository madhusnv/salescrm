# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Backend.Repo.insert!(%Backend.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Backend.Repo
alias Backend.Access
alias Backend.Accounts
alias Backend.Access.Role
alias Backend.Organizations.{Branch, Organization, University}

organization =
  Repo.get_by(Organization, name: "KonCRM") ||
    Repo.insert!(%Organization{name: "KonCRM", country: "IN", timezone: "Asia/Kolkata"})

hq_branch =
  Repo.get_by(Branch, organization_id: organization.id, name: "HQ") ||
    Repo.insert!(%Branch{organization_id: organization.id, name: "HQ", city: "Hyderabad"})

roles = ["Super Admin", "Branch Manager", "Counselor"]

for role_name <- roles do
  Repo.get_by(Role, organization_id: organization.id, name: role_name) ||
    Repo.insert!(%Role{organization_id: organization.id, name: role_name, is_system: true})
end

admin_role = Repo.get_by!(Role, organization_id: organization.id, name: "Super Admin")
manager_role = Repo.get_by!(Role, organization_id: organization.id, name: "Branch Manager")
counselor_role = Repo.get_by!(Role, organization_id: organization.id, name: "Counselor")

Repo.get_by(University, organization_id: organization.id, name: "Default University") ||
  Repo.insert!(%University{organization_id: organization.id, name: "Default University"})

Access.seed_permissions!()
Access.assign_default_permissions!(admin_role)
Access.assign_default_permissions!(manager_role)
Access.assign_default_permissions!(counselor_role)

admin_email = "admin@koncrm.local"

unless Repo.get_by(Backend.Accounts.User, email: admin_email) do
  {:ok, _user} =
    Accounts.register_user(%{
      full_name: "KonCRM Admin",
      email: admin_email,
      password: "ChangeMe123",
      organization_id: organization.id,
      branch_id: hq_branch.id,
      role_id: admin_role.id
    })
end
