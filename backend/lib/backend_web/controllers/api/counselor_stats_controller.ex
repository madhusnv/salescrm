defmodule BackendWeb.Api.CounselorStatsController do
  use BackendWeb, :controller

  plug(
    BackendWeb.Plugs.RequirePermission,
    Backend.Access.Policy.lead_read_permissions()
  )

  alias Backend.Reports

  def show(conn, params) do
    scope = conn.assigns.current_scope
    filter = Map.get(params, "filter", "today")
    date_range = Reports.date_range_for_filter(filter)
    stats = Reports.counselor_call_stats(scope, date_range)

    json(conn, %{
      data: stats,
      meta: %{
        filter: filter
      }
    })
  end
end
