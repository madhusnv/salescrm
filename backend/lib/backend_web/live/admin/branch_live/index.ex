defmodule BackendWeb.Admin.BranchLive.Index do
  use BackendWeb, :live_view

  alias Backend.Organizations
  alias Backend.Organizations.Branch

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Branches")
     |> assign(:branches, Organizations.list_branches(scope.user.organization_id))
     |> assign(:branch, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:branch, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    branch = %Branch{}
    changeset = Organizations.change_branch(branch)

    socket
    |> assign(:page_title, "New Branch")
    |> assign(:branch, branch)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    branch = Organizations.get_branch!(id)
    changeset = Organizations.change_branch(branch)

    socket
    |> assign(:page_title, "Edit Branch")
    |> assign(:branch, branch)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    branch = Organizations.get_branch!(id)

    case Organizations.delete_branch(branch) do
      {:ok, _branch} ->
        scope = socket.assigns.current_scope

        {:noreply,
         socket
         |> put_flash(:info, "Branch deleted")
         |> assign(:branches, Organizations.list_branches(scope.user.organization_id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot delete branch with users or leads")}
    end
  end

  @impl true
  def handle_event("save", %{"branch" => branch_params}, socket) do
    save_branch(socket, socket.assigns.live_action, branch_params)
  end

  defp save_branch(socket, :new, branch_params) do
    scope = socket.assigns.current_scope
    attrs = Map.put(branch_params, "organization_id", scope.user.organization_id)

    case Organizations.create_branch(attrs) do
      {:ok, _branch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Branch created successfully")
         |> push_navigate(to: ~p"/admin/branches")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_branch(socket, :edit, branch_params) do
    case Organizations.update_branch(socket.assigns.branch, branch_params) do
      {:ok, _branch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Branch updated successfully")
         |> push_navigate(to: ~p"/admin/branches")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-widest text-slate-500">Admin</p>
            <h1 class="mt-2 text-2xl font-semibold text-slate-900">{@page_title}</h1>
          </div>
          <.link
            :if={@live_action == :index}
            navigate={~p"/admin/branches/new"}
            class="inline-flex h-10 items-center gap-2 rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
          >
            <.icon name="hero-plus" class="size-4" /> Add Branch
          </.link>
        </div>

        <%= if @live_action in [:new, :edit] do %>
          <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
            <.form for={@form} phx-submit="save" class="space-y-4">
              <.input field={@form[:name]} type="text" label="Branch Name" required />
              <.input field={@form[:city]} type="text" label="City" />
              <.input field={@form[:state]} type="text" label="State" />

              <div class="flex items-center gap-3 pt-4">
                <button
                  type="submit"
                  class="inline-flex h-10 items-center rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  {if @live_action == :new, do: "Create Branch", else: "Save Changes"}
                </button>
                <.link
                  navigate={~p"/admin/branches"}
                  class="inline-flex h-10 items-center rounded-full border border-slate-200 px-5 text-sm font-semibold text-slate-600 transition hover:border-slate-300"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </div>
        <% else %>
          <div class="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
            <table class="min-w-full divide-y divide-slate-100">
              <thead class="bg-slate-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                    Name
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                    City
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                    State
                  </th>
                  <th class="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wide text-slate-500">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr :for={branch <- @branches} class="hover:bg-slate-50">
                  <td class="whitespace-nowrap px-6 py-4 text-sm font-medium text-slate-900">
                    {branch.name}
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                    {branch.city || "—"}
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                    {branch.state || "—"}
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-right text-sm">
                    <.link
                      navigate={~p"/admin/branches/#{branch.id}/edit"}
                      class="font-medium text-slate-600 hover:text-slate-900"
                    >
                      Edit
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={branch.id}
                      class="ml-4 font-medium text-red-600 hover:text-red-800"
                      data-confirm="Are you sure? This will fail if the branch has users or leads."
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
