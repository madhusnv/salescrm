defmodule Backend.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  schema "organizations" do
    field(:name, :string)
    field(:country, :string, default: "IN")
    field(:timezone, :string, default: "Asia/Kolkata")
    field(:is_active, :boolean, default: true)

    has_many(:branches, Backend.Organizations.Branch)
    has_many(:universities, Backend.Organizations.University)
    has_many(:roles, Backend.Access.Role)
    has_many(:users, Backend.Accounts.User)

    timestamps()
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :country, :timezone, :is_active])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
  end
end
