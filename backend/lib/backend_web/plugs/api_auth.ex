defmodule BackendWeb.Plugs.ApiAuth do
  import Plug.Conn
  require Logger

  alias Backend.Accounts
  alias Backend.Accounts.Scope
  alias BackendWeb.ApiToken

  def init(mode), do: mode

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :require_authenticated), do: require_authenticated(conn, [])

  def fetch_current_user(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, %{user_id: user_id}} <- ApiToken.verify_access_token(token),
         %{} = user <- Accounts.get_user(user_id) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_scope, Scope.for_user(user))
    else
      error ->
        Logger.warning("ApiAuth failed: #{inspect(error)}, auth_header=#{inspect(get_req_header(conn, "authorization"))}")
        conn
    end
  end

  def require_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.json(%{error: "unauthorized"})
      |> halt()
    end
  end
end
