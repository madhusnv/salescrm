defmodule Backend.Accounts do
  import Ecto.Query, warn: false

  alias Backend.Repo
  alias Backend.Access.Role
  alias Backend.Accounts.{Scope, User, UserToken, UserNotifier}
  alias Backend.Organizations.{Branch, Organization}

  ## Database getters

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: String.downcase(email))
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by id.
  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user scoped to organization.
  """
  def get_user!(%Scope{} = scope, id) do
    User
    |> where([u], u.id == ^id and u.organization_id == ^scope.user.organization_id)
    |> Repo.one!()
    |> Repo.preload(:role)
  end

  @doc """
  Lists all users in the organization.
  """
  def list_users(%Scope{} = scope) do
    User
    |> where([u], u.organization_id == ^scope.user.organization_id)
    |> order_by([u], asc: u.full_name, asc: u.email)
    |> Repo.all()
    |> Repo.preload(:role)
  end

  @doc """
  Returns a changeset for updating user profile.
  """
  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Updates a user's profile.
  """
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Toggles user active status.
  """
  def toggle_active(%User{} = user) do
    user
    |> Ecto.Changeset.change(is_active: !user.is_active)
    |> Repo.update()
  end

  ## User registration

  @doc """
  Registers a user with email/password.
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> put_optional_change(:organization_id, attrs)
    |> put_optional_change(:branch_id, attrs)
    |> put_optional_change(:role_id, attrs)
    |> Ecto.Changeset.validate_required([:organization_id, :role_id])
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for user registration.
  """
  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  @doc """
  Returns default IDs for registrations when explicit scope is not provided.
  """
  def registration_defaults do
    organization =
      Repo.one(from(o in Organization, order_by: [asc: o.id], limit: 1)) ||
        Repo.insert!(%Organization{name: "KonCRM", country: "IN", timezone: "Asia/Kolkata"})

    branch =
      Repo.one(
        from(b in Branch,
          where: b.organization_id == ^organization.id,
          order_by: [asc: b.id],
          limit: 1
        )
      ) || Repo.insert!(%Branch{organization_id: organization.id, name: "HQ"})

    role =
      Repo.get_by(Role, organization_id: organization.id, name: "Counselor") ||
        Repo.insert!(%Role{organization_id: organization.id, name: "Counselor", is_system: true})

    %{
      organization_id: organization.id,
      branch_id: branch.id,
      role_id: role.id
    }
  end

  defp put_optional_change(changeset, field, attrs) do
    value = Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))

    if is_nil(value) do
      changeset
    else
      Ecto.Changeset.put_change(changeset, field, value)
    end
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.
  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transaction(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        user
      else
        _ -> Repo.rollback(:transaction_aborted)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.
  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  def list_counselors(organization_id, branch_id \\ nil) do
    query =
      User
      |> where([u], u.organization_id == ^organization_id)
      |> join(:inner, [u], r in assoc(u, :role))
      |> where([_u, r], r.name == "Counselor")
      |> order_by([u], asc: u.full_name)

    query =
      if is_nil(branch_id) || branch_id == "" do
        query
      else
        where(query, [u], u.branch_id == ^branch_id)
      end

    Repo.all(query)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.
  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  @doc """
  Generates a refresh token.
  """
  def generate_user_refresh_token(user) do
    {token, user_token} = UserToken.build_refresh_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given refresh token.
  """
  def get_user_by_refresh_token(token) do
    with {:ok, query} <- UserToken.verify_refresh_token_query(token),
         {user, user_token} <- Repo.one(query) do
      {user, user_token}
    else
      _ -> nil
    end
  end

  @doc """
  Exchanges a refresh token and rotates it.
  """
  def exchange_refresh_token(token) do
    case get_user_by_refresh_token(token) do
      {user, user_token} ->
        Repo.delete!(user_token)
        {:ok, {user, generate_user_refresh_token(user)}}

      _ ->
        {:error, :invalid_token}
    end
  end

  ## Email notifications

  @doc ~S"""
  Delivers the update email instructions to the given user.
  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transaction(fn ->
      case Repo.update(changeset) do
        {:ok, user} ->
          tokens_to_expire = Repo.all(from(t in UserToken, where: t.user_id == ^user.id))

          Repo.delete_all(
            from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id))
          )

          {user, tokens_to_expire}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end
end
