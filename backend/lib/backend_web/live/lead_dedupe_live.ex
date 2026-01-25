defmodule BackendWeb.LeadDedupeLive do
  use BackendWeb, :live_view

  alias Backend.Leads
  alias Backend.Leads.LeadDedupeCandidate

  on_mount({BackendWeb.RequirePermissionOnMount, Backend.Access.Permissions.leads_update()})

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:filters, default_filters())
      |> assign(:page, 1)
      |> assign(:page_size, @page_size)
      |> assign(:total_count, 0)
      |> assign(:total_pages, 1)
      |> assign(:page_links, %{prev: nil, next: nil})
      |> assign(:filter_form, to_form(default_filters(), as: :filters))
      |> assign(:status_options, status_options())
      |> assign(:match_type_options, match_type_options())
      |> stream(:candidates, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_page(params)
    filters = normalize_filters(params)

    candidates =
      Leads.list_dedupe_candidates(
        socket.assigns.current_scope,
        filters,
        page,
        socket.assigns.page_size
      )

    total_count = Leads.count_dedupe_candidates(socket.assigns.current_scope, filters)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:page, page)
      |> assign(:total_count, total_count)
      |> assign(:filter_form, to_form(filters, as: :filters))
      |> assign_pagination(filters, page, total_count)
      |> stream(:candidates, candidates, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    params = filters |> Map.put("page", "1") |> clean_params()
    {:noreply, push_patch(socket, to: ~p"/leads/dedupe?#{params}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/leads/dedupe")}
  end

  def handle_event("merge", %{"id" => id}, socket) do
    candidate = Leads.get_dedupe_candidate!(socket.assigns.current_scope, id)

    case Leads.merge_candidate(socket.assigns.current_scope, candidate) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lead merged successfully.")
         |> refresh_candidates()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Unable to merge: #{inspect(reason)}")}
    end
  end

  def handle_event("ignore", %{"id" => id}, socket) do
    candidate = Leads.get_dedupe_candidate!(socket.assigns.current_scope, id)

    case Leads.ignore_candidate(socket.assigns.current_scope, candidate) do
      {:ok, _candidate} ->
        {:noreply,
         socket
         |> put_flash(:info, "Duplicate ignored.")
         |> refresh_candidates()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Unable to ignore: #{inspect(reason)}")}
    end
  end

  defp refresh_candidates(socket) do
    candidates =
      Leads.list_dedupe_candidates(
        socket.assigns.current_scope,
        socket.assigns.filters,
        socket.assigns.page,
        socket.assigns.page_size
      )

    total_count =
      Leads.count_dedupe_candidates(socket.assigns.current_scope, socket.assigns.filters)

    socket
    |> assign(:total_count, total_count)
    |> assign_pagination(socket.assigns.filters, socket.assigns.page, total_count)
    |> stream(:candidates, candidates, reset: true)
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
    |> Map.merge(Map.take(params, ["status", "match_type"]))
  end

  defp default_filters do
    %{"status" => "", "match_type" => ""}
  end

  defp status_options do
    [
      {"All statuses", ""}
      | Enum.map(LeadDedupeCandidate.statuses(), &{humanize(&1), Atom.to_string(&1)})
    ]
  end

  defp match_type_options do
    [
      {"All match types", ""}
      | Enum.map(LeadDedupeCandidate.match_types(), &{humanize(&1), Atom.to_string(&1)})
    ]
  end

  defp humanize(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> to_ist()
    |> Calendar.strftime("%d %b %Y, %I:%M %p")
  end

  defp to_ist(%DateTime{} = datetime) do
    DateTime.add(datetime, 19_800, :second)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-6">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 class="text-3xl font-semibold text-slate-900">Duplicate review</h1>
            <p class="mt-2 text-sm text-slate-600">
              Review soft matches and resolve which lead to keep.
            </p>
          </div>
          <div class="rounded-full border border-slate-200 bg-white px-4 py-2 text-sm text-slate-600">
            Results: <span class="font-semibold text-slate-900">{@total_count}</span>
          </div>
        </div>

        <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <.form for={@filter_form} id="dedupe-filters" phx-change="filter" phx-submit="filter">
            <div class="grid gap-4 md:grid-cols-[1fr_1fr_auto]">
              <div>
                <.input
                  field={@filter_form[:status]}
                  type="select"
                  label="Status"
                  options={@status_options}
                />
              </div>
              <div>
                <.input
                  field={@filter_form[:match_type]}
                  type="select"
                  label="Match type"
                  options={@match_type_options}
                />
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
          <div id="dedupe-list" phx-update="stream" class="divide-y divide-slate-100">
            <div class="hidden px-6 py-10 text-center text-sm text-slate-500 only:block">
              No duplicates waiting for review.
            </div>
            <div
              :for={{id, candidate} <- @streams.candidates}
              id={id}
              class="grid gap-4 px-6 py-5 md:grid-cols-[1.2fr_1.2fr_0.8fr]"
            >
              <div class="space-y-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">New lead</p>
                <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4">
                  <p class="text-base font-semibold text-slate-900">{candidate.lead.student_name}</p>
                  <p class="text-sm text-slate-600">{candidate.lead.phone_number}</p>
                  <p class="mt-2 text-xs text-slate-500">
                    Status: {humanize(candidate.lead.status)}
                  </p>
                  <p class="text-xs text-slate-500">
                    Created: {format_datetime(candidate.lead.inserted_at)}
                  </p>
                </div>
              </div>

              <div class="space-y-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Matched lead
                </p>
                <div class="rounded-2xl border border-slate-200 bg-white p-4">
                  <p class="text-base font-semibold text-slate-900">
                    {candidate.matched_lead.student_name}
                  </p>
                  <p class="text-sm text-slate-600">{candidate.matched_lead.phone_number}</p>
                  <p class="mt-2 text-xs text-slate-500">
                    Status: {humanize(candidate.matched_lead.status)}
                  </p>
                  <p class="text-xs text-slate-500">
                    Created: {format_datetime(candidate.matched_lead.inserted_at)}
                  </p>
                </div>
              </div>

              <div class="flex flex-col justify-between gap-3">
                <div>
                  <span class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-600">
                    {humanize(candidate.match_type)}
                  </span>
                  <span class="ml-2 rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-600">
                    {humanize(candidate.status)}
                  </span>
                </div>
                <div class="flex flex-wrap items-center gap-2">
                  <.link
                    navigate={~p"/leads/#{candidate.lead_id}"}
                    class="text-xs font-semibold text-slate-700 hover:text-slate-900"
                  >
                    View new
                  </.link>
                  <.link
                    navigate={~p"/leads/#{candidate.matched_lead_id}"}
                    class="text-xs font-semibold text-slate-700 hover:text-slate-900"
                  >
                    View matched
                  </.link>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button
                    type="button"
                    phx-click="merge"
                    phx-value-id={candidate.id}
                    phx-confirm="Merge this lead into the matched lead?"
                    class="inline-flex h-10 items-center rounded-full bg-slate-900 px-4 text-xs font-semibold text-white transition hover:bg-slate-800"
                    disabled={candidate.status != :pending}
                  >
                    Merge
                  </button>
                  <button
                    type="button"
                    phx-click="ignore"
                    phx-value-id={candidate.id}
                    phx-confirm="Ignore this duplicate?"
                    class="inline-flex h-10 items-center rounded-full border border-slate-200 px-4 text-xs font-semibold text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
                    disabled={candidate.status != :pending}
                  >
                    Ignore
                  </button>
                </div>
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
              patch={~p"/leads/dedupe?#{@page_links.prev}"}
              class="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-600 transition hover:border-slate-300 hover:text-slate-900"
            >
              <.icon name="hero-chevron-left-mini" class="size-4" /> Prev
            </.link>
            <.link
              :if={@page_links.next}
              patch={~p"/leads/dedupe?#{@page_links.next}"}
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
