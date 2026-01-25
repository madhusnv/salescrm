defmodule Backend.Repo.Migrations.SeedAuthorizationPermissions do
  use Ecto.Migration

  import Ecto.Query

  def up do
    permissions = [
      %{key: "leads.read_all", description: "Read all leads in organization", category: "leads"},
      %{key: "leads.read_branch", description: "Read leads in own branch", category: "leads"},
      %{key: "leads.read_own", description: "Read own assigned leads", category: "leads"},
      %{key: "leads.create", description: "Create leads", category: "leads"},
      %{key: "leads.update", description: "Update leads", category: "leads"},
      %{key: "leads.delete", description: "Delete leads", category: "leads"},
      %{key: "leads.assign", description: "Assign leads to counselors", category: "leads"},
      %{
        key: "leads.reassign",
        description: "Reassign leads between counselors",
        category: "leads"
      },
      %{key: "leads.import", description: "Import leads from CSV", category: "leads"},
      %{key: "leads.export", description: "Export leads", category: "leads"},
      %{key: "calls.read_all", description: "Read all call logs", category: "calls"},
      %{key: "calls.read_branch", description: "Read branch call logs", category: "calls"},
      %{key: "recordings.playback", description: "Play call recordings", category: "recordings"},
      %{
        key: "recordings.download",
        description: "Download call recordings",
        category: "recordings"
      },
      %{key: "analytics.org", description: "View organization analytics", category: "analytics"},
      %{key: "analytics.branch", description: "View branch analytics", category: "analytics"},
      %{key: "analytics.own", description: "View own analytics", category: "analytics"},
      %{key: "admin.users", description: "Manage users", category: "admin"},
      %{key: "admin.branches", description: "Manage branches", category: "admin"},
      %{key: "admin.roles", description: "Manage roles", category: "admin"},
      %{key: "admin.settings", description: "Manage settings", category: "admin"},
      %{key: "audit.read", description: "Read audit logs", category: "audit"},
      %{key: "reports.counselors", description: "View counselor reports", category: "reports"}
    ]

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    permission_rows =
      Enum.map(permissions, fn perm ->
        Map.merge(perm, %{inserted_at: now, updated_at: now})
      end)

    repo().insert_all("permissions", permission_rows, on_conflict: :nothing)

    assign_permissions_to_roles()
  end

  def down do
    repo().delete_all(from(rp in "role_permissions"))

    repo().delete_all(
      from(p in "permissions",
        where:
          p.category in ["leads", "calls", "recordings", "analytics", "admin", "audit", "reports"]
      )
    )
  end

  defp assign_permissions_to_roles do
    super_admin_permissions = [
      "leads.read_all",
      "leads.read_branch",
      "leads.read_own",
      "leads.create",
      "leads.update",
      "leads.delete",
      "leads.assign",
      "leads.reassign",
      "leads.import",
      "leads.export",
      "calls.read_all",
      "calls.read_branch",
      "recordings.playback",
      "recordings.download",
      "analytics.org",
      "analytics.branch",
      "analytics.own",
      "admin.users",
      "admin.branches",
      "admin.roles",
      "admin.settings",
      "audit.read",
      "reports.counselors"
    ]

    branch_manager_permissions = [
      "leads.read_branch",
      "leads.create",
      "leads.update",
      "leads.assign",
      "leads.reassign",
      "leads.import",
      "leads.export",
      "calls.read_branch",
      "recordings.playback",
      "analytics.branch",
      "reports.counselors"
    ]

    counselor_permissions = [
      "leads.read_own",
      "leads.update",
      "recordings.playback",
      "analytics.own"
    ]

    roles = repo().all(from(r in "roles", select: %{id: r.id, name: r.name}))

    Enum.each(roles, fn role ->
      perms =
        case role.name do
          "Super Admin" -> super_admin_permissions
          "Branch Manager" -> branch_manager_permissions
          "Counselor" -> counselor_permissions
          _ -> []
        end

      assign_permissions(role.id, perms)
    end)
  end

  defp assign_permissions(role_id, permission_keys) do
    permissions =
      repo().all(from(p in "permissions", where: p.key in ^permission_keys, select: %{id: p.id}))

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    role_permissions =
      Enum.map(permissions, fn perm ->
        %{role_id: role_id, permission_id: perm.id, inserted_at: now, updated_at: now}
      end)

    repo().insert_all("role_permissions", role_permissions, on_conflict: :nothing)
  end
end
