defmodule BackendWeb.Plugs.RequireAdmin do
  import Plug.Conn
  alias Backend.Access
  alias Backend.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_scope] && conn.assigns.current_scope.user

    if user && admin_or_branch_manager?(user) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.text("forbidden")
      |> halt()
    end
  end

  defp admin_or_branch_manager?(user) do
    Access.super_admin?(user) || role_name(user) == "Branch Manager"
  end

  defp role_name(user) do
    import Ecto.Query
    Repo.one(from(r in Backend.Access.Role, where: r.id == ^user.role_id, select: r.name))
  end
end
