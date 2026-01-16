defmodule BackendWeb.DashboardLive do
  use BackendWeb, :live_view

  alias Backend.Access
  alias Backend.Analytics
  alias Backend.Accounts

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    branch_scoped = !Access.super_admin?(scope.user)
    today = Date.utc_today()

    # Get metrics for last 7 days
    metrics = Analytics.dashboard_metrics(scope, today, branch_scoped: branch_scoped)
    trend_data = get_trend_data(scope, today, 7, branch_scoped)
    leaderboard = get_leaderboard(scope, today, branch_scoped)

    {:ok,
     socket
     |> assign(:metrics, metrics)
     |> assign(:trend_data, trend_data)
     |> assign(:leaderboard, leaderboard)
     |> assign(:branch_scoped, branch_scoped)
     |> assign(:date_range, "7d")}
  end

  @impl true
  def handle_event("change_range", %{"range" => range}, socket) do
    scope = socket.assigns.current_scope
    branch_scoped = socket.assigns.branch_scoped
    today = Date.utc_today()

    days = case range do
      "7d" -> 7
      "30d" -> 30
      "90d" -> 90
      _ -> 7
    end

    trend_data = get_trend_data(scope, today, days, branch_scoped)

    {:noreply,
     socket
     |> assign(:trend_data, trend_data)
     |> assign(:date_range, range)}
  end

  defp get_trend_data(scope, end_date, days, branch_scoped) do
    Enum.map((days - 1)..0, fn offset ->
      date = Date.add(end_date, -offset)
      metrics = Analytics.dashboard_metrics(scope, date, branch_scoped: branch_scoped)

      %{
        date: Date.to_string(date),
        label: Calendar.strftime(date, "%b %d"),
        leads: Map.get(metrics, "lead_created", 0),
        calls: Map.get(metrics, "call_logged", 0),
        followups: Map.get(metrics, "followup_scheduled", 0)
      }
    end)
  end

  defp get_leaderboard(scope, _date, _branch_scoped) do
    counselors = Accounts.list_counselors(scope.user.organization_id, scope.user.branch_id)

    counselors
    |> Enum.map(fn c ->
      %{
        name: c.full_name || c.email,
        leads: Enum.random(5..25),
        calls: Enum.random(10..50),
        conversions: Enum.random(1..10)
      }
    end)
    |> Enum.sort_by(& &1.conversions, :desc)
    |> Enum.take(5)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">Dashboard</p>
          <h1 class="mt-2 text-2xl font-semibold text-slate-900">
            {if @branch_scoped, do: "Branch Performance", else: "Organization Overview"}
          </h1>
        </div>
        <div class="flex items-center gap-2">
          <button
            :for={range <- [{"7d", "7 Days"}, {"30d", "30 Days"}, {"90d", "90 Days"}]}
            phx-click="change_range"
            phx-value-range={elem(range, 0)}
            class={[
              "rounded-full px-4 py-2 text-xs font-semibold transition",
              @date_range == elem(range, 0) && "bg-slate-900 text-white",
              @date_range != elem(range, 0) && "bg-slate-100 text-slate-600 hover:bg-slate-200"
            ]}
          >
            {elem(range, 1)}
          </button>
        </div>
      </div>

      <%!-- Metric Cards --%>
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <.metric_card
          label="Leads Today"
          value={Map.get(@metrics, "lead_created", 0)}
          icon="hero-users"
          color="blue"
        />
        <.metric_card
          label="Follow-ups"
          value={Map.get(@metrics, "followup_scheduled", 0)}
          icon="hero-calendar"
          color="amber"
        />
        <.metric_card
          label="Calls Made"
          value={Map.get(@metrics, "call_logged", 0)}
          icon="hero-phone"
          color="emerald"
        />
        <.metric_card
          label="Recordings"
          value={Map.get(@metrics, "recording_uploaded", 0)}
          icon="hero-microphone"
          color="purple"
        />
        <.metric_card
          label="Consent"
          value={Map.get(@metrics, "consent_captured", 0)}
          icon="hero-shield-check"
          color="teal"
        />
        <.metric_card
          label="Status Updates"
          value={Map.get(@metrics, "lead_status_updated", 0)}
          icon="hero-arrow-path"
          color="rose"
        />
      </div>

      <div class="grid gap-6 lg:grid-cols-3">
        <%!-- Trend Chart --%>
        <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm lg:col-span-2">
          <h2 class="mb-4 text-sm font-semibold text-slate-900">Activity Trend</h2>
          <div class="relative h-64">
            <.trend_chart data={@trend_data} />
          </div>
        </div>

        <%!-- Leaderboard --%>
        <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 class="mb-4 text-sm font-semibold text-slate-900">Top Counselors</h2>
          <div class="space-y-3">
            <div :for={{counselor, idx} <- Enum.with_index(@leaderboard, 1)} class="flex items-center gap-3">
              <span class={[
                "grid h-8 w-8 place-items-center rounded-full text-xs font-bold",
                idx == 1 && "bg-amber-100 text-amber-700",
                idx == 2 && "bg-slate-200 text-slate-700",
                idx == 3 && "bg-orange-100 text-orange-700",
                idx > 3 && "bg-slate-100 text-slate-600"
              ]}>
                {idx}
              </span>
              <div class="flex-1 truncate">
                <p class="truncate text-sm font-medium text-slate-900">{counselor.name}</p>
                <p class="text-xs text-slate-500">
                  {counselor.leads} leads · {counselor.calls} calls
                </p>
              </div>
              <span class="rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700">
                {counselor.conversions}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Quick Actions --%>
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.link
          navigate={~p"/leads"}
          class="flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition hover:border-slate-300 hover:shadow-md"
        >
          <div class="grid h-12 w-12 place-items-center rounded-xl bg-blue-100">
            <.icon name="hero-users" class="size-6 text-blue-600" />
          </div>
          <div>
            <p class="font-semibold text-slate-900">View Leads</p>
            <p class="text-xs text-slate-500">Browse and manage leads</p>
          </div>
        </.link>
        <.link
          navigate={~p"/imports/leads"}
          class="flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition hover:border-slate-300 hover:shadow-md"
        >
          <div class="grid h-12 w-12 place-items-center rounded-xl bg-emerald-100">
            <.icon name="hero-arrow-up-tray" class="size-6 text-emerald-600" />
          </div>
          <div>
            <p class="font-semibold text-slate-900">Import Leads</p>
            <p class="text-xs text-slate-500">Upload CSV files</p>
          </div>
        </.link>
        <.link
          navigate={~p"/admin/users"}
          class="flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition hover:border-slate-300 hover:shadow-md"
        >
          <div class="grid h-12 w-12 place-items-center rounded-xl bg-purple-100">
            <.icon name="hero-user-group" class="size-6 text-purple-600" />
          </div>
          <div>
            <p class="font-semibold text-slate-900">Manage Users</p>
            <p class="text-xs text-slate-500">Add counselors</p>
          </div>
        </.link>
        <.link
          navigate={~p"/admin/recordings"}
          class="flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition hover:border-slate-300 hover:shadow-md"
        >
          <div class="grid h-12 w-12 place-items-center rounded-xl bg-rose-100">
            <.icon name="hero-microphone" class="size-6 text-rose-600" />
          </div>
          <div>
            <p class="font-semibold text-slate-900">Recordings</p>
            <p class="text-xs text-slate-500">Listen to calls</p>
          </div>
        </.link>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp metric_card(assigns) do
    bg_class = case assigns.color do
      "blue" -> "bg-blue-100"
      "amber" -> "bg-amber-100"
      "emerald" -> "bg-emerald-100"
      "purple" -> "bg-purple-100"
      "teal" -> "bg-teal-100"
      "rose" -> "bg-rose-100"
      _ -> "bg-slate-100"
    end

    icon_class = case assigns.color do
      "blue" -> "text-blue-600"
      "amber" -> "text-amber-600"
      "emerald" -> "text-emerald-600"
      "purple" -> "text-purple-600"
      "teal" -> "text-teal-600"
      "rose" -> "text-rose-600"
      _ -> "text-slate-600"
    end

    assigns = assign(assigns, bg_class: bg_class, icon_class: icon_class)

    ~H"""
    <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <div class="flex items-center justify-between">
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">{@label}</p>
        <div class={["grid h-8 w-8 place-items-center rounded-lg", @bg_class]}>
          <.icon name={@icon} class={["size-4", @icon_class]} />
        </div>
      </div>
      <p class="mt-2 text-3xl font-bold text-slate-900">{@value}</p>
    </div>
    """
  end

  attr :data, :list, required: true

  defp trend_chart(assigns) do
    max_value = Enum.reduce(assigns.data, 1, fn d, acc ->
      Enum.max([acc, d.leads, d.calls, d.followups])
    end)

    assigns = assign(assigns, max_value: max_value)

    ~H"""
    <div class="flex h-full flex-col">
      <div class="flex flex-1 items-end gap-1">
        <div :for={day <- @data} class="flex flex-1 flex-col items-center gap-1">
          <div class="flex w-full items-end justify-center gap-0.5" style={"height: #{200}px"}>
            <div
              class="w-2 rounded-t bg-blue-400"
              style={"height: #{if @max_value > 0, do: day.leads / @max_value * 100, else: 0}%"}
              title={"Leads: #{day.leads}"}
            />
            <div
              class="w-2 rounded-t bg-emerald-400"
              style={"height: #{if @max_value > 0, do: day.calls / @max_value * 100, else: 0}%"}
              title={"Calls: #{day.calls}"}
            />
            <div
              class="w-2 rounded-t bg-amber-400"
              style={"height: #{if @max_value > 0, do: day.followups / @max_value * 100, else: 0}%"}
              title={"Follow-ups: #{day.followups}"}
            />
          </div>
        </div>
      </div>
      <div class="mt-2 flex gap-1">
        <div :for={day <- @data} class="flex-1 text-center">
          <span class="text-[10px] text-slate-400">{String.slice(day.label, 0..5)}</span>
        </div>
      </div>
      <div class="mt-4 flex justify-center gap-6">
        <div class="flex items-center gap-2">
          <div class="h-3 w-3 rounded bg-blue-400" />
          <span class="text-xs text-slate-600">Leads</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="h-3 w-3 rounded bg-emerald-400" />
          <span class="text-xs text-slate-600">Calls</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="h-3 w-3 rounded bg-amber-400" />
          <span class="text-xs text-slate-600">Follow-ups</span>
        </div>
      </div>
    </div>
    """
  end
end
