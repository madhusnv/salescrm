defmodule BackendWeb.LeadIndexLive do
  use BackendWeb, :live_view

  import Ecto.Query, warn: false

  alias Backend.Accounts
  alias Backend.Access
  alias Backend.Leads
  alias Backend.Leads.Lead
  alias Backend.Repo

  on_mount({BackendWeb.RequirePermissionOnMount, "lead.read"})

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    role_name = role_name(user)
    counselors = list_counselors(user, role_name)
    can_assign = Access.role_has_permission?(user, "lead.assign")

    socket =
      socket
      |> assign(:filters, default_filters())
      |> assign(:page, 1)
      |> assign(:page_size, @page_size)
      |> assign(:total_count, 0)
      |> assign(:total_pages, 1)
      |> assign(:page_links, %{prev: nil, next: nil})
      |> assign(:show_counselor_filter, role_name in ["Super Admin", "Branch Manager"])
      |> assign(:counselors, counselors)
      |> assign(:counselor_options, counselor_options(counselors))
      |> assign(:status_options, status_options())
      |> assign(:filter_form, to_form(default_filters(), as: :filters))
      |> assign(:assignment_forms, %{})
      |> assign(:can_assign, can_assign)
      |> stream(:leads, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_page(params)
    filters = normalize_filters(params)

    leads =
      Leads.list_leads(socket.assigns.current_scope, filters, page, socket.assigns.page_size)

    total_count = Leads.count_leads(socket.assigns.current_scope, filters)
    assignment_forms = build_assignment_forms(leads)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:page, page)
      |> assign(:total_count, total_count)
      |> assign(:assignment_forms, assignment_forms)
      |> assign(:filter_form, to_form(filters, as: :filters))
      |> assign_pagination(filters, page, total_count)
      |> stream(:leads, leads, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    params = filters |> Map.put("page", "1") |> clean_params()
    {:noreply, push_patch(socket, to: ~p"/leads?#{params}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/leads")}
  end

  def handle_event(
        "assign",
        %{"assignment" => %{"lead_id" => lead_id, "counselor_id" => counselor_id}},
        socket
      ) do
    if socket.assigns.can_assign do
      with {:ok, lead_id} <- parse_id(lead_id),
           {:ok, counselor_id} <- parse_id(counselor_id) do
        lead = Leads.get_lead!(socket.assigns.current_scope, lead_id)

        case Leads.assign_lead(socket.assigns.current_scope, lead, counselor_id) do
          {:ok, lead} ->
            refreshed = Leads.get_lead!(socket.assigns.current_scope, lead.id)

            assignment_forms =
              Map.put(socket.assigns.assignment_forms, lead.id, build_assignment_form(refreshed))

            {:noreply,
             socket
             |> stream_insert(:leads, refreshed)
             |> assign(:assignment_forms, assignment_forms)
             |> put_flash(:info, "Lead assigned successfully.")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Assignment failed: #{inspect(reason)}")}
        end
      else
        :error ->
          {:noreply, put_flash(socket, :error, "Select a counselor before assigning.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to assign leads.")}
    end
  end

  defp assign_pagination(socket, filters, page, total_count) do
    total_pages =
      max(div(total_count + socket.assigns.page_size - 1, socket.assigns.page_size), 1)

    prev_page = if page > 1, do: page - 1, else: nil
    next_page = if page < total_pages, do: page + 1, else: nil

    page_links = %{
      prev: build_query(filters, prev_page),
      next: build_query(filters, next_page)
    }

    assign(socket, total_pages: total_pages, page_links: page_links)
  end

  defp build_query(_filters, nil), do: nil

  defp build_query(filters, page) do
    filters
    |> Map.put("page", to_string(page))
    |> clean_params()
  end

  defp clean_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Enum.into(%{})
    |> URI.encode_query()
  end

  defp parse_page(%{"page" => page}) when is_binary(page) do
    case Integer.parse(page) do
      {page_num, _} when page_num > 0 -> page_num
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp normalize_filters(params) do
    default_filters()
    |> Map.merge(Map.take(params, ["status", "search", "counselor_id", "include_merged"]))
  end

  defp default_filters do
    %{"status" => "", "search" => "", "counselor_id" => "", "include_merged" => "false"}
  end

  defp status_options do
    [{"All statuses", ""} | Enum.map(Lead.statuses(), &{humanize_status(&1), Atom.to_string(&1)})]
  end

  defp counselor_options(counselors) do
    [{"Select counselor", ""} | Enum.map(counselors, &{&1.full_name, &1.id})]
  end

  defp build_assignment_forms(leads) do
    leads
    |> Enum.map(fn lead -> {lead.id, build_assignment_form(lead)} end)
    |> Map.new()
  end

  defp build_assignment_form(lead) do
    to_form(
      %{
        "lead_id" => to_string(lead.id),
        "counselor_id" => to_string(lead.assigned_counselor_id || "")
      },
      as: :assignment
    )
  end

  defp list_counselors(user, role_name) do
    cond do
      Access.super_admin?(user) ->
        Accounts.list_counselors(user.organization_id)

      role_name == "Branch Manager" ->
        Accounts.list_counselors(user.organization_id, user.branch_id)

      true ->
        []
    end
  end

  defp role_name(user) do
    Repo.one(from(r in Backend.Access.Role, where: r.id == ^user.role_id, select: r.name))
  end

  defp humanize_status(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, _} -> {:ok, id}
      :error -> :error
    end
  end

  defp parse_id(_), do: :error

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 class="text-3xl font-semibold text-slate-900">Leads</h1>
            <p class="mt-2 text-sm text-slate-600">
              Track counselor workload and keep the pipeline moving.
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-3">
            <.link
              navigate={~p"/leads/dedupe"}
              class="inline-flex h-10 items-center rounded-full border border-slate-200 bg-white px-4 text-sm font-semibold text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
            >
              Review duplicates
            </.link>
            <div class="rounded-full border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600">
              Total leads: <span class="font-semibold text-slate-900">{@total_count}</span>
            </div>
          </div>
        </div>

        <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <.form for={@filter_form} id="lead-filters" phx-change="filter" phx-submit="filter">
            <div class="grid gap-4 md:grid-cols-[1.3fr_0.7fr_0.7fr_0.6fr_auto]">
              <div>
                <.input
                  field={@filter_form[:search]}
                  type="text"
                  label="Search"
                  placeholder="Name or phone number"
                />
              </div>
              <div>
                <.input
                  field={@filter_form[:status]}
                  type="select"
                  label="Status"
                  options={@status_options}
                />
              </div>
              <div :if={@show_counselor_filter}>
                <.input
                  field={@filter_form[:counselor_id]}
                  type="select"
                  label="Counselor"
                  options={[{"All counselors", ""} | Enum.map(@counselors, &{&1.full_name, &1.id})]}
                />
              </div>
              <div class="flex items-end">
                <div class="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
                  <.input
                    field={@filter_form[:include_merged]}
                    type="checkbox"
                    label="Include merged"
                    class="h-4 w-4 rounded border-slate-300 text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-200"
                  />
                </div>
              </div>
              <div class="flex items-end">
                <button
                  type="button"
                  phx-click="clear_filters"
                  class="inline-flex h-11 items-center justify-center rounded-full border border-slate-200 px-4 text-sm font-medium text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
                >
                  Clear filters
                </button>
              </div>
            </div>
          </.form>
        </div>

        <div class="rounded-3xl border border-slate-200 bg-white shadow-sm">
          <div
            id="lead-list"
            phx-update="stream"
            class="divide-y divide-slate-100"
          >
            <div
              id="lead-empty-state"
              class="hidden px-6 py-10 text-center text-sm text-slate-500 only:block"
            >
              No leads found for these filters.
            </div>
            <div
              :for={{id, lead} <- @streams.leads}
              id={id}
              class="flex flex-wrap items-center justify-between gap-4 px-6 py-4 transition hover:bg-slate-50"
            >
              <div>
                <div class="flex items-center gap-3">
                  <div class="h-10 w-10 rounded-full bg-slate-900 text-white grid place-items-center text-sm font-semibold">
                    {String.first(lead.student_name || "?")}
                  </div>
                  <div>
                    <p class="text-base font-semibold text-slate-900">{lead.student_name}</p>
                    <p class="text-sm text-slate-500">{lead.phone_number}</p>
                  </div>
                </div>
              </div>
              <div class="flex flex-wrap items-center gap-3 text-sm text-slate-600">
                <span class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-600">
                  {humanize_status(lead.status)}
                </span>
                <span class="text-xs text-slate-500">{lead.university && lead.university.name}</span>
                <span class="text-xs text-slate-500">
                  {lead.assigned_counselor && lead.assigned_counselor.full_name}
                </span>
                <.link
                  navigate={~p"/leads/#{lead.id}"}
                  class="inline-flex items-center gap-1 text-sm font-semibold text-slate-900 hover:text-slate-700"
                >
                  View <.icon name="hero-arrow-right-mini" class="size-4" />
                </.link>
              </div>
              <div :if={@can_assign} class="w-full pt-3 sm:w-auto sm:pt-0">
                <.form
                  :if={Map.has_key?(@assignment_forms, lead.id)}
                  for={@assignment_forms[lead.id]}
                  id={"assign-form-#{lead.id}"}
                  phx-submit="assign"
                  class="flex flex-wrap items-center gap-2"
                >
                  <.input field={@assignment_forms[lead.id][:lead_id]} type="hidden" />
                  <.input
                    field={@assignment_forms[lead.id][:counselor_id]}
                    type="select"
                    options={@counselor_options}
                  />
                  <button
                    type="submit"
                    class="inline-flex h-10 items-center rounded-full border border-slate-200 px-4 text-xs font-semibold text-slate-700 transition hover:border-slate-300 hover:text-slate-900"
                  >
                    Assign
                  </button>
                </.form>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between">
          <div class="text-sm text-slate-500">
            Page {@page} of {@total_pages}
          </div>
          <div class="flex items-center gap-2">
            <.link
              :if={@page_links.prev}
              patch={~p"/leads?#{@page_links.prev}"}
              class="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
            >
              <.icon name="hero-chevron-left-mini" class="size-4" /> Prev
            </.link>
            <.link
              :if={@page_links.next}
              patch={~p"/leads?#{@page_links.next}"}
              class="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
            >
              Next <.icon name="hero-chevron-right-mini" class="size-4" />
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
