defmodule BackendWeb.LeadShowLive do
  use BackendWeb, :live_view

  alias Backend.Access
  alias Backend.Leads
  alias Backend.Leads.{Lead, LeadFollowup}
  alias Backend.Recordings
  alias Backend.Repo

  on_mount({BackendWeb.RequirePermissionOnMount, "lead.read"})

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:lead, nil)
     |> assign(:status_options, status_options())
     |> assign(:status_form, to_form(%{"status" => "new"}, as: :lead))
     |> assign(:note_form, to_form(%{"body" => ""}, as: :note))
     |> assign(:followup_form, to_form(%{"due_at" => "", "note" => ""}, as: :followup))
     |> assign(:can_update, can_update?(socket))
     |> assign(:can_read_recordings, can_read_recordings?(socket))
     |> stream(:activities, [])
     |> stream(:followups, [])
     |> stream(:recordings, [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    lead = Leads.get_lead!(socket.assigns.current_scope, id)

    activities = Leads.list_activities(lead)
    followups = Leads.list_followups(lead)

    recordings =
      if socket.assigns.can_read_recordings do
        Recordings.list_recordings_for_lead(socket.assigns.current_scope, lead.id)
      else
        []
      end

    socket =
      socket
      |> assign(:lead, lead)
      |> assign(:status_form, to_form(%{"status" => to_string(lead.status)}, as: :lead))
      |> stream(:activities, activities, reset: true)
      |> stream(:followups, followups, reset: true)
      |> stream(:recordings, recordings, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_status", %{"lead" => %{"status" => status}}, socket) do
    lead = socket.assigns.lead
    scope = socket.assigns.current_scope

    if socket.assigns.can_update do
      case Leads.update_lead_status(scope, lead, status) do
        {:ok, {lead, _activity}} ->
          {:noreply, refresh_lead(socket, lead)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Unable to update status: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to update this lead.")}
    end
  end

  def handle_event("add_note", %{"note" => %{"body" => body}}, socket) do
    lead = socket.assigns.lead
    scope = socket.assigns.current_scope
    trimmed_body = String.trim(body)

    if !socket.assigns.can_update do
      {:noreply, put_flash(socket, :error, "You do not have permission to update this lead.")}
    else
      if trimmed_body == "" do
        {:noreply, put_flash(socket, :error, "Note cannot be empty.")}
      else
        case Leads.add_note(scope, lead, trimmed_body) do
          {:ok, {lead, _activity}} ->
            {:noreply,
             socket
             |> refresh_lead(lead)
             |> assign(:note_form, to_form(%{"body" => ""}, as: :note))}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Unable to add note: #{inspect(reason)}")}
        end
      end
    end
  end

  def handle_event("schedule_followup", %{"followup" => followup_params}, socket) do
    lead = socket.assigns.lead
    scope = socket.assigns.current_scope

    if socket.assigns.can_update do
      with {:ok, due_at} <- parse_due_at(followup_params["due_at"]),
           {:ok, {lead, _followup, _activity}} <-
             Leads.schedule_followup(scope, lead, %{
               due_at: due_at,
               note: followup_params["note"]
             }) do
        {:noreply,
         socket
         |> refresh_lead(lead)
         |> assign(:followup_form, to_form(%{"due_at" => "", "note" => ""}, as: :followup))}
      else
        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "Unable to schedule follow-up: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to update this lead.")}
    end
  end

  def handle_event("complete_followup", %{"id" => id}, socket) do
    followup =
      LeadFollowup
      |> Repo.get_by!(id: id, lead_id: socket.assigns.lead.id)

    if socket.assigns.can_update do
      case Leads.complete_followup(socket.assigns.current_scope, followup) do
        {:ok, {lead, _followup, _activity}} ->
          {:noreply, refresh_lead(socket, lead)}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "Unable to complete follow-up: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to update this lead.")}
    end
  end

  defp refresh_lead(socket, lead) do
    lead = Leads.get_lead!(socket.assigns.current_scope, lead.id)
    activities = Leads.list_activities(lead)
    followups = Leads.list_followups(lead)

    recordings =
      if socket.assigns.can_read_recordings do
        Recordings.list_recordings_for_lead(socket.assigns.current_scope, lead.id)
      else
        []
      end

    socket
    |> assign(:lead, lead)
    |> assign(:status_form, to_form(%{"status" => to_string(lead.status)}, as: :lead))
    |> stream(:activities, activities, reset: true)
    |> stream(:followups, followups, reset: true)
    |> stream(:recordings, recordings, reset: true)
  end

  defp parse_due_at(nil), do: {:error, :missing_due_at}
  defp parse_due_at(""), do: {:error, :missing_due_at}

  defp parse_due_at(due_at) when is_binary(due_at) do
    case NaiveDateTime.from_iso8601(due_at) do
      {:ok, naive} ->
        {:ok,
         naive
         |> DateTime.from_naive!("Asia/Kolkata")
         |> DateTime.shift_zone!("Etc/UTC")}

      {:error, _} ->
        {:error, :invalid_datetime}
    end
  end

  defp status_options do
    Enum.map(Lead.statuses(), &{humanize_status(&1), Atom.to_string(&1)})
  end

  defp humanize_status(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp can_update?(socket) do
    user = socket.assigns.current_scope.user
    Access.role_has_permission?(user, "lead.update")
  end

  defp can_read_recordings?(socket) do
    user = socket.assigns.current_scope.user
    Access.role_has_permission?(user, "recording.read")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-6">
        <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
              <h1 class="text-3xl font-semibold text-slate-900">{@lead.student_name}</h1>
              <p class="mt-2 text-sm text-slate-500">
                {@lead.phone_number} · {@lead.university && @lead.university.name}
              </p>
            </div>
            <div class="flex items-center gap-3">
              <span class="rounded-full bg-slate-100 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-slate-600">
                {humanize_status(@lead.status)}
              </span>
              <div class="text-right text-sm text-slate-500">
                <div>Assigned to</div>
                <div class="font-semibold text-slate-900">
                  {@lead.assigned_counselor && @lead.assigned_counselor.full_name}
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 grid gap-4 md:grid-cols-2">
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Branch</p>
              <p class="mt-2 text-sm text-slate-800">
                {@lead.branch && @lead.branch.name}
              </p>
            </div>
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Next follow-up
              </p>
              <p class="mt-2 text-sm text-slate-800">
                {format_datetime(@lead.next_follow_up_at) || "Not scheduled"}
              </p>
            </div>
          </div>
        </div>

        <div class="grid gap-6 lg:grid-cols-[1.2fr_1fr]">
          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-slate-900">Timeline</h2>
            </div>
            <div id="lead-activities" phx-update="stream" class="mt-6 space-y-4">
              <div class="hidden text-sm text-slate-500 only:block">No activity yet.</div>
              <div
                :for={{id, activity} <- @streams.activities}
                id={id}
                class="rounded-2xl border border-slate-200 bg-slate-50 p-4"
              >
                <div class="flex items-center justify-between text-xs text-slate-500">
                  <span class="font-semibold uppercase tracking-wide">
                    {humanize_activity(activity.activity_type)}
                  </span>
                  <span>{format_datetime(activity.occurred_at)}</span>
                </div>
                <p class="mt-2 text-sm text-slate-800">{activity.body}</p>
                <p class="mt-2 text-xs text-slate-500">
                  by {activity.user && activity.user.full_name}
                </p>
              </div>
            </div>
          </div>

          <div class="space-y-6">
            <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Update status</h2>
              <.form
                :if={@can_update}
                for={@status_form}
                id="lead-status-form"
                phx-submit="update_status"
                class="mt-4 flex items-end gap-3"
              >
                <.input field={@status_form[:status]} type="select" options={@status_options} />
                <button
                  type="submit"
                  class="inline-flex h-11 items-center rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Save
                </button>
              </.form>
              <p :if={!@can_update} class="mt-4 text-sm text-slate-500">
                You do not have permission to update this lead.
              </p>
            </div>

            <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Add a note</h2>
              <.form
                :if={@can_update}
                for={@note_form}
                id="lead-note-form"
                phx-submit="add_note"
                class="mt-4 space-y-3"
              >
                <.input
                  field={@note_form[:body]}
                  type="textarea"
                  placeholder="Write a quick update..."
                />
                <button
                  type="submit"
                  class="inline-flex h-11 items-center rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Add note
                </button>
              </.form>
            </div>

            <div
              :if={@can_read_recordings}
              class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm"
            >
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-slate-900">Recordings</h2>
                <span class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Secure
                </span>
              </div>
              <div id="lead-recordings" phx-update="stream" class="mt-4 space-y-4">
                <div class="hidden text-sm text-slate-500 only:block">No recordings yet.</div>
                <div
                  :for={{id, recording} <- @streams.recordings}
                  id={id}
                  class="rounded-2xl border border-slate-200 bg-slate-50 p-4"
                >
                  <div class="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-500">
                    <span class="font-semibold uppercase tracking-wide">
                      {humanize_recording_status(recording.status)}
                    </span>
                    <span>{format_datetime(recording.recorded_at)}</span>
                  </div>
                  <p class="mt-2 text-sm text-slate-800">
                    Duration {recording.duration_seconds || 0}s
                  </p>
                  <audio :if={recording.file_url} controls class="mt-3 w-full">
                    <source src={recording.file_url} type="audio/m4a" />
                  </audio>
                  <p :if={!recording.file_url} class="mt-3 text-xs text-slate-500">
                    Upload pending.
                  </p>
                </div>
              </div>
            </div>

            <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-slate-900">Follow-ups</h2>
              </div>
              <div id="lead-followups" phx-update="stream" class="mt-4 space-y-3">
                <div class="hidden text-sm text-slate-500 only:block">No follow-ups yet.</div>
                <div
                  :for={{id, followup} <- @streams.followups}
                  id={id}
                  class="rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-700"
                >
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="font-semibold text-slate-900">
                        {format_datetime(followup.due_at)}
                      </p>
                      <p class="text-xs text-slate-500">
                        {followup.note}
                      </p>
                    </div>
                    <div class="flex items-center gap-2">
                      <span class="rounded-full bg-white px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-600">
                        {humanize_followup(followup.status)}
                      </span>
                      <button
                        :if={@can_update && followup.status == :pending}
                        type="button"
                        phx-click="complete_followup"
                        phx-value-id={followup.id}
                        class="text-xs font-semibold text-slate-900 hover:text-slate-700"
                      >
                        Mark done
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <.form
                :if={@can_update}
                for={@followup_form}
                id="lead-followup-form"
                phx-submit="schedule_followup"
                class="mt-6 space-y-3"
              >
                <.input
                  field={@followup_form[:due_at]}
                  type="datetime-local"
                  label="Schedule next follow-up"
                />
                <.input field={@followup_form[:note]} type="text" placeholder="Optional note" />
                <button
                  type="submit"
                  class="inline-flex h-11 items-center rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Schedule follow-up
                </button>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Asia/Kolkata")
    |> Calendar.strftime("%d %b %Y, %I:%M %p")
  end

  defp humanize_activity(type) do
    type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_followup(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_recording_status(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
