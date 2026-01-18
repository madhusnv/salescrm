defmodule BackendWeb.Admin.CounselorReportLive.Index do
  use BackendWeb, :live_view

  alias Backend.Reports

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Counselor Reports")
     |> assign(:date_filter, "today")
     |> assign(:custom_start, nil)
     |> assign(:custom_end, nil)
     |> load_counselors()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:date_filter, filter)
     |> load_counselors()}
  end

  @impl true
  def handle_event("custom_range", %{"start" => start_str, "end" => end_str}, socket) do
    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str) do
      {:noreply,
       socket
       |> assign(:date_filter, "custom")
       |> assign(:custom_start, start_date)
       |> assign(:custom_end, end_date)
       |> load_counselors()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid date range")}
    end
  end

  defp load_counselors(socket) do
    scope = socket.assigns.current_scope
    filter = socket.assigns.date_filter
    custom_start = socket.assigns[:custom_start]
    custom_end = socket.assigns[:custom_end]

    date_range = Reports.date_range_for_filter(filter, custom_start, custom_end)
    counselors = Reports.list_counselor_stats(scope, date_range)

    assign(socket, :counselors, counselors)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-widest text-slate-500">Admin</p>
            <h1 class="mt-2 text-2xl font-semibold text-slate-900">{@page_title}</h1>
            <p class="mt-1 text-sm text-slate-500">View counselor performance and activity</p>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <button
              :for={
                {label, value} <- [
                  {"Today", "today"},
                  {"This Week", "week"},
                  {"This Month", "month"}
                ]
              }
              phx-click="filter"
              phx-value-filter={value}
              class={[
                "rounded-full px-4 py-2 text-sm font-medium transition",
                @date_filter == value &&
                  "bg-slate-900 text-white",
                @date_filter != value &&
                  "bg-white text-slate-600 border border-slate-200 hover:border-slate-300"
              ]}
            >
              {label}
            </button>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <form phx-submit="custom_range" class="flex flex-wrap items-end gap-4">
            <div>
              <label class="block text-xs font-medium text-slate-600">Start Date</label>
              <input
                type="date"
                name="start"
                value={@custom_start && Date.to_iso8601(@custom_start)}
                class="mt-1 rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-slate-400 focus:outline-none focus:ring-0"
              />
            </div>
            <div>
              <label class="block text-xs font-medium text-slate-600">End Date</label>
              <input
                type="date"
                name="end"
                value={@custom_end && Date.to_iso8601(@custom_end)}
                class="mt-1 rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-slate-400 focus:outline-none focus:ring-0"
              />
            </div>
            <button
              type="submit"
              class="rounded-full bg-slate-100 px-4 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-200"
            >
              Apply Range
            </button>
          </form>
        </div>

        <div
          :if={@counselors == []}
          class="rounded-2xl border border-slate-200 bg-white p-12 text-center shadow-sm"
        >
          <p class="text-sm text-slate-500">No counselors found</p>
        </div>

        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={counselor <- @counselors}
            class="group rounded-2xl border border-slate-200 bg-white p-6 shadow-sm transition hover:shadow-md"
          >
            <div class="flex items-start justify-between">
              <div>
                <h3 class="text-lg font-semibold text-slate-900">
                  {counselor.full_name || "—"}
                </h3>
                <p class="text-sm text-slate-500">{counselor.email}</p>
              </div>
              <span class={[
                "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                counselor.is_active && "bg-emerald-100 text-emerald-700",
                !counselor.is_active && "bg-red-100 text-red-700"
              ]}>
                {if counselor.is_active, do: "Active", else: "Inactive"}
              </span>
            </div>

            <div class="mt-6 grid grid-cols-2 gap-4">
              <div class="rounded-xl bg-slate-50 p-3">
                <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Calls</p>
                <p class="mt-1 text-2xl font-semibold text-slate-900">
                  {counselor.stats.total_calls}
                </p>
              </div>
              <div class="rounded-xl bg-slate-50 p-3">
                <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Leads</p>
                <p class="mt-1 text-2xl font-semibold text-slate-900">
                  {counselor.stats.leads_handled}
                </p>
              </div>
              <div class="rounded-xl bg-slate-50 p-3">
                <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Avg Duration</p>
                <p class="mt-1 text-2xl font-semibold text-slate-900">
                  {format_duration(counselor.stats.avg_call_duration)}
                </p>
              </div>
              <div class="rounded-xl bg-slate-50 p-3">
                <p class="text-xs font-medium uppercase tracking-wide text-slate-500">Recordings</p>
                <p class="mt-1 text-2xl font-semibold text-slate-900">
                  {counselor.stats.recordings_count}
                </p>
              </div>
            </div>

            <div class="mt-4 rounded-xl bg-indigo-50 p-3">
              <p class="text-xs font-medium uppercase tracking-wide text-indigo-600">
                Total Duration
              </p>
              <p class="mt-1 text-2xl font-semibold text-indigo-700">
                {format_duration(counselor.stats.total_duration)}
              </p>
            </div>

            <div class="mt-6">
              <.link
                navigate={~p"/admin/counselor-reports/#{counselor.id}?filter=#{@date_filter}"}
                class="inline-flex w-full items-center justify-center gap-2 rounded-full bg-slate-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-slate-800"
              >
                <.icon name="hero-eye" class="size-4" /> View Details
              </.link>
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
end
