defmodule Backend.Recordings do
  import Ecto.Query, warn: false

  alias Backend.Accounts.Scope
  alias Backend.Audit
  alias Backend.Analytics
  alias Backend.Recordings.CallRecording
  alias Backend.Repo
  alias BackendWeb.Broadcaster

  def init_recording(%Scope{} = scope, attrs) do
    user = scope.user

    data =
      attrs
      |> Map.put("organization_id", user.organization_id)
      |> Map.put("branch_id", user.branch_id)
      |> Map.put("counselor_id", user.id)
      |> Map.put_new("status", "pending")

    %CallRecording{}
    |> CallRecording.init_changeset(data)
    |> Repo.insert()
  end

  def complete_recording(%Scope{} = scope, recording_id, attrs) do
    recording = Repo.get!(CallRecording, recording_id)

    cond do
      recording.organization_id != scope.user.organization_id ->
        {:error, :forbidden}

      recording.counselor_id != scope.user.id and not scope.is_super_admin ->
        {:error, :forbidden}

      true ->
        attrs = maybe_put_file_url(recording, attrs)

        recording
        |> CallRecording.complete_changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            _ = Analytics.log_event(scope, "recording_uploaded", %{lead_id: updated.lead_id})

            _ =
              Audit.log(scope, "recording.completed", %{
                recording_id: updated.id,
                lead_id: updated.lead_id
              })

            # Broadcast real-time update
            _ = Broadcaster.broadcast_recording_uploaded(scope.user.id, updated)

            {:ok, updated}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def get_recording(%Scope{} = scope, id) do
    Repo.get_by(CallRecording, id: id, organization_id: scope.user.organization_id)
  end

  def get_recording!(%Scope{} = scope, id) do
    Repo.get_by!(CallRecording, id: id, organization_id: scope.user.organization_id)
  end

  def list_recordings(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    CallRecording
    |> where([r], r.organization_id == ^scope.user.organization_id)
    |> where([r], r.status == :uploaded)
    |> order_by([r], desc: r.recorded_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_playback_url(%CallRecording{} = recording) do
    cond do
      is_binary(recording.storage_key) and recording.storage_key != "" ->
        {:ok, "/uploads/#{recording.storage_key}"}

      is_binary(recording.file_url) and String.starts_with?(recording.file_url, "/uploads/") ->
        {:ok, recording.file_url}

      true ->
        {:error, :no_file}
    end
  end

  def list_recordings_for_lead(%Scope{} = scope, lead_id) do
    CallRecording
    |> where([r], r.lead_id == ^lead_id and r.organization_id == ^scope.user.organization_id)
    |> order_by([r], desc: r.recorded_at)
    |> Repo.all()
  end

  def expire_old_recordings do
    cutoff = DateTime.utc_now(:second) |> DateTime.add(-365 * 24 * 60 * 60, :second)

    base_query =
      CallRecording
      |> where([r], r.recorded_at < ^cutoff and r.status == :uploaded)

    expire_recordings_in_batches(base_query, 0, 200)
  end

  defp expire_recordings_in_batches(base_query, last_id, batch_size) do
    recordings =
      base_query
      |> where([r], r.id > ^last_id)
      |> order_by([r], asc: r.id)
      |> limit(^batch_size)
      |> Repo.all()

    case recordings do
      [] ->
        :ok

      _ ->
        Enum.each(recordings, &expire_recording/1)
        expire_recordings_in_batches(base_query, List.last(recordings).id, batch_size)
    end
  end

  defp expire_recording(recording) do
    if recording.storage_key do
      target_path =
        Path.join([:code.priv_dir(:backend), "static", "uploads", recording.storage_key])

      _ = File.rm(target_path)
    end

    changes =
      CallRecording.complete_changeset(recording, %{
        status: "expired",
        file_url: nil,
        file_size_bytes: nil,
        metadata: Map.put(recording.metadata || %{}, "expired_at", DateTime.utc_now(:second))
      })

    case Repo.update(changes) do
      {:ok, updated} ->
        _ =
          Analytics.log_event_for_org(
            updated.organization_id,
            updated.branch_id,
            "recording_expired",
            %{lead_id: updated.lead_id}
          )

        _ =
          Audit.log_system(
            updated.organization_id,
            updated.branch_id,
            "recording.expired",
            %{recording_id: updated.id, lead_id: updated.lead_id}
          )

        :ok

      _ ->
        :error
    end
  end

  defp maybe_put_file_url(recording, attrs) when is_map(attrs) do
    file_url = expected_file_url(recording) || validated_file_url(attrs)

    if is_binary(file_url) do
      Map.put(attrs, "file_url", file_url)
    else
      attrs
    end
  end

  defp expected_file_url(%CallRecording{storage_key: key}) when is_binary(key) and key != "" do
    "/uploads/#{key}"
  end

  defp expected_file_url(_), do: nil

  defp validated_file_url(attrs) do
    file_url = Map.get(attrs, "file_url") || Map.get(attrs, :file_url)

    if is_binary(file_url) and String.starts_with?(file_url, "/uploads/") do
      file_url
    else
      nil
    end
  end
end
