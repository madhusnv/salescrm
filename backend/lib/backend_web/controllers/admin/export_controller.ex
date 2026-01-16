defmodule BackendWeb.Admin.ExportController do
  use BackendWeb, :controller

  alias Backend.Leads

  plug :require_authenticated_user

  def leads(conn, _params) do
    scope = conn.assigns.current_scope
    {leads, _total} = Leads.list_leads(scope, %{}, 1, 10000)

    csv_content = generate_leads_csv(leads)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"leads_export_#{Date.utc_today()}.csv\"")
    |> send_resp(200, csv_content)
  end

  defp generate_leads_csv(leads) do
    headers = ["ID", "Name", "Email", "Phone", "Status", "University", "Assigned To", "Created At"]

    rows = Enum.map(leads, fn lead ->
      [
        lead.id,
        lead.name || "",
        lead.email || "",
        lead.phone_number || "",
        lead.status || "",
        (lead.university && lead.university.name) || "",
        (lead.counselor && (lead.counselor.full_name || lead.counselor.email)) || "",
        Calendar.strftime(lead.inserted_at, "%Y-%m-%d %H:%M:%S")
      ]
    end)

    [headers | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized"})
      |> halt()
    end
  end
end
