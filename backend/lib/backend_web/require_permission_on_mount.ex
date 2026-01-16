defmodule BackendWeb.RequirePermissionOnMount do
  use BackendWeb, :verified_routes

  import Phoenix.LiveView

  alias Backend.Access

  def on_mount(permission_key, _params, _session, socket) when is_binary(permission_key) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user && Access.role_has_permission?(user, permission_key) do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You do not have access to that page.")
        |> push_navigate(to: ~p"/dashboard")

      {:halt, socket}
    end
  end
end
