defmodule Backend.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The Scope struct contains preloaded user data, permissions, and role information
  to avoid repeated database queries during authorization checks.

  Built once at authentication time (login or session mount), then passed
  throughout the request lifecycle.
  """

  alias Backend.Accounts.User
  alias Backend.Access.Permissions
  alias Backend.Repo

  import Ecto.Query

  defstruct [
    :user,
    :user_id,
    :organization_id,
    :branch_id,
    :role_id,
    :role_name,
    :permissions,
    :is_super_admin
  ]

  @doc """
  Creates a scope for the given user with preloaded permissions.

  This function:
  - Preloads the user's role and branch
  - Loads all permissions for the user's role
  - Caches everything in the Scope struct

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    user = Repo.preload(user, [:role, :branch])
    permissions = load_permissions(user.role_id)
    permission_set = MapSet.new(permissions)

    is_super_admin =
      Enum.all?(Permissions.super_admin_permissions(), &MapSet.member?(permission_set, &1))

    %__MODULE__{
      user: user,
      user_id: user.id,
      organization_id: user.organization_id,
      branch_id: user.branch_id,
      role_id: user.role_id,
      role_name: user.role && user.role.name,
      permissions: permission_set,
      is_super_admin: is_super_admin
    }
  end

  def for_user(nil), do: nil

  defp load_permissions(nil), do: []

  defp load_permissions(role_id) do
    from(rp in Backend.Access.RolePermission,
      join: p in Backend.Access.Permission,
      on: rp.permission_id == p.id,
      where: rp.role_id == ^role_id,
      select: p.key
    )
    |> Repo.all()
  end
end
