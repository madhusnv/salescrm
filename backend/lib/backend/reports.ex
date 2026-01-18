defmodule Backend.Reports do
  @moduledoc """
  Context module for generating counselor reports and analytics.
  """
  import Ecto.Query, warn: false

  alias Backend.Accounts.{Scope, User}
  alias Backend.Access
  alias Backend.Calls.CallLog
  alias Backend.Leads.Lead
  alias Backend.Recordings.CallRecording
  alias Backend.Repo

  @doc """
  Lists counselors with their stats for the given date range.
  Super Admins see all counselors in the organization.
  Branch Managers see only counselors in their branch.
  """
  def list_counselor_stats(%Scope{} = scope, date_range) do
    user = scope.user
    {start_date, end_date} = date_range

    counselors = list_accessible_counselors(user)

    Enum.map(counselors, fn counselor ->
      stats = get_counselor_stats(counselor, start_date, end_date)
      Map.put(counselor, :stats, stats)
    end)
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
    |> order_by([l], desc: coalesce(l.last_activity_at, l.inserted_at))
    |> limit(^limit)
    |> preload([:university, :branch])
    |> Repo.all()
  end

  @doc """
  Lists call logs for a lead with recordings preloaded.
  """
  def list_lead_calls_with_recordings(lead_id) do
    CallLog
    |> where([c], c.lead_id == ^lead_id)
    |> order_by([c], desc: c.started_at)
    |> Repo.all()
    |> Enum.map(fn call ->
      recording =
        CallRecording
        |> where([r], r.call_log_id == ^call.id and r.status == :uploaded)
        |> limit(1)
        |> Repo.one()

      Map.put(call, :recording, recording)
    end)
  end

  @doc """
  Gets the playback URL for a recording.
  """
  def get_recording_url(%CallRecording{storage_key: key}) when is_binary(key) do
    {:ok, "/uploads/#{key}"}
  end

  def get_recording_url(_), do: {:error, :no_file}

  defp list_accessible_counselors(user) do
    User
    |> where([u], u.organization_id == ^user.organization_id and u.is_active == true)
    |> join(:inner, [u], r in assoc(u, :role))
    |> where([_u, r], r.name == "Counselor")
    |> maybe_filter_by_branch(user)
    |> order_by([u], asc: u.full_name)
    |> preload(:role)
    |> Repo.all()
  end

  defp maybe_filter_by_branch(query, user) do
    cond do
      Access.super_admin?(user) ->
        query

      role_name(user) == "Branch Manager" ->
        where(query, [u], u.branch_id == ^user.branch_id)

      true ->
        where(query, [u], false)
    end
  end

  defp role_name(user) do
    Repo.one(from(r in Backend.Access.Role, where: r.id == ^user.role_id, select: r.name))
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
    today = Date.utc_today()

    case filter do
      "today" ->
        start_dt = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
        end_dt = DateTime.new!(Date.add(today, 1), ~T[00:00:00], "Etc/UTC")
        {start_dt, end_dt}

      "week" ->
        days_since_monday = Date.day_of_week(today) - 1
        start_of_week = Date.add(today, -days_since_monday)
        start_dt = DateTime.new!(start_of_week, ~T[00:00:00], "Etc/UTC")
        end_dt = DateTime.new!(Date.add(today, 1), ~T[00:00:00], "Etc/UTC")
        {start_dt, end_dt}

      "month" ->
        start_of_month = Date.beginning_of_month(today)
        start_dt = DateTime.new!(start_of_month, ~T[00:00:00], "Etc/UTC")
        end_dt = DateTime.new!(Date.add(today, 1), ~T[00:00:00], "Etc/UTC")
        {start_dt, end_dt}

      "custom" when not is_nil(custom_start) and not is_nil(custom_end) ->
        start_dt = DateTime.new!(custom_start, ~T[00:00:00], "Etc/UTC")
        end_dt = DateTime.new!(Date.add(custom_end, 1), ~T[00:00:00], "Etc/UTC")
        {start_dt, end_dt}

      _ ->
        start_dt = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
        end_dt = DateTime.new!(Date.add(today, 1), ~T[00:00:00], "Etc/UTC")
        {start_dt, end_dt}
    end
  end
end
