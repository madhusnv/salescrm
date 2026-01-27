defmodule BackendWeb.Api.LeadController do
  use BackendWeb, :controller

  plug(
    BackendWeb.Plugs.RequirePermission,
    Backend.Access.Policy.lead_read_permissions()
    when action in [:index, :show]
  )

  plug(
    BackendWeb.Plugs.RequirePermission,
    Backend.Access.Permissions.leads_update()
    when action in [:create, :update_status, :add_note, :schedule_followup]
  )

  alias Backend.Access.Policy
  alias Backend.Calls
  alias Backend.Leads
  alias Backend.Organizations
  alias Backend.Recordings

  def index(conn, params) do
    scope = conn.assigns.current_scope
    page = parse_int(Map.get(params, "page", "1"), 1)
    page_size = parse_int(Map.get(params, "page_size", "20"), 20)

    filters =
      Map.take(params, [
        "status",
        "search",
        "counselor_id",
        "include_merged",
        "university_id",
        "activity_filter",
        "followup_filter"
      ])

    leads = Leads.list_leads(scope, filters, page, page_size)
    total_count = Leads.count_leads(scope, filters)

    json(conn, %{
      data: Enum.map(leads, &render_lead/1),
      meta: %{
        page: page,
        page_size: page_size,
        total_count: total_count
      }
    })
  end

  def create(conn, params) do
    scope = conn.assigns.current_scope

    attrs = %{
      "student_name" => Map.get(params, "student_name") || "Unknown Lead",
      "phone_number" => Map.get(params, "phone_number"),
      "source" => Map.get(params, "source", "android"),
      "university_id" => resolve_university_id(scope, Map.get(params, "university_id"))
    }

    case Leads.create_lead(scope, attrs) do
      {:ok, lead} ->
        json(conn, %{data: render_lead(lead)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_on(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    lead = Leads.get_lead!(scope, id)

    recordings =
      if Policy.can_access_recordings?(scope) do
        Recordings.list_recordings_for_lead(scope, lead.id)
      else
        []
      end

    json(conn, %{
      data: %{
        lead: render_lead(lead),
        activities: Enum.map(Leads.list_activities(lead), &render_activity/1),
        followups: Enum.map(Leads.list_followups(lead), &render_followup/1),
        call_logs: Enum.map(Calls.list_call_logs_for_lead(scope, lead.id), &render_call_log/1),
        recordings: Enum.map(recordings, &render_recording/1)
      }
    })
  end

  def update_status(conn, %{"id" => id, "status" => status}) do
    scope = conn.assigns.current_scope
    lead = Leads.get_lead!(scope, id)

    case Leads.update_lead_status(scope, lead, status) do
      {:ok, {lead, activity}} ->
        json(conn, %{data: %{lead: render_lead(lead), activity: render_activity(activity)}})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "status_update_failed", details: inspect(reason)})
    end
  end

  def add_note(conn, %{"id" => id, "body" => body}) do
    scope = conn.assigns.current_scope
    lead = Leads.get_lead!(scope, id)

    case Leads.add_note(scope, lead, body) do
      {:ok, {lead, activity}} ->
        json(conn, %{data: %{lead: render_lead(lead), activity: render_activity(activity)}})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "note_failed", details: inspect(reason)})
    end
  end

  def schedule_followup(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    lead = Leads.get_lead!(scope, id)

    with {:ok, due_at} <- parse_datetime(Map.get(params, "due_at")),
         {:ok, {lead, followup, activity}} <-
           Leads.schedule_followup(scope, lead, %{
             due_at: due_at,
             note: Map.get(params, "note")
           }) do
      json(conn, %{
        data: %{
          lead: render_lead(lead),
          followup: render_followup(followup),
          activity: render_activity(activity)
        }
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "followup_failed", details: inspect(reason)})
    end
  end

  defp parse_datetime(nil), do: {:error, :missing_due_at}
  defp parse_datetime(""), do: {:error, :missing_due_at}

  defp parse_datetime(value) when is_integer(value) do
    DateTime.from_unix(value, :second)
  end

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _} -> {:error, :invalid_datetime}
    end
  end

  defp parse_datetime(_), do: {:error, :invalid_datetime}

  defp parse_int(value, default) do
    case Integer.parse(to_string(value)) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp resolve_university_id(scope, university_id) when is_binary(university_id) do
    case Integer.parse(university_id) do
      {id, _} -> id
      :error -> resolve_university_id(scope, nil)
    end
  end

  defp resolve_university_id(_scope, university_id) when is_integer(university_id) do
    university_id
  end

  defp resolve_university_id(scope, _university_id) do
    case Organizations.list_universities(scope.user.organization_id) do
      [first | _] -> first.id
      [] -> nil
    end
  end

  defp render_lead(lead) do
    %{
      id: lead.id,
      student_name: lead.student_name,
      phone_number: lead.phone_number,
      status: lead.status,
      source: lead.source,
      last_activity_at: format_datetime(lead.last_activity_at),
      next_follow_up_at: format_datetime(lead.next_follow_up_at),
      branch: render_branch(lead.branch),
      university: render_university(lead.university),
      assigned_counselor: render_user(lead.assigned_counselor)
    }
  end

  defp render_activity(activity) do
    %{
      id: activity.id,
      activity_type: activity.activity_type,
      body: activity.body,
      metadata: activity.metadata,
      occurred_at: format_datetime(activity.occurred_at),
      user: render_user(activity.user)
    }
  end

  defp render_followup(followup) do
    %{
      id: followup.id,
      due_at: format_datetime(followup.due_at),
      completed_at: format_datetime(followup.completed_at),
      status: followup.status,
      note: followup.note,
      user: render_user(followup.user)
    }
  end

  defp render_call_log(call_log) do
    %{
      id: call_log.id,
      call_type: call_log.call_type,
      phone_number: call_log.phone_number,
      started_at: format_datetime(call_log.started_at),
      ended_at: format_datetime(call_log.ended_at),
      duration_seconds: call_log.duration_seconds,
      metadata: call_log.metadata
    }
  end

  defp render_recording(recording) do
    %{
      id: recording.id,
      status: recording.status,
      file_url: recording.file_url,
      duration_seconds: recording.duration_seconds,
      recorded_at: format_datetime(recording.recorded_at)
    }
  end

  defp render_branch(nil), do: nil
  defp render_branch(branch), do: %{id: branch.id, name: branch.name}

  defp render_university(nil), do: nil
  defp render_university(university), do: %{id: university.id, name: university.name}

  defp render_user(nil), do: nil

  defp render_user(user) do
    %{
      id: user.id,
      full_name: user.full_name,
      email: user.email
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> to_ist()
    |> DateTime.to_iso8601()
  end

  defp to_ist(%DateTime{} = datetime) do
    DateTime.add(datetime, 19_800, :second)
  end
end
