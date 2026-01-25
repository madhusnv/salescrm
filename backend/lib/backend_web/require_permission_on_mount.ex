defmodule BackendWeb.RequirePermissionOnMount do
  use BackendWeb, :verified_routes

  import Phoenix.LiveView

  alias Backend.Access.Policy

  def on_mount(permission_key, _params, _session, socket) do
    scope = socket.assigns.current_scope

    if scope && authorized?(scope, permission_key) do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You do not have access to that page.")
        |> push_navigate(to: ~p"/dashboard")

      {:halt, socket}
    end
  end

  defp authorized?(scope, permission_key) when is_binary(permission_key) do
    Policy.can?(scope, permission_key)
  end

  defp authorized?(scope, permissions) when is_list(permissions) do
    Enum.any?(permissions, &Policy.can?(scope, &1))
  end
end
