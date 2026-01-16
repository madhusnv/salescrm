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
alias Backend.Accounts
alias Backend.Access.{Permission, Role, RolePermission}
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

permission_keys = [
  "org.manage",
  "branch.manage",
  "user.manage",
  "role.manage",
  "permission.manage",
  "lead.import",
  "lead.assign",
  "lead.read",
  "lead.update",
  "call.read",
  "call.write",
  "recording.read",
  "recording.review",
  "analytics.read"
]

for key <- permission_keys do
  Repo.get_by(Permission, key: key) ||
    Repo.insert!(%Permission{key: key, description: key, category: "core"})
end

permission_map = %{
  admin_role.id => permission_keys,
  manager_role.id => [
    "branch.manage",
    "user.manage",
    "lead.import",
    "lead.assign",
    "lead.read",
    "lead.update",
    "call.read",
    "call.write",
    "recording.read",
    "recording.review",
    "analytics.read"
  ],
  counselor_role.id => [
    "lead.read",
    "lead.update",
    "call.read",
    "call.write",
    "recording.read"
  ]
}

permissions_by_key =
  Permission
  |> Repo.all()
  |> Map.new(fn permission -> {permission.key, permission.id} end)

for {role_id, keys} <- permission_map do
  for key <- keys do
    permission_id = Map.fetch!(permissions_by_key, key)

    Repo.get_by(RolePermission, role_id: role_id, permission_id: permission_id) ||
      Repo.insert!(%RolePermission{role_id: role_id, permission_id: permission_id})
  end
end

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
