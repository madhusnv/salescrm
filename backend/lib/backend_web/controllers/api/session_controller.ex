defmodule BackendWeb.Api.SessionController do
  use BackendWeb, :controller

  alias Backend.Accounts
  alias BackendWeb.ApiToken

  plug BackendWeb.Plugs.RateLimit,
       [limit: 5, window_ms: 60_000, key_prefix: "login"] when action == :create

  plug BackendWeb.Plugs.RateLimit,
       [limit: 10, window_ms: 60_000, key_prefix: "refresh"] when action == :refresh

  def create(conn, %{"email" => email, "password" => password}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      access_token = ApiToken.sign_access_token(user)
      refresh_token = Accounts.generate_user_refresh_token(user)

      json(conn, %{
        access_token: access_token,
        refresh_token: refresh_token,
        token_type: "bearer",
        expires_in: ApiToken.access_token_ttl_seconds(),
        user_id: user.id,
        user: %{
          id: user.id,
          email: user.email,
          full_name: user.full_name
        }
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
          expires_in: ApiToken.access_token_ttl_seconds(),
          user_id: user.id,
          user: %{
            id: user.id,
            email: user.email,
            full_name: user.full_name
          }
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
