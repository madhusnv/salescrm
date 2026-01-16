defmodule BackendWeb.Admin.OrganizationLive.Settings do
  use BackendWeb, :live_view

  alias Backend.Organizations

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    organization = Organizations.get_organization!(scope.user.organization_id)
    changeset = Organizations.change_organization(organization)

    {:ok,
     socket
     |> assign(:page_title, "Organization Settings")
     |> assign(:organization, organization)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"organization" => org_params}, socket) do
    case Organizations.update_organization(socket.assigns.organization, org_params) do
      {:ok, organization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Settings saved successfully")
         |> assign(:organization, organization)
         |> assign(:form, to_form(Organizations.change_organization(organization)))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-6">
      <div>
        <p class="text-xs font-semibold uppercase tracking-widest text-slate-500">Admin</p>
        <h1 class="mt-2 text-2xl font-semibold text-slate-900">{@page_title}</h1>
        <p class="mt-1 text-sm text-slate-500">Configure your organization details and preferences</p>
      </div>

      <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <.form for={@form} phx-submit="save" class="space-y-6">
          <div class="space-y-4">
            <h2 class="text-sm font-semibold text-slate-900">Basic Information</h2>
            <.input field={@form[:name]} type="text" label="Organization Name" required />
            <.input field={@form[:country]} type="text" label="Country Code" placeholder="IN" />
          </div>

          <div class="space-y-4">
            <h2 class="text-sm font-semibold text-slate-900">Timezone & Locale</h2>
            <.input
              field={@form[:timezone]}
              type="select"
              label="Timezone"
              options={[
                {"Asia/Kolkata (IST)", "Asia/Kolkata"},
                {"America/New_York (EST)", "America/New_York"},
                {"America/Los_Angeles (PST)", "America/Los_Angeles"},
                {"Europe/London (GMT)", "Europe/London"},
                {"Asia/Dubai (GST)", "Asia/Dubai"},
                {"Asia/Singapore (SGT)", "Asia/Singapore"}
              ]}
            />
          </div>

          <div class="pt-4">
            <button
              type="submit"
              class="inline-flex h-10 items-center rounded-full bg-slate-900 px-6 text-sm font-semibold text-white transition hover:bg-slate-800"
            >
              Save Settings
            </button>
          </div>
        </.form>
      </div>

      <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 class="text-sm font-semibold text-slate-900">Organization ID</h2>
        <p class="mt-2 font-mono text-sm text-slate-600">{@organization.id}</p>
        <p class="mt-1 text-xs text-slate-400">Use this ID when integrating with APIs</p>
      </div>
    </div>
    """
  end
end
