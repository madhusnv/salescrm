defmodule BackendWeb.Admin.UniversityLive.Index do
  use BackendWeb, :live_view

  alias Backend.Organizations
  alias Backend.Organizations.University

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Universities")
     |> assign(:universities, Organizations.list_universities(scope.user.organization_id))
     |> assign(:university, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:university, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    university = %University{}
    changeset = Organizations.change_university(university)

    socket
    |> assign(:page_title, "New University")
    |> assign(:university, university)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    university = Organizations.get_university!(id)
    changeset = Organizations.change_university(university)

    socket
    |> assign(:page_title, "Edit University")
    |> assign(:university, university)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    university = Organizations.get_university!(id)

    case Organizations.delete_university(university) do
      {:ok, _} ->
        scope = socket.assigns.current_scope

        {:noreply,
         socket
         |> put_flash(:info, "University deleted")
         |> assign(:universities, Organizations.list_universities(scope.user.organization_id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot delete university with leads")}
    end
  end

  @impl true
  def handle_event("save", %{"university" => params}, socket) do
    save_university(socket, socket.assigns.live_action, params)
  end

  defp save_university(socket, :new, params) do
    scope = socket.assigns.current_scope
    attrs = Map.put(params, "organization_id", scope.user.organization_id)

    case Organizations.create_university(attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "University created successfully")
         |> push_navigate(to: ~p"/admin/universities")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_university(socket, :edit, params) do
    case Organizations.update_university(socket.assigns.university, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "University updated successfully")
         |> push_navigate(to: ~p"/admin/universities")}

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
            navigate={~p"/admin/universities/new"}
            class="inline-flex h-10 items-center gap-2 rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
          >
            <.icon name="hero-plus" class="size-4" /> Add University
          </.link>
        </div>

        <%= if @live_action in [:new, :edit] do %>
          <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
            <.form for={@form} phx-submit="save" class="space-y-4">
              <.input field={@form[:name]} type="text" label="University Name" required />

              <div class="flex items-center gap-3 pt-4">
                <button
                  type="submit"
                  class="inline-flex h-10 items-center rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  {if @live_action == :new, do: "Create University", else: "Save Changes"}
                </button>
                <.link
                  navigate={~p"/admin/universities"}
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
                  <th class="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wide text-slate-500">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr :for={university <- @universities} class="hover:bg-slate-50">
                  <td class="whitespace-nowrap px-6 py-4 text-sm font-medium text-slate-900">
                    {university.name}
                  </td>
                  <td class="whitespace-nowrap px-6 py-4 text-right text-sm">
                    <.link
                      navigate={~p"/admin/universities/#{university.id}/edit"}
                      class="font-medium text-slate-600 hover:text-slate-900"
                    >
                      Edit
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={university.id}
                      class="ml-4 font-medium text-red-600 hover:text-red-800"
                      data-confirm="Are you sure?"
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
