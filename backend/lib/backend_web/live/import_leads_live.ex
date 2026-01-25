defmodule BackendWeb.ImportLeadsLive do
  use BackendWeb, :live_view

  on_mount({BackendWeb.UserAuth, :require_authenticated})
  on_mount({BackendWeb.RequirePermissionOnMount, "lead.import"})

  alias Backend.Imports
  alias Backend.Organizations

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    user = scope.user

    filters = %{"status" => "", "from" => "", "to" => "", "search" => ""}
    page = 1
    page_size = 10

    socket =
      socket
      |> assign(:universities, Organizations.list_universities(user.organization_id))
      |> assign(:branches, Organizations.list_branches(user.organization_id))
      |> assign(:selected_branch_id, user.branch_id)
      |> assign(:can_select_branch, scope.is_super_admin)
      |> assign(:selected_university_id, nil)
      |> assign(:import_job_id, nil)
      |> assign(:filters, filters)
      |> assign(:filter_form, to_form(filters, as: "filters"))
      |> assign(:page, page)
      |> assign(:page_size, page_size)
      |> assign(:total_count, Imports.count_import_jobs(user.organization_id, filters))
      |> assign(:jobs, Imports.list_import_jobs(user.organization_id, filters, page, page_size))
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    if connected?(socket) do
      _ = :timer.send_interval(8_000, self(), :refresh_jobs)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_scope.user
    filters = normalize_filters(params)
    page = parse_int(Map.get(params, "page", "1"), 1)
    page_size = parse_int(Map.get(params, "page_size", "10"), 10)
    total_count = Imports.count_import_jobs(user.organization_id, filters)
    jobs = Imports.list_import_jobs(user.organization_id, filters, page, page_size)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: "filters"))
     |> assign(:page, page)
     |> assign(:page_size, page_size)
     |> assign(:total_count, total_count)
     |> assign(:jobs, jobs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-5xl py-10">
        <div class="grid gap-10 lg:grid-cols-[1.1fr_0.9fr]">
          <section class="space-y-6">
            <div class="space-y-2">
              <p class="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
                Lead Imports
              </p>
              <h1 class="text-3xl font-semibold text-slate-900 sm:text-4xl">
                Import new leads with clarity
              </h1>
              <p class="text-base text-slate-600">
                Upload a CSV with student name and phone number, pick the university, and we will
                validate each row before it flows into the pipeline.
              </p>
            </div>

            <.form
              for={%{}}
              id="lead-import-form"
              phx-submit="import"
              phx-change="validate"
              class="rounded-3xl border border-slate-200 bg-white p-6 shadow-[0_20px_50px_-30px_rgba(15,23,42,0.35)]"
            >
              <div class="space-y-5">
                <.input
                  name="university_id"
                  id="lead_import_university"
                  type="select"
                  label="University"
                  value={@selected_university_id}
                  options={Enum.map(@universities, &{&1.name, &1.id})}
                  prompt="Select university"
                  required
                />

                <.input
                  :if={@can_select_branch}
                  name="branch_id"
                  id="lead_import_branch"
                  type="select"
                  label="Branch"
                  value={@selected_branch_id}
                  options={Enum.map(@branches, &{&1.name, &1.id})}
                  prompt="Select branch"
                  required
                />

                <div>
                  <label class="block text-xs font-semibold uppercase tracking-wide text-slate-500">
                    CSV file
                  </label>
                  <div class="mt-2 rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-6 text-center">
                    <.live_file_input
                      upload={@uploads.csv}
                      class="block w-full cursor-pointer text-sm text-slate-600 file:mr-4 file:rounded-full file:border-0 file:bg-slate-900 file:px-4 file:py-2 file:text-xs file:font-semibold file:text-white"
                    />
                    <p class="mt-3 text-xs text-slate-500">
                      Expected headers: <span class="font-semibold">student_name, phone_number</span>
                    </p>
                  </div>

                  <%= for err <- upload_errors(@uploads.csv) do %>
                    <p class="mt-2 text-xs text-red-600">{error_to_string(err)}</p>
                  <% end %>
                </div>

                <button
                  type="submit"
                  class="w-full rounded-2xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                >
                  Start import
                </button>
              </div>
            </.form>

            <div :if={@import_job_id} class="rounded-2xl border border-emerald-200 bg-emerald-50 p-4">
              <p class="text-sm font-semibold text-emerald-800">Import queued</p>
              <p class="text-xs text-emerald-700">Job ID: {@import_job_id}</p>
            </div>

            <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-slate-900">Recent imports</h2>
                <div class="flex items-center gap-2">
                  <.link
                    href={~p"/imports/leads/template"}
                    class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-600 transition hover:border-slate-400"
                  >
                    Download CSV template
                  </.link>
                  <button
                    type="button"
                    phx-click="clear_filters"
                    class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-600 transition hover:border-slate-400"
                  >
                    Clear filters
                  </button>
                  <button
                    type="button"
                    phx-click="refresh"
                    class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-600 transition hover:border-slate-400"
                  >
                    Refresh
                  </button>
                </div>
              </div>

              <.form
                for={@filter_form}
                id="import-filters"
                phx-change="filter"
                class="mt-4 grid gap-3 rounded-2xl border border-slate-100 bg-slate-50 p-4 sm:grid-cols-2 lg:grid-cols-4"
              >
                <.input
                  field={@filter_form[:status]}
                  type="select"
                  label="Status"
                  options={[
                    {"All", ""},
                    {"Pending", "pending"},
                    {"Processing", "processing"},
                    {"Completed", "completed"},
                    {"Failed", "failed"}
                  ]}
                />
                <.input field={@filter_form[:from]} type="date" label="From date" />
                <.input field={@filter_form[:to]} type="date" label="To date" />
                <.input field={@filter_form[:search]} type="text" label="Search" />
              </.form>

              <div :if={@jobs == []} class="mt-4 text-sm text-slate-500">
                No imports yet.
              </div>

              <div :if={@jobs != []} class="mt-4 space-y-3">
                <%= for job <- @jobs do %>
                  <div class="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-100 bg-slate-50 px-4 py-3">
                    <div>
                      <p class="text-sm font-semibold text-slate-800">
                        {job.university && job.university.name}
                      </p>
                      <p class="text-xs text-slate-500">
                        {job.original_filename || "CSV upload"} · {format_status(job.status)}
                      </p>
                    </div>
                    <div class="flex items-center gap-4 text-xs text-slate-500">
                      <span>{job.valid_rows} valid</span>
                      <span>{job.invalid_rows} invalid</span>
                      <.link
                        navigate={~p"/imports/leads/#{job.id}"}
                        class="rounded-full bg-slate-900 px-3 py-1 text-xs font-semibold text-white transition hover:bg-slate-800"
                      >
                        View
                      </.link>
                    </div>
                  </div>
                <% end %>
              </div>

              <div
                :if={@total_count > 0}
                class="mt-6 flex flex-wrap items-center justify-between gap-3 text-xs text-slate-500"
              >
                <span>
                  Showing {range_start(@page, @page_size)}-{range_end(@page, @page_size, @total_count)} of {@total_count}
                </span>
                <div class="flex items-center gap-2">
                  <button
                    type="button"
                    phx-click="page_prev"
                    class="rounded-full border border-slate-200 px-3 py-1 font-semibold text-slate-600 transition hover:border-slate-400 disabled:opacity-50"
                    disabled={@page <= 1}
                  >
                    Prev
                  </button>
                  <span class="text-slate-600">Page {@page}</span>
                  <button
                    type="button"
                    phx-click="page_next"
                    class="rounded-full border border-slate-200 px-3 py-1 font-semibold text-slate-600 transition hover:border-slate-400 disabled:opacity-50"
                    disabled={@page * @page_size >= @total_count}
                  >
                    Next
                  </button>
                </div>
              </div>
            </div>
          </section>

          <aside class="space-y-6">
            <div class="rounded-3xl bg-slate-900 p-6 text-white shadow-lg">
              <h2 class="text-lg font-semibold">Before you upload</h2>
              <ul class="mt-4 space-y-3 text-sm text-slate-200">
                <li>One university per CSV file.</li>
                <li>Phone numbers are normalized to 10 digits.</li>
                <li>Invalid rows stay visible for review.</li>
              </ul>
            </div>
            <div class="rounded-3xl border border-slate-200 bg-white p-6">
              <h3 class="text-sm font-semibold text-slate-800">What happens next</h3>
              <p class="mt-3 text-sm text-slate-600">
                We validate each row, flag duplicates in the next sprint, and queue assignments
                based on university rules.
              </p>
            </div>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", params, socket) do
    university_id =
      params
      |> Map.get("university_id", socket.assigns.selected_university_id)
      |> normalize_select_id()

    branch_id =
      params
      |> Map.get("branch_id", socket.assigns.selected_branch_id)
      |> normalize_select_id()

    {:noreply,
     socket
     |> assign(:selected_university_id, university_id)
     |> assign(:selected_branch_id, branch_id)}
  end

  def handle_event("import", %{"university_id" => university_id} = params, socket) do
    scope = socket.assigns.current_scope
    user = scope.user
    branch_id = resolve_branch_id(params, scope)

    case consume_uploaded_entries(socket, :csv, fn %{path: path}, entry ->
           csv_content = File.read!(path)

           attrs = %{
             organization_id: user.organization_id,
             branch_id: branch_id,
             university_id: String.to_integer(university_id),
             created_by_user_id: user.id,
             original_filename: entry.client_name
           }

           Imports.enqueue_leads_import(attrs, csv_content)
         end) do
      [{:ok, %Backend.Imports.ImportJob{id: job_id}}] ->
        {:noreply,
         socket
         |> assign(:import_job_id, job_id)
         |> assign(
           :total_count,
           Imports.count_import_jobs(user.organization_id, socket.assigns.filters)
         )
         |> assign(
           :jobs,
           Imports.list_import_jobs(
             user.organization_id,
             socket.assigns.filters,
             socket.assigns.page,
             socket.assigns.page_size
           )
         )}

      # Handle case where job is returned directly (not wrapped in {:ok, _})
      [%Backend.Imports.ImportJob{id: job_id}] ->
        {:noreply,
         socket
         |> assign(:import_job_id, job_id)
         |> assign(
           :total_count,
           Imports.count_import_jobs(user.organization_id, socket.assigns.filters)
         )
         |> assign(
           :jobs,
           Imports.list_import_jobs(
             user.organization_id,
             socket.assigns.filters,
             socket.assigns.page,
             socket.assigns.page_size
           )
         )}

      [{:error, reason}] ->
        {:noreply, put_flash(socket, :error, "Import failed: #{inspect(reason)}")}

      [] ->
        {:noreply, put_flash(socket, :error, "Please select a CSV file.")}
    end
  end

  def handle_event("refresh", _params, socket) do
    user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(
       :total_count,
       Imports.count_import_jobs(user.organization_id, socket.assigns.filters)
     )
     |> assign(
       :jobs,
       Imports.list_import_jobs(
         user.organization_id,
         socket.assigns.filters,
         socket.assigns.page,
         socket.assigns.page_size
       )
     )}
  end

  def handle_event("filter", %{"filters" => filters}, socket) do
    cleaned = drop_empty(filters)
    params = Map.put(cleaned, "page", "1")
    {:noreply, push_patch(socket, to: ~p"/imports/leads?#{params}")}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/imports/leads")}
  end

  def handle_event("page_prev", _params, socket) do
    page = max(socket.assigns.page - 1, 1)
    params = Map.merge(socket.assigns.filters, %{"page" => to_string(page)})
    {:noreply, push_patch(socket, to: ~p"/imports/leads?#{params}")}
  end

  def handle_event("page_next", _params, socket) do
    max_page = ceil_div(socket.assigns.total_count, socket.assigns.page_size)
    page = min(socket.assigns.page + 1, max_page)
    params = Map.merge(socket.assigns.filters, %{"page" => to_string(page)})
    {:noreply, push_patch(socket, to: ~p"/imports/leads?#{params}")}
  end

  defp resolve_branch_id(params, scope) do
    branch_id = Map.get(params, "branch_id")

    cond do
      scope.is_super_admin and is_binary(branch_id) and branch_id != "" ->
        String.to_integer(branch_id)

      true ->
        scope.branch_id
    end
  end

  defp normalize_select_id(nil), do: nil
  defp normalize_select_id(""), do: nil

  defp normalize_select_id(value) when is_binary(value) do
    String.to_integer(value)
  end

  defp normalize_select_id(value), do: value

  @impl true
  def handle_info(:refresh_jobs, socket) do
    user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(
       :total_count,
       Imports.count_import_jobs(user.organization_id, socket.assigns.filters)
     )
     |> assign(
       :jobs,
       Imports.list_import_jobs(
         user.organization_id,
         socket.assigns.filters,
         socket.assigns.page,
         socket.assigns.page_size
       )
     )}
  end

  defp error_to_string(:too_large), do: "File is too large."
  defp error_to_string(:too_many_files), do: "Only one CSV file is allowed."
  defp error_to_string(:not_accepted), do: "Unsupported file type."

  defp format_status(status) when is_atom(status), do: Atom.to_string(status)
  defp format_status(status), do: to_string(status)

  defp normalize_filters(params) do
    %{
      "status" => Map.get(params, "status", ""),
      "from" => Map.get(params, "from", ""),
      "to" => Map.get(params, "to", ""),
      "search" => Map.get(params, "search", "")
    }
  end

  defp drop_empty(filters) do
    filters
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp parse_int(value, default) do
    case Integer.parse(to_string(value)) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp range_start(page, page_size), do: (page - 1) * page_size + 1

  defp range_end(page, page_size, total) do
    min(page * page_size, total)
  end

  defp ceil_div(value, divisor) when divisor > 0 do
    div(value + divisor - 1, divisor)
  end
end
