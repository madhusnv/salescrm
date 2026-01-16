defmodule Backend.Access.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "permissions" do
    field :key, :string
    field :description, :string
    field :category, :string

    many_to_many :roles, Backend.Access.Role, join_through: Backend.Access.RolePermission

    timestamps()
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:key, :description, :category])
    |> validate_required([:key])
    |> validate_length(:key, min: 3, max: 120)
    |> validate_format(:key, ~r/^[a-z0-9_\.]+$/)
  end
end
