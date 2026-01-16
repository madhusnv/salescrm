defmodule BackendWeb.Api.CallLogController do
  use BackendWeb, :controller

  plug(BackendWeb.Plugs.RequirePermission, "call.write" when action in [:create])
  plug(BackendWeb.Plugs.RequirePermission, "call.read" when action in [:index])

  alias Backend.Accounts.Scope
  alias Backend.Calls

  def create(conn, params) do
    scope = Scope.for_user(conn.assigns.current_user)

    attrs = %{
      "phone_number" => Map.get(params, "phone_number"),
      "call_type" => normalize_call_type(Map.get(params, "call_type")),
      "device_call_id" => Map.get(params, "device_call_id"),
      "started_at" => parse_datetime(Map.get(params, "started_at")),
      "ended_at" => parse_datetime_optional(Map.get(params, "ended_at")),
      "duration_seconds" => Map.get(params, "duration_seconds"),
      "consent_granted" => Map.get(params, "consent_granted", false),
      "consent_recorded_at" => parse_datetime_optional(Map.get(params, "consent_recorded_at")),
      "consent_source" => Map.get(params, "consent_source"),
      "metadata" => Map.get(params, "metadata")
    }

    case Calls.create_call_log(scope, attrs) do
      {:ok, call_log, :created} ->
        json(conn, %{data: render_call_log(call_log), status: "created"})

      {:ok, call_log, :duplicate} ->
        json(conn, %{data: render_call_log(call_log), status: "duplicate"})

      {:error, :invalid_phone} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_phone"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "call_log_failed", details: errors_on(changeset)})
    end
  end

  def index(conn, params) do
    scope = Scope.for_user(conn.assigns.current_user)
    lead_id = parse_int(Map.get(params, "lead_id"), nil)
    page = parse_int(Map.get(params, "page", "1"), 1)
    page_size = parse_int(Map.get(params, "page_size", "20"), 20)
    offset = max(page - 1, 0) * page_size

    if is_nil(lead_id) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "lead_id_required"})
    else
      logs = Calls.list_call_logs_for_lead(scope, lead_id, page_size, offset)
      json(conn, %{data: Enum.map(logs, &render_call_log/1)})
    end
  end

  defp normalize_call_type(nil), do: nil

  defp normalize_call_type(type) when is_binary(type) do
    type
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_call_type(type) when is_atom(type),
    do: type |> Atom.to_string() |> normalize_call_type()

  defp normalize_call_type(_), do: nil

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(value) when is_integer(value) do
    case DateTime.from_unix(value, :second) do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp parse_datetime(_), do: nil

  defp parse_datetime_optional(nil), do: nil
  defp parse_datetime_optional(""), do: nil
  defp parse_datetime_optional(value), do: parse_datetime(value)

  defp render_call_log(call_log) do
    %{
      id: call_log.id,
      call_type: call_log.call_type,
      phone_number: call_log.phone_number,
      started_at: call_log.started_at && DateTime.to_iso8601(call_log.started_at),
      ended_at: call_log.ended_at && DateTime.to_iso8601(call_log.ended_at),
      duration_seconds: call_log.duration_seconds,
      consent_granted: call_log.consent_granted,
      consent_recorded_at:
        call_log.consent_recorded_at && DateTime.to_iso8601(call_log.consent_recorded_at),
      consent_source: call_log.consent_source
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp parse_int(value, default) do
    case Integer.parse(to_string(value)) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end
end
