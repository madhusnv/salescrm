defmodule BackendWeb.Plugs.RequirePermission do
  import Plug.Conn

  alias Backend.Access

  def init(permission_key), do: permission_key

  def call(conn, permission_key) when is_binary(permission_key) do
    user = conn.assigns[:current_scope] && conn.assigns.current_scope.user

    if user && Access.role_has_permission?(user, permission_key) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.text("forbidden")
      |> halt()
    end
  end
end
