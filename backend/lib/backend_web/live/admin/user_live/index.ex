defmodule BackendWeb.Admin.UserLive.Index do
  use BackendWeb, :live_view

  alias Backend.Accounts
  alias Backend.Accounts.User
  alias Backend.Access
  alias Backend.Organizations

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:users, list_users(scope))
     |> assign(:roles, Access.list_roles())
     |> assign(:branches, Organizations.list_branches(scope.user.organization_id))
     |> assign(:user, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:user, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, _params) do
    user = %User{}
    changeset = Accounts.change_user_registration(user)

    socket
    |> assign(:page_title, "New User")
    |> assign(:user, user)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    user = Accounts.get_user!(scope, id)
    changeset = Accounts.change_user_profile(user)

    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, user)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    user = Accounts.get_user!(scope, id)

    case Accounts.toggle_active(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User status updated")
         |> assign(:users, list_users(scope))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user")}
    end
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.live_action, user_params)
  end

  defp save_user(socket, :new, user_params) do
    scope = socket.assigns.current_scope

    attrs =
      user_params
      |> Map.put("organization_id", scope.user.organization_id)

    case Accounts.register_user(attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user_profile(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp list_users(scope) do
    Accounts.list_users(scope)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-xs font-semibold uppercase tracking-widest text-slate-500">Admin</p>
          <h1 class="mt-2 text-2xl font-semibold text-slate-900">{@page_title}</h1>
        </div>
        <.link
          :if={@live_action == :index}
          navigate={~p"/admin/users/new"}
          class="inline-flex h-10 items-center gap-2 rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
        >
          <.icon name="hero-plus" class="size-4" /> Add User
        </.link>
      </div>

      <%= if @live_action in [:new, :edit] do %>
        <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <.form for={@form} phx-submit="save" class="space-y-4">
            <.input field={@form[:email]} type="email" label="Email" required />
            <.input field={@form[:full_name]} type="text" label="Full Name" required />
            <.input field={@form[:phone_number]} type="text" label="Phone Number" />
            <.input
              :if={@live_action == :new}
              field={@form[:password]}
              type="password"
              label="Password"
              required
            />
            <.input
              field={@form[:role_id]}
              type="select"
              label="Role"
              options={Enum.map(@roles, &{&1.name, &1.id})}
              prompt="Select role"
            />
            <.input
              field={@form[:branch_id]}
              type="select"
              label="Branch"
              options={Enum.map(@branches, &{&1.name, &1.id})}
              prompt="Select branch"
            />

            <div class="flex items-center gap-3 pt-4">
              <button
                type="submit"
                class="inline-flex h-10 items-center rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
              >
                {if @live_action == :new, do: "Create User", else: "Save Changes"}
              </button>
              <.link
                navigate={~p"/admin/users"}
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
                  Email
                </th>
                <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Role
                </th>
                <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Status
                </th>
                <th class="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={user <- @users} class="hover:bg-slate-50">
                <td class="whitespace-nowrap px-6 py-4 text-sm font-medium text-slate-900">
                  {user.full_name || "—"}
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                  {user.email}
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                  {user.role && user.role.name}
                </td>
                <td class="whitespace-nowrap px-6 py-4">
                  <span class={[
                    "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                    user.is_active && "bg-emerald-100 text-emerald-700",
                    !user.is_active && "bg-red-100 text-red-700"
                  ]}>
                    {if user.is_active, do: "Active", else: "Inactive"}
                  </span>
                </td>
                <td class="whitespace-nowrap px-6 py-4 text-right text-sm">
                  <.link
                    navigate={~p"/admin/users/#{user.id}/edit"}
                    class="font-medium text-slate-600 hover:text-slate-900"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={user.id}
                    class="ml-4 font-medium text-red-600 hover:text-red-800"
                    data-confirm="Are you sure?"
                  >
                    {if user.is_active, do: "Deactivate", else: "Activate"}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end
end
