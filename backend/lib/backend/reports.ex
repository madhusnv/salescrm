defmodule Backend.Reports do
  @moduledoc """
  Context module for generating counselor reports and analytics.
  """
  import Ecto.Query, warn: false

  alias Backend.Accounts.{Scope, User}
  alias Backend.Access.{Permissions, Policy}
  alias Backend.Calls.CallLog
  alias Backend.Leads.Lead
  alias Backend.Recordings.CallRecording
  alias Backend.Repo

  @doc """
  Lists counselors with their stats for the given date range.
  Super Admins see all counselors in the organization.
  Branch Managers see only counselors in their branch.

  Optimized to use 3 aggregate queries instead of N+1 (3 queries per counselor).
  """
  def list_counselor_stats(%Scope{} = scope, date_range) do
    user = scope.user
    {start_date, end_date} = date_range

    counselors = list_accessible_counselors(user)
    counselor_ids = Enum.map(counselors, & &1.id)

    if counselor_ids == [] do
      []
    else
      call_stats = fetch_call_stats_batch(counselor_ids, start_date, end_date)
      leads_counts = fetch_leads_counts_batch(counselor_ids, start_date, end_date)
      recordings_counts = fetch_recordings_counts_batch(counselor_ids, start_date, end_date)

      Enum.map(counselors, fn counselor ->
        cs =
          Map.get(call_stats, counselor.id, %{total_calls: 0, total_duration: 0, avg_duration: 0})

        stats = %{
          total_calls: cs.total_calls || 0,
          total_duration: decimal_to_int(cs.total_duration),
          avg_call_duration: decimal_to_int(cs.avg_duration),
          leads_handled: Map.get(leads_counts, counselor.id, 0),
          recordings_count: Map.get(recordings_counts, counselor.id, 0)
        }

        Map.put(counselor, :stats, stats)
      end)
    end
  end

  defp fetch_call_stats_batch(counselor_ids, start_date, end_date) do
    CallLog
    |> where([c], c.counselor_id in ^counselor_ids)
    |> where([c], c.started_at >= ^start_date and c.started_at < ^end_date)
    |> group_by([c], c.counselor_id)
    |> select([c], {
      c.counselor_id,
      %{
        total_calls: count(c.id),
        total_duration: coalesce(sum(c.duration_seconds), 0),
        avg_duration: coalesce(avg(c.duration_seconds), 0)
      }
    })
    |> Repo.all()
    |> Map.new()
  end

  defp fetch_leads_counts_batch(counselor_ids, start_date, end_date) do
    Lead
    |> where([l], l.assigned_counselor_id in ^counselor_ids)
    |> where([l], is_nil(l.merged_into_lead_id))
    |> where([l], l.last_activity_at >= ^start_date and l.last_activity_at < ^end_date)
    |> group_by([l], l.assigned_counselor_id)
    |> select([l], {l.assigned_counselor_id, count(l.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp fetch_recordings_counts_batch(counselor_ids, start_date, end_date) do
    CallRecording
    |> where([r], r.counselor_id in ^counselor_ids and r.status == :uploaded)
    |> where([r], r.recorded_at >= ^start_date and r.recorded_at < ^end_date)
    |> group_by([r], r.counselor_id)
    |> select([r], {r.counselor_id, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Gets detailed stats for a specific counselor.
  """
  def get_counselor_with_stats(%Scope{} = scope, counselor_id, date_range) do
    user = scope.user
    {start_date, end_date} = date_range

    counselor =
      User
      |> where([u], u.id == ^counselor_id and u.organization_id == ^user.organization_id)
      |> maybe_filter_by_branch(user)
      |> preload(:role)
      |> Repo.one()

    case counselor do
      nil ->
        nil

      counselor ->
        stats = get_counselor_stats(counselor, start_date, end_date)
        Map.put(counselor, :stats, stats)
    end
  end

  @doc """
  Returns call stats for the current counselor in the given date range.
  """
  def counselor_call_stats(%Scope{} = scope, date_range) do
    {start_date, end_date} = date_range
    counselor_id = scope.user.id

    call_type_stats =
      CallLog
      |> where([c], c.counselor_id == ^counselor_id)
      |> where([c], c.started_at >= ^start_date and c.started_at < ^end_date)
      |> group_by([c], c.call_type)
      |> select([c], {
        c.call_type,
        count(c.id),
        coalesce(sum(c.duration_seconds), 0)
      })
      |> Repo.all()

    by_type =
      Enum.reduce(call_type_stats, %{}, fn {call_type, count, duration}, acc ->
        Map.put(acc, call_type, %{
          count: count || 0,
          duration: decimal_to_int(duration)
        })
      end)

    total_calls = Enum.reduce(by_type, 0, fn {_type, stat}, acc -> acc + stat.count end)
    total_duration = Enum.reduce(by_type, 0, fn {_type, stat}, acc -> acc + stat.duration end)

    missed_calls =
      Enum.reduce([:missed, :rejected, :blocked], 0, fn type, acc ->
        acc + Map.get(by_type, type, %{count: 0}).count
      end)

    outgoing_calls = Map.get(by_type, :outgoing, %{count: 0}).count
    incoming_calls = Map.get(by_type, :incoming, %{count: 0}).count

    leads_assigned =
      Lead
      |> where([l], l.assigned_counselor_id == ^counselor_id)
      |> where([l], l.inserted_at >= ^start_date and l.inserted_at < ^end_date)
      |> Repo.aggregate(:count, :id)

    %{
      total_calls: total_calls,
      outgoing_calls: outgoing_calls,
      incoming_calls: incoming_calls,
      missed_calls: missed_calls,
      total_duration_seconds: total_duration,
      leads_assigned: leads_assigned
    }
  end

  @doc """
  Returns a daily total call duration series for the counselor.
  """
  def list_counselor_daily_call_durations(counselor_id, date_range)
      when is_integer(counselor_id) do
    {start_date, end_date} = date_range

    durations =
      CallLog
      |> where([c], c.counselor_id == ^counselor_id)
      |> where([c], c.started_at >= ^start_date and c.started_at < ^end_date)
      |> group_by([c], fragment("date(timezone('Asia/Kolkata', ?))", c.started_at))
      |> select([c], {
        fragment("date(timezone('Asia/Kolkata', ?))", c.started_at),
        coalesce(sum(c.duration_seconds), 0)
      })
      |> Repo.all()
      |> Map.new(fn {date, duration} -> {date, decimal_to_int(duration)} end)

    start_day = DateTime.to_date(start_date)
    end_day = Date.add(DateTime.to_date(end_date), -1)

    start_day
    |> Date.range(end_day)
    |> Enum.map(fn date ->
      %{date: date, total_duration: Map.get(durations, date, 0)}
    end)
  end

  @doc """
  Lists leads for a counselor with optional search filter.
  """
  def list_counselor_leads(%Scope{} = scope, counselor_id, opts \\ []) do
    user = scope.user
    search = Keyword.get(opts, :search, "")
    limit = Keyword.get(opts, :limit, 50)

    Lead
    |> where([l], l.assigned_counselor_id == ^counselor_id)
    |> where([l], l.organization_id == ^user.organization_id)
    |> where([l], is_nil(l.merged_into_lead_id))
    |> maybe_search_leads(search)
    |> order_by([l], desc: l.last_activity_at, desc: l.id)
    |> limit(^limit)
    |> preload([:university, :branch])
    |> Repo.all()
  end

  @doc """
  Lists call logs for a lead with recordings preloaded.

  Optimized: uses a single query with LEFT JOIN instead of N+1 queries.
  """
  def list_lead_calls_with_recordings(lead_id) do
    calls =
      CallLog
      |> where([c], c.lead_id == ^lead_id)
      |> order_by([c], desc: c.started_at)
      |> Repo.all()

    if calls == [] do
      []
    else
      call_ids = Enum.map(calls, & &1.id)

      recordings =
        CallRecording
        |> where([r], r.call_log_id in ^call_ids and r.status == :uploaded)
        |> Repo.all()
        |> Map.new(&{&1.call_log_id, &1})

      Enum.map(calls, fn call ->
        Map.put(call, :recording, Map.get(recordings, call.id))
      end)
    end
  end

  @doc """
  Gets the playback URL for a recording.
  """
  def get_recording_url(%CallRecording{storage_key: key}) when is_binary(key) do
    {:ok, "/uploads/#{key}"}
  end

  def get_recording_url(_), do: {:error, :no_file}

  defp list_accessible_counselors(user) do
    counselor_role_ids = get_counselor_role_ids(user.organization_id)

    User
    |> where([u], u.organization_id == ^user.organization_id and u.is_active == true)
    |> where([u], u.role_id in ^counselor_role_ids)
    |> maybe_filter_by_branch(user)
    |> order_by([u], asc: u.full_name)
    |> preload(:role)
    |> Repo.all()
  end

  defp get_counselor_role_ids(organization_id) do
    exclude_role_ids =
      from(rp in Backend.Access.RolePermission,
        join: p in Backend.Access.Permission,
        on: p.id == rp.permission_id,
        join: r in Backend.Access.Role,
        on: r.id == rp.role_id,
        where: r.organization_id == ^organization_id,
        where: p.key in ^[Permissions.leads_read_all(), Permissions.leads_read_branch()],
        select: rp.role_id
      )

    Backend.Access.Role
    |> where([r], r.organization_id == ^organization_id)
    |> join(:inner, [r], rp in Backend.Access.RolePermission, on: rp.role_id == r.id)
    |> join(:inner, [_r, rp], p in Backend.Access.Permission, on: p.id == rp.permission_id)
    |> where([_r, _rp, p], p.key == ^Permissions.leads_read_own())
    |> where([r], r.id not in subquery(exclude_role_ids))
    |> select([r], r.id)
    |> Repo.all()
  end

  defp maybe_filter_by_branch(query, %Scope{} = scope) do
    case Policy.lead_access_level(scope) do
      :organization ->
        query

      :branch ->
        where(query, [u], u.branch_id == ^scope.branch_id)

      :own ->
        where(query, [u], false)
    end
  end

  defp maybe_filter_by_branch(query, %User{} = user) do
    scope = Scope.for_user(user)
    maybe_filter_by_branch(query, scope)
  end

  defp get_counselor_stats(counselor, start_date, end_date) do
    call_stats =
      CallLog
      |> where([c], c.counselor_id == ^counselor.id)
      |> where([c], c.started_at >= ^start_date and c.started_at < ^end_date)
      |> select([c], %{
        total_calls: count(c.id),
        total_duration: coalesce(sum(c.duration_seconds), 0),
        avg_duration: coalesce(avg(c.duration_seconds), 0)
      })
      |> Repo.one()

    leads_count =
      Lead
      |> where([l], l.assigned_counselor_id == ^counselor.id)
      |> where([l], is_nil(l.merged_into_lead_id))
      |> where([l], l.last_activity_at >= ^start_date and l.last_activity_at < ^end_date)
      |> Repo.aggregate(:count, :id)

    recordings_count =
      CallRecording
      |> where([r], r.counselor_id == ^counselor.id and r.status == :uploaded)
      |> where([r], r.recorded_at >= ^start_date and r.recorded_at < ^end_date)
      |> Repo.aggregate(:count, :id)

    %{
      total_calls: call_stats.total_calls || 0,
      leads_handled: leads_count,
      avg_call_duration: decimal_to_int(call_stats.avg_duration),
      recordings_count: recordings_count,
      total_duration: decimal_to_int(call_stats.total_duration)
    }
  end

  defp decimal_to_int(nil), do: 0
  defp decimal_to_int(%Decimal{} = d), do: d |> Decimal.round() |> Decimal.to_integer()
  defp decimal_to_int(val) when is_integer(val), do: val
  defp decimal_to_int(val) when is_float(val), do: round(val)

  defp maybe_search_leads(query, search) when is_binary(search) and search != "" do
    like = "%#{search}%"

    where(
      query,
      [l],
      ilike(l.student_name, ^like) or ilike(l.phone_number, ^like)
    )
  end

  defp maybe_search_leads(query, _), do: query

  @doc """
  Returns date range based on filter type.
  """
  def date_range_for_filter(filter, custom_start \\ nil, custom_end \\ nil) do
    today = ist_now() |> DateTime.to_date()

    case filter do
      "today" ->
        start_dt = ist_midnight_to_utc(today)
        end_dt = ist_midnight_to_utc(Date.add(today, 1))
        {start_dt, end_dt}

      "week" ->
        days_since_monday = Date.day_of_week(today) - 1
        start_of_week = Date.add(today, -days_since_monday)
        start_dt = ist_midnight_to_utc(start_of_week)
        end_dt = ist_midnight_to_utc(Date.add(today, 1))
        {start_dt, end_dt}

      "month" ->
        start_of_month = Date.beginning_of_month(today)
        start_dt = ist_midnight_to_utc(start_of_month)
        end_dt = ist_midnight_to_utc(Date.add(today, 1))
        {start_dt, end_dt}

      "custom" when not is_nil(custom_start) and not is_nil(custom_end) ->
        start_dt = ist_midnight_to_utc(custom_start)
        end_dt = ist_midnight_to_utc(Date.add(custom_end, 1))
        {start_dt, end_dt}

      _ ->
        start_dt = ist_midnight_to_utc(today)
        end_dt = ist_midnight_to_utc(Date.add(today, 1))
        {start_dt, end_dt}
    end
  end

  @ist_offset_seconds 19_800

  defp ist_now do
    DateTime.add(DateTime.utc_now(), @ist_offset_seconds, :second)
  end

  defp ist_midnight_to_utc(%Date{} = date) do
    date
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    |> DateTime.add(-@ist_offset_seconds, :second)
  end
end
