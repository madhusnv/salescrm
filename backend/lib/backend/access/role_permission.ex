defmodule Backend.Access.RolePermission do
  use Ecto.Schema

  schema "role_permissions" do
    belongs_to :role, Backend.Access.Role
    belongs_to :permission, Backend.Access.Permission

    timestamps()
  end
end
