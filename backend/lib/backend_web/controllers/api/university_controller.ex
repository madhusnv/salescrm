defmodule BackendWeb.Api.UniversityController do
  use BackendWeb, :controller

  plug(BackendWeb.Plugs.RequirePermission, "lead.read")

  alias Backend.Accounts.Scope
  alias Backend.Organizations

  def index(conn, _params) do
    scope = Scope.for_user(conn.assigns.current_user)
    universities = Organizations.list_universities(scope.user.organization_id)

    json(conn, %{
      data:
        Enum.map(universities, fn university -> %{id: university.id, name: university.name} end)
    })
  end
end
