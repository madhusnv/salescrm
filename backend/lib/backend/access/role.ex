defmodule Backend.Access.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :description, :string
    field :is_system, :boolean, default: false

    belongs_to :organization, Backend.Organizations.Organization

    many_to_many :permissions, Backend.Access.Permission,
      join_through: Backend.Access.RolePermission

    has_many :users, Backend.Accounts.User

    timestamps()
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description, :is_system, :organization_id])
    |> validate_required([:name, :organization_id])
    |> validate_length(:name, min: 2, max: 80)
  end
end
