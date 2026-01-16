defmodule BackendWeb.Admin.AuditLive.Index do
  use BackendWeb, :live_view

  alias Backend.Audit

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Audit Log")
     |> assign(:entries, Audit.list_entries(scope))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
    <div class="mx-auto max-w-5xl space-y-6">
      <div>
        <p class="text-xs font-semibold uppercase tracking-widest text-slate-500">Admin</p>
        <h1 class="mt-2 text-2xl font-semibold text-slate-900">{@page_title}</h1>
        <p class="mt-1 text-sm text-slate-500">Track sensitive actions across the system</p>
      </div>

      <div class="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-slate-100">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Action
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                User
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Resource
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Timestamp
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={entry <- @entries} class="hover:bg-slate-50">
              <td class="whitespace-nowrap px-6 py-4 text-sm font-medium text-slate-900">
                {entry.action}
              </td>
              <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                {entry.user_email || "System"}
              </td>
              <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                {entry.resource_type} #{entry.resource_id}
              </td>
              <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-500">
                {Calendar.strftime(entry.inserted_at, "%b %d, %Y %I:%M %p")}
              </td>
            </tr>
          </tbody>
        </table>
        <div :if={@entries == []} class="px-6 py-12 text-center text-sm text-slate-500">
          No audit entries found
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end
end
