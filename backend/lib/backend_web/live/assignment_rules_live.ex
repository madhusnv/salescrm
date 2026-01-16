defmodule BackendWeb.AssignmentRulesLive do
  use BackendWeb, :live_view

  on_mount({BackendWeb.UserAuth, :require_authenticated})
  on_mount({BackendWeb.RequirePermissionOnMount, "lead.assign"})

  alias Backend.Accounts
  alias Backend.Assignments
  alias Backend.Assignments.AssignmentRule
  alias Backend.Organizations

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    universities = Organizations.list_universities(user.organization_id)
    branches = Organizations.list_branches(user.organization_id)
    counselors = Accounts.list_counselors(user.organization_id)

    filters = %{"university_id" => ""}

    socket =
      socket
      |> assign(:universities, universities)
      |> assign(:branches, branches)
      |> assign(:counselors, counselors)
      |> assign(:filters, filters)
      |> assign(:filter_form, to_form(filters, as: "filters"))
      |> assign(:rules, Assignments.list_rules(user.organization_id, filters))
      |> assign(:form, to_form(Assignments.change_rule(%AssignmentRule{}), as: "rule"))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-6xl py-10">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
              Assignment Rules
            </p>
            <h1 class="text-3xl font-semibold text-slate-900 sm:text-4xl">
              Route leads by university
            </h1>
            <p class="mt-2 text-sm text-slate-600">
              Configure counselor routing with priority and daily caps. University-specific only.
            </p>
          </div>
          <div class="rounded-full border border-slate-200 bg-white px-4 py-2 text-xs text-slate-600">
            {length(@rules)} active rules
          </div>
        </div>

        <div class="mt-8 grid gap-8 lg:grid-cols-[0.9fr_1.1fr]">
          <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-slate-900">Create rule</h2>
            <p class="mt-1 text-sm text-slate-500">Assign counselors for a university.</p>

            <.form
              for={@form}
              id="assignment-rule-form"
              phx-submit="save"
              phx-change="validate"
              class="mt-6 space-y-4"
            >
              <.input
                field={@form[:university_id]}
                type="select"
                label="University"
                options={university_options(@universities)}
                prompt="Select university"
                required
              />

              <.input
                field={@form[:counselor_id]}
                type="select"
                label="Counselor"
                options={counselor_options(@counselors)}
                prompt="Select counselor"
                required
              />

              <.input
                field={@form[:branch_id]}
                type="select"
                label="Branch (optional)"
                options={branch_options(@branches)}
                prompt="All branches"
              />

              <div class="grid gap-4 sm:grid-cols-2">
                <.input field={@form[:priority]} type="number" label="Priority" value="0" />
                <.input field={@form[:daily_cap]} type="number" label="Daily cap" />
              </div>

              <.input field={@form[:is_active]} type="checkbox" label="Active" />

              <button
                type="submit"
                class="w-full rounded-2xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
              >
                Save rule
              </button>
            </.form>
          </section>

          <section class="space-y-4">
            <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-slate-900">Rules list</h2>
                <button
                  type="button"
                  phx-click="clear_filters"
                  class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-600 transition hover:border-slate-400"
                >
                  Clear filters
                </button>
              </div>

              <.form for={@filter_form} id="rule-filters" phx-change="filter" class="mt-4">
                <.input
                  field={@filter_form[:university_id]}
                  type="select"
                  label="Filter by university"
                  options={university_options(@universities)}
                  prompt="All universities"
                />
              </.form>
            </div>

            <div class="space-y-3">
              <%= for rule <- @rules do %>
                <div class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
                  <div class="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <p class="text-sm font-semibold text-slate-900">
                        {rule.university && rule.university.name}
                      </p>
                      <p class="mt-1 text-xs text-slate-500">
                        Counselor: {rule.counselor && rule.counselor.full_name}
                        <span :if={rule.branch}>
                          · Branch: {rule.branch.name}
                        </span>
                      </p>
                    </div>
                    <div class="flex items-center gap-2 text-xs text-slate-500">
                      <span>Priority {rule.priority}</span>
                      <span :if={rule.daily_cap}>Cap {rule.daily_cap}</span>
                    </div>
                  </div>

                  <div class="mt-4 flex flex-wrap items-center gap-3">
                    <button
                      type="button"
                      phx-click="toggle"
                      phx-value-id={rule.id}
                      class={[
                        "rounded-full px-3 py-1 text-xs font-semibold transition",
                        rule.is_active && "bg-emerald-100 text-emerald-700",
                        !rule.is_active && "bg-slate-100 text-slate-500"
                      ]}
                    >
                      {if rule.is_active, do: "Active", else: "Paused"}
                    </button>
                    <button
                      type="button"
                      phx-click="delete"
                      phx-value-id={rule.id}
                      class="rounded-full border border-rose-200 px-3 py-1 text-xs font-semibold text-rose-600 transition hover:border-rose-400"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"rule" => params}, socket) do
    changeset =
      %AssignmentRule{}
      |> Assignments.change_rule(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "rule"))}
  end

  def handle_event("save", %{"rule" => params}, socket) do
    user = socket.assigns.current_scope.user
    attrs = Map.put(params, "organization_id", user.organization_id)

    case Assignments.create_rule(attrs) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> assign(:rules, Assignments.list_rules(user.organization_id, socket.assigns.filters))
         |> assign(:form, to_form(Assignments.change_rule(%AssignmentRule{}), as: "rule"))
         |> put_flash(:info, "Rule saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "rule"))}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    rule = Assignments.get_rule!(id)

    {:ok, _rule} = Assignments.update_rule(rule, %{is_active: !rule.is_active})

    user = socket.assigns.current_scope.user

    {:noreply,
     assign(socket, :rules, Assignments.list_rules(user.organization_id, socket.assigns.filters))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    rule = Assignments.get_rule!(id)
    {:ok, _rule} = Assignments.delete_rule(rule)

    user = socket.assigns.current_scope.user

    {:noreply,
     assign(socket, :rules, Assignments.list_rules(user.organization_id, socket.assigns.filters))}
  end

  def handle_event("filter", %{"filters" => filters}, socket) do
    cleaned = drop_empty(filters)
    user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(:filters, cleaned)
     |> assign(:filter_form, to_form(cleaned, as: "filters"))
     |> assign(:rules, Assignments.list_rules(user.organization_id, cleaned))}
  end

  def handle_event("clear_filters", _params, socket) do
    user = socket.assigns.current_scope.user
    filters = %{"university_id" => ""}

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: "filters"))
     |> assign(:rules, Assignments.list_rules(user.organization_id, filters))}
  end

  defp university_options(universities) do
    Enum.map(universities, &{&1.name, &1.id})
  end

  defp counselor_options(counselors) do
    Enum.map(counselors, &{&1.full_name, &1.id})
  end

  defp branch_options(branches) do
    Enum.map(branches, &{&1.name, &1.id})
  end

  defp drop_empty(filters) do
    filters
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end
end
