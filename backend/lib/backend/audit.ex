defmodule Backend.Audit do
  import Ecto.Query, warn: false

  alias Backend.Accounts.Scope
  alias Backend.Audit.AuditLog
  alias Backend.Repo

  def log(%Scope{} = scope, action, attrs \\ %{}) when is_binary(action) do
    data = %{
      organization_id: scope.user.organization_id,
      branch_id: scope.user.branch_id,
      user_id: scope.user.id,
      lead_id: Map.get(attrs, :lead_id) || Map.get(attrs, "lead_id"),
      recording_id: Map.get(attrs, :recording_id) || Map.get(attrs, "recording_id"),
      action: action,
      metadata: Map.drop(attrs, [:lead_id, "lead_id", :recording_id, "recording_id"])
    }

    %AuditLog{}
    |> AuditLog.changeset(data)
    |> Repo.insert()
  end

  def log_system(organization_id, branch_id, action, attrs \\ %{}) when is_binary(action) do
    data = %{
      organization_id: organization_id,
      branch_id: branch_id,
      user_id: Map.get(attrs, :user_id) || Map.get(attrs, "user_id"),
      lead_id: Map.get(attrs, :lead_id) || Map.get(attrs, "lead_id"),
      recording_id: Map.get(attrs, :recording_id) || Map.get(attrs, "recording_id"),
      action: action,
      metadata:
        Map.drop(attrs, [:lead_id, "lead_id", :recording_id, "recording_id", :user_id, "user_id"])
    }

    %AuditLog{}
    |> AuditLog.changeset(data)
    |> Repo.insert()
  end

  def list_recent(%Scope{} = scope, limit \\ 20) do
    AuditLog
    |> where([a], a.organization_id == ^scope.user.organization_id)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_entries(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    AuditLog
    |> where([a], a.organization_id == ^scope.user.organization_id)
    |> join(:left, [a], u in assoc(a, :user))
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> select([a, u], %{
      id: a.id,
      action: a.action,
      user_email: u.email,
      resource_id: coalesce(a.lead_id, a.recording_id),
      metadata: a.metadata,
      inserted_at: a.inserted_at
    })
    |> Repo.all()
    |> Enum.map(fn entry ->
      Map.put(entry, :resource_type, parse_resource_type(entry.action))
    end)
  end

  defp parse_resource_type(action) when is_binary(action) do
    case String.split(action, ".") do
      [resource | _] -> resource
      _ -> "unknown"
    end
  end
end
