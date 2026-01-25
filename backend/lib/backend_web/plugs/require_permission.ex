defmodule BackendWeb.Plugs.RequirePermission do
  import Plug.Conn

  alias Backend.Access.Policy

  def init(permission_key), do: permission_key

  def call(conn, permission_key) do
    scope = conn.assigns[:current_scope]

    if scope && authorized?(scope, permission_key) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.text("forbidden")
      |> halt()
    end
  end

  defp authorized?(scope, permission_key) when is_binary(permission_key) do
    Policy.can?(scope, permission_key)
  end

  defp authorized?(scope, permissions) when is_list(permissions) do
    Enum.any?(permissions, &Policy.can?(scope, &1))
  end
end
