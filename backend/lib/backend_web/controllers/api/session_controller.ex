defmodule BackendWeb.Api.SessionController do
  use BackendWeb, :controller

  alias Backend.Accounts
  alias BackendWeb.ApiToken

  def create(conn, %{"email" => email, "password" => password}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      access_token = ApiToken.sign_access_token(user)
      refresh_token = Accounts.generate_user_refresh_token(user)

      json(conn, %{
        access_token: access_token,
        refresh_token: refresh_token,
        token_type: "bearer",
        expires_in: ApiToken.access_token_ttl_seconds()
      })
    else
      unauthorized(conn)
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.exchange_refresh_token(refresh_token) do
      {:ok, {user, new_refresh_token}} ->
        access_token = ApiToken.sign_access_token(user)

        json(conn, %{
          access_token: access_token,
          refresh_token: new_refresh_token,
          token_type: "bearer",
          expires_in: ApiToken.access_token_ttl_seconds()
        })

      {:error, _reason} ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_credentials"})
  end
end
