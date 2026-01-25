defmodule Backend.Analytics do
  import Ecto.Query, warn: false

  alias Backend.Accounts.Scope
  alias Backend.Analytics.{AnalyticsDailyStat, AnalyticsEvent}
  alias Backend.Repo

  @default_metrics ~w(
    lead_created
    lead_status_updated
    followup_scheduled
    call_logged
    recording_uploaded
    consent_captured
  )

  def log_event(%Scope{} = scope, event_type, metadata \\ %{}) when is_binary(event_type) do
    attrs = %{
      organization_id: scope.user.organization_id,
      branch_id: scope.user.branch_id,
      user_id: scope.user.id,
      lead_id: Map.get(metadata, :lead_id) || Map.get(metadata, "lead_id"),
      event_type: event_type,
      occurred_at: DateTime.utc_now(:second),
      metadata: Map.drop(metadata, [:lead_id, "lead_id"])
    }

    %AnalyticsEvent{}
    |> AnalyticsEvent.changeset(attrs)
    |> Repo.insert()
  end

  def log_event_for_org(organization_id, branch_id, event_type, metadata \\ %{})
      when is_binary(event_type) do
    attrs = %{
      organization_id: organization_id,
      branch_id: branch_id,
      user_id: Map.get(metadata, :user_id) || Map.get(metadata, "user_id"),
      lead_id: Map.get(metadata, :lead_id) || Map.get(metadata, "lead_id"),
      event_type: event_type,
      occurred_at: DateTime.utc_now(:second),
      metadata: Map.drop(metadata, [:lead_id, "lead_id", :user_id, "user_id"])
    }

    %AnalyticsEvent{}
    |> AnalyticsEvent.changeset(attrs)
    |> Repo.insert()
  end

  def rollup_daily(%Date{} = date) do
    day_start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    day_end = DateTime.add(day_start, 86_400, :second)

    events =
      AnalyticsEvent
      |> where([e], e.occurred_at >= ^day_start and e.occurred_at < ^day_end)
      |> select([e], %{
        organization_id: e.organization_id,
        branch_id: e.branch_id,
        metric: e.event_type,
        value: count(e.id)
      })
      |> group_by([e], [e.organization_id, e.branch_id, e.event_type])
      |> Repo.all()

    entries =
      Enum.map(events, fn event ->
        %{
          organization_id: event.organization_id,
          branch_id: event.branch_id,
          metric: event.metric,
          stat_date: date,
          value: event.value,
          inserted_at: DateTime.utc_now(:second),
          updated_at: DateTime.utc_now(:second)
        }
      end)

    Repo.insert_all(AnalyticsDailyStat, entries,
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: [:organization_id, :branch_id, :metric, :stat_date]
    )
  end

  def list_daily_stats(%Scope{} = scope, %Date{} = from_date, %Date{} = to_date) do
    AnalyticsDailyStat
    |> where([s], s.organization_id == ^scope.user.organization_id)
    |> where([s], s.stat_date >= ^from_date and s.stat_date <= ^to_date)
    |> Repo.all()
  end

  def dashboard_metrics(%Scope{} = scope, %Date{} = date, opts \\ []) do
    branch_scoped = Keyword.get(opts, :branch_scoped, true)

    stats =
      AnalyticsDailyStat
      |> where([s], s.organization_id == ^scope.user.organization_id)
      |> maybe_scope_branch(scope, branch_scoped)
      |> where([s], s.stat_date == ^date)
      |> Repo.all()

    metrics_from_stats =
      Map.new(@default_metrics, fn metric ->
        {metric, sum_metric(stats, metric)}
      end)

    if Enum.all?(metrics_from_stats, fn {_key, value} -> value == 0 end) do
      rollup_from_events(scope, date, branch_scoped)
    else
      metrics_from_stats
    end
  end

  defp maybe_scope_branch(query, %Scope{user: %{branch_id: branch_id}}, true) do
    where(query, [s], s.branch_id == ^branch_id)
  end

  defp maybe_scope_branch(query, _scope, false), do: query

  defp sum_metric(stats, metric) do
    stats
    |> Enum.filter(&(&1.metric == metric))
    |> Enum.reduce(0, fn stat, acc -> acc + (stat.value || 0) end)
  end

  defp rollup_from_events(%Scope{} = scope, %Date{} = date, branch_scoped) do
    day_start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    day_end = DateTime.add(day_start, 86_400, :second)

    event_counts =
      AnalyticsEvent
      |> where([e], e.organization_id == ^scope.user.organization_id)
      |> maybe_scope_event_branch(scope, branch_scoped)
      |> where([e], e.occurred_at >= ^day_start and e.occurred_at < ^day_end)
      |> group_by([e], e.event_type)
      |> select([e], {e.event_type, count(e.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@default_metrics, fn metric ->
      {metric, Map.get(event_counts, metric, 0)}
    end)
  end

  defp maybe_scope_event_branch(query, %Scope{user: %{branch_id: branch_id}}, true) do
    where(query, [e], e.branch_id == ^branch_id)
  end

  defp maybe_scope_event_branch(query, _scope, false), do: query
end
