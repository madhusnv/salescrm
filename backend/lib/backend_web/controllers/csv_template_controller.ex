defmodule BackendWeb.CsvTemplateController do
  use BackendWeb, :controller

  plug BackendWeb.Plugs.RequirePermission, "lead.import"

  def show(conn, _params) do
    csv = "student_name,phone_number\n"

    send_download(conn, {:binary, csv},
      content_type: "text/csv",
      filename: "lead_import_template.csv"
    )
  end
end
