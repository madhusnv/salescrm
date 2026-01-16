defmodule BackendWeb.Api.RecordingController do
  use BackendWeb, :controller

  plug(
    BackendWeb.Plugs.RequirePermission,
    "call.write" when action in [:init, :upload, :complete]
  )

  plug(BackendWeb.Plugs.RequirePermission, "recording.read" when action in [:index])

  alias Backend.Accounts.Scope
  alias Backend.Audit
  alias Backend.Recordings

  def init(conn, params) do
    scope = Scope.for_user(conn.assigns.current_user)

    attrs = %{
      "lead_id" => Map.get(params, "lead_id"),
      "call_log_id" => Map.get(params, "call_log_id"),
      "content_type" => Map.get(params, "content_type", "audio/m4a"),
      "consent_granted" => Map.get(params, "consent_granted", false),
      "recorded_at" => parse_datetime(Map.get(params, "recorded_at")),
      "storage_key" => build_storage_key(scope.user.id)
    }

    case Recordings.init_recording(scope, attrs) do
      {:ok, recording} ->
        json(conn, %{
          data: %{
            id: recording.id,
            upload_url: placeholder_upload_url(recording.id),
            upload_headers: %{},
            storage_key: recording.storage_key
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_on(changeset)})
    end
  end

  def complete(conn, %{"id" => id} = params) do
    scope = Scope.for_user(conn.assigns.current_user)

    attrs = %{
      "status" => Map.get(params, "status", "uploaded"),
      "file_url" => Map.get(params, "file_url"),
      "file_size_bytes" => Map.get(params, "file_size_bytes"),
      "duration_seconds" => Map.get(params, "duration_seconds"),
      "metadata" => Map.get(params, "metadata")
    }

    case Recordings.complete_recording(scope, id, attrs) do
      {:ok, recording} ->
        json(conn, %{
          data: %{id: recording.id, status: recording.status, file_url: recording.file_url}
        })

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_on(changeset)})
    end
  end

  def upload(conn, %{"id" => id}) do
    scope = Scope.for_user(conn.assigns.current_user)

    with recording when not is_nil(recording) <- Recordings.get_recording(scope, id),
         {:ok, file_bytes} <- extract_upload_bytes(conn) do
      storage_key = recording.storage_key || "recordings/#{recording.id}.m4a"
      uploads_root = Path.join([:code.priv_dir(:backend), "static", "uploads"])
      target_path = Path.join(uploads_root, storage_key)
      File.mkdir_p!(Path.dirname(target_path))
      File.write!(target_path, file_bytes)

      file_url = "/uploads/#{storage_key}"

      _ =
        Audit.log(scope, "recording.uploaded", %{
          recording_id: recording.id,
          lead_id: recording.lead_id
        })

      json(conn, %{data: %{file_url: file_url, file_size_bytes: byte_size(file_bytes)}})
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})

      {:error, :invalid_upload} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_upload"})
    end
  end

  def index(conn, params) do
    scope = Scope.for_user(conn.assigns.current_user)
    lead_id = parse_int(Map.get(params, "lead_id"), nil)

    if is_nil(lead_id) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "lead_id_required"})
    else
      recordings = Recordings.list_recordings_for_lead(scope, lead_id)
      _ = Audit.log(scope, "recording.listed", %{lead_id: lead_id})
      json(conn, %{data: Enum.map(recordings, &render_recording/1)})
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil

  defp build_storage_key(user_id) do
    "recordings/#{user_id}/#{Ecto.UUID.generate()}.m4a"
  end

  defp placeholder_upload_url(recording_id) do
    BackendWeb.Endpoint.url() <> "/api/recordings/#{recording_id}/upload"
  end

  defp extract_upload_bytes(conn) do
    case Map.get(conn.params, "file") do
      %Plug.Upload{path: path} ->
        {:ok, File.read!(path)}

      _ ->
        case Plug.Conn.read_body(conn) do
          {:ok, body, _conn} when is_binary(body) and byte_size(body) > 0 ->
            {:ok, body}

          _ ->
            {:error, :invalid_upload}
        end
    end
  end

  defp render_recording(recording) do
    %{
      id: recording.id,
      status: recording.status,
      file_url: recording.file_url,
      duration_seconds: recording.duration_seconds,
      recorded_at: recording.recorded_at && DateTime.to_iso8601(recording.recorded_at),
      counselor_id: recording.counselor_id
    }
  end

  defp parse_int(value, default) do
    case Integer.parse(to_string(value)) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
