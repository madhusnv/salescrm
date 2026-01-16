defmodule Backend.Recordings do
  import Ecto.Query, warn: false

  alias Backend.Accounts.Scope
  alias Backend.Audit
  alias Backend.Analytics
  alias Backend.Recordings.CallRecording
  alias Backend.Repo

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

    if recording.organization_id != scope.user.organization_id do
      {:error, :forbidden}
    else
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
    # For local file storage, return the static path
    if recording.storage_key do
      url = "/uploads/#{recording.storage_key}"
      {:ok, url}
    else
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

    CallRecording
    |> where([r], r.recorded_at < ^cutoff and r.status == :uploaded)
    |> Repo.all()
    |> Enum.each(fn recording ->
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
    end)
  end
end
