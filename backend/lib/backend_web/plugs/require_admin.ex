defmodule BackendWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug that requires the user to be an admin (Super Admin or Branch Manager).
  Uses Policy-based authorization instead of role name checks.
  """

  import Plug.Conn

  alias Backend.Access.{Permissions, Policy}

  def init(opts), do: opts

  def call(conn, _opts) do
    scope = conn.assigns[:current_scope]

    if scope && admin_access?(scope) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.text("forbidden")
      |> halt()
    end
  end

  defp admin_access?(scope) do
    scope.is_super_admin or
      Enum.any?(
        [
          Permissions.admin_users(),
          Permissions.admin_branches(),
          Permissions.admin_roles(),
          Permissions.admin_settings()
        ],
        &Policy.can?(scope, &1)
      )
  end
end
