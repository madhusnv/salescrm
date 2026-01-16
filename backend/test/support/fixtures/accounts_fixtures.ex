defmodule Backend.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Backend.Accounts` context.
  """

  import Ecto.Query

  alias Backend.Accounts
  alias Backend.Accounts.Scope
  alias Backend.Access.Role
  alias Backend.Organizations.{Branch, Organization}
  alias Backend.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    scope = create_scope()

    Enum.into(attrs, %{
      full_name: "Test User",
      email: unique_user_email(),
      password: valid_user_password(),
      password_confirmation: valid_user_password(),
      organization_id: scope.organization_id,
      branch_id: scope.branch_id,
      role_id: scope.role_id
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Backend.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Backend.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end

  defp create_scope do
    uniq = System.unique_integer([:positive])

    organization =
      Repo.insert!(%Organization{
        name: "Test Org #{uniq}",
        country: "IN",
        timezone: "Asia/Kolkata"
      })

    branch =
      Repo.insert!(%Branch{organization_id: organization.id, name: "Branch #{uniq}"})

    role =
      Repo.insert!(%Role{organization_id: organization.id, name: "Counselor #{uniq}"})

    %{
      organization_id: organization.id,
      branch_id: branch.id,
      role_id: role.id
    }
  end
end
