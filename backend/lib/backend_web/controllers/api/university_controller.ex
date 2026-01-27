defmodule BackendWeb.Api.UniversityController do
  use BackendWeb, :controller

  plug(BackendWeb.Plugs.RequirePermission, Backend.Access.Policy.lead_read_permissions())

  alias Backend.Organizations

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    universities = Organizations.list_universities(scope.user.organization_id)

    json(conn, %{
      data:
        Enum.map(universities, fn university -> %{id: university.id, name: university.name} end)
    })
  end
end
