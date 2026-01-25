defmodule BackendWeb.Admin.CounselorReportLive.Show do
  use BackendWeb, :live_view

  alias Backend.Reports

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    filter = Map.get(params, "filter", "today")
    scope = socket.assigns.current_scope
    date_range = Reports.date_range_for_filter(filter)

    case Reports.get_counselor_with_stats(scope, id, date_range) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Counselor not found")
         |> push_navigate(to: ~p"/admin/counselor-reports")}

      counselor ->
        leads = Reports.list_counselor_leads(scope, counselor.id)
        leads_with_calls = load_calls_for_leads(leads)
        daily_durations = Reports.list_counselor_daily_call_durations(counselor.id, date_range)

        {:ok,
         socket
         |> assign(:page_title, "#{counselor.full_name} - Report")
         |> assign(:counselor, counselor)
         |> assign(:leads, leads_with_calls)
         |> assign(:search, "")
         |> assign(:date_filter, filter)
         |> assign(:daily_durations, daily_durations)
         |> assign(:playing_recording, nil)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    scope = socket.assigns.current_scope
    counselor = socket.assigns.counselor

    leads = Reports.list_counselor_leads(scope, counselor.id, search: search)
    leads_with_calls = load_calls_for_leads(leads)

    {:noreply,
     socket
     |> assign(:search, search)
     |> assign(:leads, leads_with_calls)}
  end

  @impl true
  def handle_event("play", %{"recording-id" => id}, socket) do
    recording_id = String.to_integer(id)

    recording =
      socket.assigns.leads
      |> Enum.flat_map(& &1.calls)
      |> Enum.find_value(fn call ->
        call.recording && call.recording.id == recording_id && call.recording
      end)

    case recording && Reports.get_recording_url(recording) do
      {:ok, url} ->
        {:noreply, assign(socket, :playing_recording, %{id: recording_id, url: url})}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not load recording")}
    end
  end

  @impl true
  def handle_event("close_player", _params, socket) do
    {:noreply, assign(socket, :playing_recording, nil)}
  end

  defp load_calls_for_leads(leads) do
    Enum.map(leads, fn lead ->
      calls = Reports.list_lead_calls_with_recordings(lead.id)
      Map.put(lead, :calls, calls)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <.link
              navigate={~p"/admin/counselor-reports"}
              class="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Back to Reports
            </.link>
            <h1 class="mt-2 text-2xl font-semibold text-slate-900">{@counselor.full_name}</h1>
            <p class="mt-1 text-sm text-slate-500">{@counselor.email}</p>
          </div>
        </div>

        <div class="grid gap-4 sm:grid-cols-5">
          <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Calls</p>
            <p class="mt-1 text-2xl font-semibold text-slate-900">
              {@counselor.stats.total_calls}
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Leads</p>
            <p class="mt-1 text-2xl font-semibold text-slate-900">
              {@counselor.stats.leads_handled}
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Avg Duration</p>
            <p class="mt-1 text-2xl font-semibold text-slate-900">
              {format_duration(@counselor.stats.avg_call_duration)}
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Recordings</p>
            <p class="mt-1 text-2xl font-semibold text-slate-900">
              {@counselor.stats.recordings_count}
            </p>
          </div>
          <div class="rounded-2xl border border-indigo-200 bg-indigo-50 p-4 shadow-sm">
            <p class="text-xs font-medium uppercase tracking-wide text-indigo-600">Total Duration</p>
            <p class="mt-1 text-2xl font-semibold text-indigo-700">
              {format_duration(@counselor.stats.total_duration)}
            </p>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-slate-900">Daily Call Duration</h2>
            <p class="text-xs font-medium uppercase tracking-wide text-slate-500">
              {@date_filter}
            </p>
          </div>
          <div :if={@daily_durations == []} class="mt-4 text-sm text-slate-500">
            No calls recorded
          </div>
          <div :if={@daily_durations != []} class="mt-4 space-y-2">
            <div
              :for={row <- @daily_durations}
              class="flex items-center justify-between rounded-lg bg-slate-50 px-4 py-2"
            >
              <span class="text-sm text-slate-700">
                {Calendar.strftime(row.date, "%b %d, %Y")}
              </span>
              <span class="text-sm font-semibold text-slate-900">
                {format_duration(row.total_duration)}
              </span>
            </div>
          </div>
        </div>

        <%= if @playing_recording do %>
          <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-slate-900">Now Playing</p>
              <button
                phx-click="close_player"
                class="text-slate-400 hover:text-slate-600"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>
            <audio
              controls
              autoplay
              class="mt-4 w-full"
              src={@playing_recording.url}
            >
              Your browser does not support audio playback.
            </audio>
          </div>
        <% end %>

        <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-slate-900">Leads & Calls</h2>
            <form phx-change="search" class="relative">
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Search by name or phone..."
                phx-debounce="300"
                class="w-64 rounded-full border border-slate-200 py-2 pl-10 pr-4 text-sm focus:border-slate-400 focus:outline-none focus:ring-0"
              />
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-slate-400"
              />
            </form>
          </div>

          <div :if={@leads == []} class="mt-8 text-center text-sm text-slate-500">
            No leads found
          </div>

          <div class="mt-6 space-y-4">
            <div
              :for={lead <- @leads}
              class="rounded-xl border border-slate-100 bg-slate-50 p-4"
            >
              <div class="flex items-start justify-between">
                <div>
                  <h3 class="font-medium text-slate-900">{lead.student_name}</h3>
                  <p class="text-sm text-slate-500">{lead.phone_number}</p>
                </div>
                <span class={[
                  "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                  lead.status == :new && "bg-blue-100 text-blue-700",
                  lead.status == :contacted && "bg-teal-100 text-teal-700",
                  lead.status == :follow_up && "bg-amber-100 text-amber-700",
                  lead.status == :applied && "bg-emerald-100 text-emerald-700",
                  lead.status == :not_interested && "bg-slate-100 text-slate-600"
                ]}>
                  {format_status(lead.status)}
                </span>
              </div>

              <div :if={lead.calls != []} class="mt-4 space-y-2">
                <p class="text-xs font-medium uppercase tracking-wide text-slate-500">
                  Calls ({length(lead.calls)})
                </p>
                <div class="space-y-2">
                  <div
                    :for={call <- lead.calls}
                    class="flex items-center justify-between rounded-lg bg-white px-4 py-3"
                  >
                    <div class="flex items-center gap-4">
                      <div class={[
                        "flex size-8 items-center justify-center rounded-full",
                        call.call_type == :incoming && "bg-green-100",
                        call.call_type == :outgoing && "bg-blue-100",
                        call.call_type in [:missed, :rejected, :blocked] && "bg-red-100",
                        call.call_type == :unknown && "bg-slate-100"
                      ]}>
                        <.icon
                          name={call_icon(call.call_type)}
                          class={[
                            "size-4",
                            call.call_type == :incoming && "text-green-600",
                            call.call_type == :outgoing && "text-blue-600",
                            call.call_type in [:missed, :rejected, :blocked] && "text-red-600",
                            call.call_type == :unknown && "text-slate-600"
                          ]}
                        />
                      </div>
                      <div>
                        <p class="text-sm font-medium text-slate-900">
                          {String.capitalize(to_string(call.call_type))}
                        </p>
                        <p class="text-xs text-slate-500">
                          {format_datetime_ist(call.started_at)}
                        </p>
                      </div>
                    </div>
                    <div class="flex items-center gap-4">
                      <span class="text-sm text-slate-600">
                        {format_duration(call.duration_seconds)}
                      </span>
                      <%= if call.recording do %>
                        <button
                          phx-click="play"
                          phx-value-recording-id={call.recording.id}
                          class={[
                            "inline-flex items-center gap-1 rounded-full px-3 py-1 text-xs font-medium transition",
                            @playing_recording && @playing_recording.id == call.recording.id &&
                              "bg-indigo-600 text-white",
                            !(@playing_recording && @playing_recording.id == call.recording.id) &&
                              "bg-indigo-100 text-indigo-700 hover:bg-indigo-200"
                          ]}
                        >
                          <.icon name="hero-play" class="size-3" />
                          {if @playing_recording && @playing_recording.id == call.recording.id,
                            do: "Playing",
                            else: "Play"}
                        </button>
                      <% else %>
                        <span class="text-xs text-slate-400">No recording</span>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>

              <div :if={lead.calls == []} class="mt-4 text-sm text-slate-400">
                No calls recorded
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_duration(nil), do: "0:00"

  defp format_duration(seconds) when is_integer(seconds) or is_float(seconds) do
    seconds = trunc(seconds)
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
    else
      "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
    end
  end

  defp format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_status(status) when is_binary(status), do: String.capitalize(status)

  defp call_icon(:incoming), do: "hero-phone-arrow-down-left"
  defp call_icon(:outgoing), do: "hero-phone-arrow-up-right"
  defp call_icon(:missed), do: "hero-phone-x-mark"
  defp call_icon(:rejected), do: "hero-phone-x-mark"
  defp call_icon(:blocked), do: "hero-no-symbol"
  defp call_icon(_), do: "hero-phone"

  defp format_datetime_ist(nil), do: "—"

  defp format_datetime_ist(%DateTime{} = datetime) do
    datetime
    |> to_ist()
    |> Calendar.strftime("%b %d, %Y at %I:%M %p")
  end

  defp to_ist(%DateTime{} = datetime) do
    DateTime.add(datetime, 19_800, :second)
  end
end
