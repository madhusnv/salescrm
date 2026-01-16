defmodule BackendWeb.DashboardLive do
  use BackendWeb, :live_view

  alias Backend.Access
  alias Backend.Analytics

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    branch_scoped = !Access.super_admin?(scope.user)
    metrics = Analytics.dashboard_metrics(scope, Date.utc_today(), branch_scoped: branch_scoped)

    {:ok,
     socket
     |> assign(:metrics, metrics)
     |> assign(:branch_scoped, branch_scoped)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-6">
        <div class="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
            Dashboard
          </p>
          <h1 class="display-text mt-4 text-3xl font-semibold text-slate-900 sm:text-4xl">
            Pipeline visibility at a glance.
          </h1>
          <p class="mt-3 text-base text-slate-600">
            {if @branch_scoped, do: "Branch performance for today.", else: "Organization-wide performance for today."}
          </p>
          <div class="mt-6 grid gap-4 sm:grid-cols-3">
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Leads today</p>
              <p class="mt-2 text-2xl font-semibold text-slate-900">
                {Map.get(@metrics, "lead_created", 0)}
              </p>
            </div>
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Follow-ups</p>
              <p class="mt-2 text-2xl font-semibold text-slate-900">
                {Map.get(@metrics, "followup_scheduled", 0)}
              </p>
            </div>
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Call coverage</p>
              <p class="mt-2 text-2xl font-semibold text-slate-900">
                {Map.get(@metrics, "call_logged", 0)}
              </p>
            </div>
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Recordings uploaded
              </p>
              <p class="mt-2 text-2xl font-semibold text-slate-900">
                {Map.get(@metrics, "recording_uploaded", 0)}
              </p>
            </div>
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Consent captured
              </p>
              <p class="mt-2 text-2xl font-semibold text-slate-900">
                {Map.get(@metrics, "consent_captured", 0)}
              </p>
            </div>
            <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Status updates
              </p>
              <p class="mt-2 text-2xl font-semibold text-slate-900">
                {Map.get(@metrics, "lead_status_updated", 0)}
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
