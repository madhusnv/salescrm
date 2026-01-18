defmodule BackendWeb.Broadcaster do
  @moduledoc """
  Broadcasts events to connected WebSocket clients.
  """

  alias BackendWeb.Endpoint

  def broadcast_to_user(user_id, event, payload) do
    Endpoint.broadcast("user:#{user_id}", event, payload)
  end

  def broadcast_lead_updated(user_id, lead) do
    broadcast_to_user(user_id, "lead:updated", %{
      id: lead.id,
      student_name: lead.student_name,
      phone_number: lead.phone_number,
      status: to_string(lead.status)
    })
  end

  def broadcast_call_synced(user_id, call_log) do
    broadcast_to_user(user_id, "call:synced", %{
      id: call_log.id,
      phone_number: call_log.phone_number,
      call_type: to_string(call_log.call_type),
      duration_seconds: call_log.duration_seconds
    })
  end

  def broadcast_lead_assigned(user_id, lead) do
    broadcast_to_user(user_id, "lead:assigned", %{
      id: lead.id,
      student_name: lead.student_name,
      phone_number: lead.phone_number
    })
  end

  def broadcast_stats_updated(user_id, stats) do
    broadcast_to_user(user_id, "stats:updated", stats)
  end

  def broadcast_recording_uploaded(user_id, recording) do
    broadcast_to_user(user_id, "recording:uploaded", %{
      id: recording.id,
      lead_id: recording.lead_id,
      status: to_string(recording.status),
      duration_seconds: recording.duration_seconds,
      file_url: recording.file_url
    })
  end

  def broadcast_recording_status(user_id, recording_id, status) do
    broadcast_to_user(user_id, "recording:status", %{
      id: recording_id,
      status: status
    })
  end
end
