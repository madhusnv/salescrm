defmodule Backend.Access do
  import Ecto.Query, warn: false

  alias Backend.Repo
  alias Backend.Access.{Role, Permission, RolePermission}
  alias Backend.Accounts.User

  def get_role!(id), do: Repo.get!(Role, id)
  def get_permission!(id), do: Repo.get!(Permission, id)

  def list_roles do
    Repo.all(from(r in Role, order_by: [asc: r.name]))
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

    if Repo.exists?(query) do
      true
    else
      Repo.exists?(from(r in Role, where: r.id == ^role_id and r.name == "Super Admin"))
    end
  end

  def super_admin?(%User{role_id: role_id}) do
    Repo.exists?(from(r in Role, where: r.id == ^role_id and r.name == "Super Admin"))
  end
end
