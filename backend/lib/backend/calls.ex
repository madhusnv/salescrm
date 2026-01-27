defmodule Backend.Calls do
  import Ecto.Query, warn: false

  alias Backend.Accounts.Scope
  alias Backend.Analytics
  alias Backend.Calls.CallLog
  alias Backend.Leads
  alias Backend.Leads.Lead
  alias Backend.Repo
  alias BackendWeb.Broadcaster

  def list_call_logs_for_lead(%Scope{} = scope, lead_id, limit \\ 20, offset \\ 0) do
    _lead = Leads.get_lead!(scope, lead_id)

    CallLog
    |> where([c], c.lead_id == ^lead_id and c.organization_id == ^scope.user.organization_id)
    |> order_by([c], desc: c.started_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def list_call_logs_for_user(%Scope{} = scope, limit \\ 50) do
    CallLog
    |> where([c], c.counselor_id == ^scope.user.id)
    |> order_by([c], desc: c.started_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_call_log_by_device_id(organization_id, counselor_id, device_call_id) do
    Repo.get_by(CallLog,
      organization_id: organization_id,
      counselor_id: counselor_id,
      device_call_id: device_call_id
    )
  end

  def create_call_log(%Scope{} = scope, attrs) when is_map(attrs) do
    user = scope.user

    normalized_phone =
      Leads.normalize_phone(Map.get(attrs, "phone_number") || Map.get(attrs, :phone_number))

    if is_nil(normalized_phone) or normalized_phone == "" do
      {:error, :invalid_phone}
    else
      device_call_id =
        Map.get(attrs, "device_call_id") || Map.get(attrs, :device_call_id) || ""

      case get_call_log_by_device_id(user.organization_id, user.id, device_call_id) do
        %CallLog{} = existing ->
          {:ok, existing, :duplicate}

        nil ->
          lead =
            Leads.get_lead_by_phone(scope, normalized_phone)

          if is_nil(lead) do
            {:ok, :ignored}
          else
            data =
              attrs
              |> Map.put("organization_id", user.organization_id)
              |> Map.put("branch_id", user.branch_id)
              |> Map.put("counselor_id", user.id)
              |> Map.put("lead_id", lead.id)
              |> Map.put("normalized_phone_number", normalized_phone)
              |> Map.put_new("consent_granted", false)

            %CallLog{}
            |> CallLog.changeset(data)
            |> Repo.insert()
            |> case do
              {:ok, call_log} ->
                _ = Analytics.log_event(scope, "call_logged", %{lead_id: call_log.lead_id})

                if call_log.consent_granted do
                  _ = Analytics.log_event(scope, "consent_captured", %{lead_id: call_log.lead_id})
                end

                _ = maybe_mark_lead_contacted(scope, lead, call_log)
                _ = Broadcaster.broadcast_call_synced(scope.user.id, call_log)

                {:ok, call_log, :created}

              {:error, changeset} ->
                {:error, changeset}
            end
          end
      end
    end
  end

  defp maybe_mark_lead_contacted(%Scope{} = scope, %Lead{} = lead, %CallLog{} = call_log) do
    if should_mark_contacted?(lead, call_log) do
      case Leads.update_lead_status(scope, lead, :contacted) do
        {:ok, _} -> :ok
        {:error, _reason} -> :error
      end
    else
      :noop
    end
  end

  defp maybe_mark_lead_contacted(_scope, _lead, _call_log), do: :noop

  defp should_mark_contacted?(%Lead{} = lead, %CallLog{} = call_log) do
    lead.status == :new and
      call_log.call_type in [:incoming, :outgoing] and
      (call_log.duration_seconds || 0) >= 10
  end
end
