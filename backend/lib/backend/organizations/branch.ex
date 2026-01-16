defmodule Backend.Organizations.Branch do
  use Ecto.Schema
  import Ecto.Changeset

  schema "branches" do
    field :name, :string
    field :city, :string
    field :state, :string
    field :is_active, :boolean, default: true

    belongs_to :organization, Backend.Organizations.Organization
    has_many :users, Backend.Accounts.User

    timestamps()
  end

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [:name, :city, :state, :is_active, :organization_id])
    |> validate_required([:name, :organization_id])
    |> validate_length(:name, min: 2, max: 120)
  end
end
