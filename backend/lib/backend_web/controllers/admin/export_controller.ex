defmodule BackendWeb.Admin.ExportController do
  use BackendWeb, :controller

  alias Backend.Leads

  plug :require_authenticated_user
  plug BackendWeb.Plugs.RequireAdmin

  def leads(conn, _params) do
    scope = conn.assigns.current_scope
    leads = Leads.list_leads(scope, %{}, 1, 10000)

    csv_content = generate_leads_csv(leads)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"leads_export_#{Date.utc_today()}.csv\""
    )
    |> send_resp(200, csv_content)
  end

  defp generate_leads_csv(leads) do
    headers = ["ID", "Name", "Phone", "Status", "University", "Assigned To", "Created At"]

    rows =
      Enum.map(leads, fn lead ->
        [
          lead.id,
          sanitize_csv_value(lead.student_name),
          sanitize_csv_value(lead.phone_number),
          sanitize_csv_value(lead.status),
          sanitize_csv_value(lead.university && lead.university.name),
          sanitize_csv_value(lead.assigned_counselor && lead.assigned_counselor.full_name),
          format_datetime(lead.inserted_at)
        ]
      end)

    [headers | rows]
    |> Enum.map(&encode_csv_row/1)
    |> Enum.join("\r\n")
  end

  defp encode_csv_row(row) do
    row
    |> Enum.map(&escape_csv_field/1)
    |> Enum.join(",")
  end

  defp escape_csv_field(nil), do: ""
  defp escape_csv_field(value) when is_integer(value), do: to_string(value)
  defp escape_csv_field(value) when is_atom(value), do: escape_csv_field(to_string(value))

  defp escape_csv_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  # Neutralize formula injection - prefix with single quote if starts with formula chars
  defp sanitize_csv_value(nil), do: nil
  defp sanitize_csv_value(value) when is_atom(value), do: sanitize_csv_value(to_string(value))

  defp sanitize_csv_value(value) when is_binary(value) do
    case value do
      <<"=", _::binary>> -> "'" <> value
      <<"+", _::binary>> -> "'" <> value
      <<"-", _::binary>> -> "'" <> value
      <<"@", _::binary>> -> "'" <> value
      _ -> value
    end
  end

  defp sanitize_csv_value(value), do: value

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  defp format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized"})
      |> halt()
    end
  end
end
