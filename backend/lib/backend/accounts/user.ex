defmodule Backend.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Backend.Repo

  @derive {Inspect, except: [:password, :hashed_password]}
  schema "users" do
    field(:full_name, :string)
    field(:email, :string)
    field(:phone_number, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:password_confirmation, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :utc_datetime)
    field(:authenticated_at, :utc_datetime)
    field(:last_login_at, :utc_datetime)
    field(:is_active, :boolean, default: true)

    belongs_to(:organization, Backend.Organizations.Organization)
    belongs_to(:branch, Backend.Organizations.Branch)
    belongs_to(:role, Backend.Access.Role)

    timestamps()
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:full_name, :email, :phone_number, :password, :password_confirmation])
    |> validate_required([:full_name, :email, :password])
    |> validate_length(:full_name, min: 2, max: 120)
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc """
  A user changeset for changing the email.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> validate_email_changed()
  end

  @doc """
  A user changeset for changing the password.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_password(opts)
  end

  @doc """
  A user changeset for updating profile fields by admin.
  """
  def profile_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:full_name, :phone_number, :role_id, :branch_id, :is_active])
    |> validate_required([:full_name])
    |> validate_length(:full_name, min: 2, max: 120)
  end

  @doc """
  Confirms the account.
  """
  def confirm_changeset(user) do
    change(user, confirmed_at: DateTime.utc_now(:second))
  end

  @doc """
  Verifies the password.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and is_binary(password) do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _), do: Bcrypt.no_user_verify()

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> update_change(:email, &String.downcase/1)
    |> validate_length(:email, max: 160)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> maybe_validate_unique_email(opts)
  end

  defp validate_email_changed(changeset) do
    current_email = changeset.data.email

    new_email =
      get_change(changeset, :email) ||
        (changeset.params && (changeset.params["email"] || changeset.params[:email]))

    if is_binary(current_email) and is_binary(new_email) and
         String.downcase(current_email) == String.downcase(new_email) do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_confirmation(:password, message: "does not match password")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && is_binary(password) and changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
