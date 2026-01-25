defmodule BackendWeb.Plugs.RequireBranchScope do
  @moduledoc """
  Plug that ensures the user has access to the requested branch.
  Super admins can access any branch, others only their own.
  """

  import Plug.Conn

  def init(opts), do: Keyword.get(opts, :param, "branch_id")

  def call(conn, param_key) do
    scope = conn.assigns[:current_scope]
    requested_branch = conn.params[param_key] || conn.assigns[param_key]

    cond do
      is_nil(scope) or is_nil(scope.user) ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.text("forbidden")
        |> halt()

      scope.is_super_admin ->
        conn

      is_nil(requested_branch) ->
        conn

      to_string(scope.branch_id) == to_string(requested_branch) ->
        conn

      true ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.text("forbidden")
        |> halt()
    end
  end
end
