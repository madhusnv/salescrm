defmodule Backend.Access do
  @moduledoc """
  Access control context for roles and permissions.

  For authorization checks, use `Backend.Access.Policy` instead of
  checking role names directly.
  """

  import Ecto.Query, warn: false

  alias Backend.Repo
  alias Backend.Access.{Permissions, Role, Permission, RolePermission, Policy}
  alias Backend.Accounts.{User, Scope}

  def get_role!(id), do: Repo.get!(Role, id)
  def get_permission!(id), do: Repo.get!(Permission, id)

  def list_roles do
    Repo.all(from(r in Role, order_by: [asc: r.name]))
  end

  def list_permissions do
    Repo.all(from(p in Permission, order_by: [asc: p.category, asc: p.key]))
  end

  def change_role(%Role{} = role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end

  def change_permission(%Permission{} = permission, attrs \\ %{}) do
    Permission.changeset(permission, attrs)
  end

  def change_role_permission(%RolePermission{} = role_permission, attrs \\ %{}) do
    Ecto.Changeset.cast(role_permission, attrs, [:role_id, :permission_id])
  end

  @doc """
  Check if a role has a specific permission.
  Prefer using `Policy.can?(scope, permission)` for authorization checks.
  """
  def role_has_permission?(%User{role_id: role_id}, permission_key)
      when is_binary(permission_key) do
    role_has_permission?(role_id, permission_key)
  end

  def role_has_permission?(role_id, permission_key) do
    query =
      from(rp in RolePermission,
        join: p in Permission,
        on: rp.permission_id == p.id,
        where: rp.role_id == ^role_id and p.key == ^permission_key
      )

    Repo.exists?(query)
  end

  @doc """
  Check if user is a super admin.

  DEPRECATED: Use `scope.is_super_admin` or `Policy.can?(scope, permission)` instead.
  This function performs a DB query on every call.
  """
  def super_admin?(%User{role_id: role_id}) do
    required = Permissions.super_admin_permissions()

    count =
      from(rp in RolePermission,
        join: p in Permission,
        on: rp.permission_id == p.id,
        where: rp.role_id == ^role_id and p.key in ^required,
        select: count(p.id)
      )
      |> Repo.one()

    count == length(required)
  end

  @doc """
  Check if scope has a permission. Delegates to Policy.can?/2.
  """
  def can?(%Scope{} = scope, permission) do
    Policy.can?(scope, permission)
  end

  @doc """
  Seed default permissions from the Permissions registry.
  """
  def seed_permissions! do
    alias Backend.Access.Permissions

    Enum.each(Permissions.all(), fn perm ->
      case Repo.get_by(Permission, key: perm.key) do
        nil ->
          %Permission{}
          |> Permission.changeset(perm)
          |> Repo.insert!()

        _existing ->
          :ok
      end
    end)
  end

  @doc """
  Assign default permissions to a role based on role name.
  """
  def assign_default_permissions!(role) do
    alias Backend.Access.Permissions

    permission_keys =
      case role.name do
        "Super Admin" -> Permissions.super_admin_permissions()
        "Branch Manager" -> Permissions.branch_manager_permissions()
        "Counselor" -> Permissions.counselor_permissions()
        _ -> []
      end

    Enum.each(permission_keys, fn key ->
      case Repo.get_by(Permission, key: key) do
        nil ->
          :ok

        permission ->
          unless Repo.get_by(RolePermission, role_id: role.id, permission_id: permission.id) do
            %RolePermission{role_id: role.id, permission_id: permission.id}
            |> Repo.insert!()
          end
      end
    end)
  end
end
