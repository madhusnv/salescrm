defmodule Backend.Organizations.University do
  use Ecto.Schema
  import Ecto.Changeset

  schema "universities" do
    field :name, :string
    field :is_active, :boolean, default: true

    belongs_to :organization, Backend.Organizations.Organization

    timestamps()
  end

  def changeset(university, attrs) do
    university
    |> cast(attrs, [:name, :is_active, :organization_id])
    |> validate_required([:name, :organization_id])
    |> validate_length(:name, min: 2, max: 200)
  end
end
