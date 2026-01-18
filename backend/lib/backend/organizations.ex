defmodule Backend.Organizations do
  import Ecto.Query, warn: false

  alias Backend.Repo
  alias Backend.Organizations.{Organization, Branch, University}

  def get_organization!(id), do: Repo.get!(Organization, id)

  # Branches

  def get_branch!(id), do: Repo.get!(Branch, id)

  def list_branches(organization_id) do
    Repo.all(
      from(b in Branch, where: b.organization_id == ^organization_id, order_by: [asc: b.name])
    )
  end

  def create_branch(attrs) do
    %Branch{}
    |> Branch.changeset(attrs)
    |> Repo.insert()
  end

  def update_branch(%Branch{} = branch, attrs) do
    branch
    |> Branch.changeset(attrs)
    |> Repo.update()
  end

  def delete_branch(%Branch{} = branch) do
    Repo.delete(branch)
  end

  def change_branch(%Branch{} = branch, attrs \\ %{}) do
    Branch.changeset(branch, attrs)
  end

  # Universities

  def get_university!(id), do: Repo.get!(University, id)

  def list_universities(organization_id) do
    Repo.all(
      from(u in University, where: u.organization_id == ^organization_id, order_by: [asc: u.name])
    )
  end

  def create_university(attrs) do
    %University{}
    |> University.changeset(attrs)
    |> Repo.insert()
  end

  def update_university(%University{} = university, attrs) do
    university
    |> University.changeset(attrs)
    |> Repo.update()
  end

  def delete_university(%University{} = university) do
    Repo.delete(university)
  end

  def change_university(%University{} = university, attrs \\ %{}) do
    University.changeset(university, attrs)
  end

  # Organizations

  def change_organization(%Organization{} = organization, attrs \\ %{}) do
    Organization.changeset(organization, attrs)
  end

  def update_organization(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
  end
end
