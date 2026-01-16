defmodule BackendWeb.Plugs.RequireBranchScope do
  import Plug.Conn

  alias Backend.Access

  def init(opts), do: Keyword.get(opts, :param, "branch_id")

  def call(conn, param_key) do
    user = conn.assigns[:current_scope] && conn.assigns.current_scope.user
    requested_branch = conn.params[param_key] || conn.assigns[param_key]

    cond do
      is_nil(user) ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.text("forbidden")
        |> halt()

      Access.super_admin?(user) ->
        conn

      is_nil(requested_branch) ->
        conn

      to_string(user.branch_id) == to_string(requested_branch) ->
        conn

      true ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.text("forbidden")
        |> halt()
    end
  end
end
