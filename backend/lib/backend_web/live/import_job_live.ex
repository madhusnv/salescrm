defmodule BackendWeb.ImportJobLive do
  use BackendWeb, :live_view

  on_mount({BackendWeb.UserAuth, :require_authenticated})
  on_mount({BackendWeb.RequirePermissionOnMount, "lead.import"})

  alias Backend.Access.Policy
  alias Backend.Accounts
  alias Backend.Imports

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job = Imports.get_import_job!(id)
    scope = socket.assigns.current_scope
    invalid_rows = Imports.list_invalid_rows(job.id, 50)
    assignment_failures = Imports.list_assignment_failures(job.id, 50)
    unassigned_rows = Imports.list_unassigned_rows(job.id, 50)
    unassigned_count = Imports.count_unassigned_rows(job.id)
    counselors = Accounts.list_counselors(job.organization_id, job.branch_id)
    can_assign = Policy.can_assign_leads?(scope)

    {:ok,
     assign(socket,
       job: job,
       invalid_rows: invalid_rows,
       assignment_failures: assignment_failures,
       unassigned_rows: unassigned_rows,
       unassigned_count: unassigned_count,
       counselors: counselors,
       can_assign: can_assign,
       assignment_form: to_form(%{"counselor_id" => ""}, as: :assignment)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-6xl py-10">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
              Import Details
            </p>
            <h1 class="text-3xl font-semibold text-slate-900">Lead import #{@job.id}</h1>
            <p class="mt-2 text-sm text-slate-600">
              University: {@job.university && @job.university.name} · Status: {format_status(
                @job.status
              )}
            </p>
          </div>
          <.link
            navigate={~p"/imports/leads"}
            class="rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:border-slate-400"
          >
            Back to imports
          </.link>
        </div>

        <div class="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <%= for metric <- metrics(@job) do %>
            <div class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
              <p class="text-xs uppercase tracking-[0.2em] text-slate-500">{metric.label}</p>
              <p class="mt-2 text-2xl font-semibold text-slate-900">{metric.value}</p>
            </div>
          <% end %>
        </div>

        <div class="mt-6 rounded-3xl border border-indigo-200 bg-indigo-50 p-6 shadow-sm">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-semibold text-indigo-900">Dedupe summary</h2>
              <p class="text-sm text-indigo-700">Soft matches are queued for review.</p>
            </div>
            <.link
              navigate={~p"/leads/dedupe"}
              class="rounded-full border border-indigo-200 bg-white px-4 py-2 text-xs font-semibold text-indigo-700 transition hover:border-indigo-300 hover:text-indigo-900"
            >
              Review duplicates
            </.link>
          </div>
          <div class="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <%= for metric <- dedupe_metrics(@job) do %>
              <div class="rounded-2xl border border-indigo-100 bg-white p-4">
                <p class="text-xs uppercase tracking-[0.2em] text-indigo-500">{metric.label}</p>
                <p class="mt-2 text-xl font-semibold text-indigo-900">{metric.value}</p>
              </div>
            <% end %>
          </div>
        </div>

        <div class="mt-10 grid gap-6 lg:grid-cols-2">
          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 class="text-lg font-semibold text-slate-900">Assignment queue</h2>
                <p class="text-sm text-slate-600">
                  {if @unassigned_count == 0,
                    do: "No unassigned rows waiting.",
                    else: "#{@unassigned_count} rows need a counselor."}
                </p>
              </div>
              <div class="rounded-full border border-slate-200 bg-white px-3 py-1 text-xs font-semibold text-slate-600">
                Unassigned: {@unassigned_count}
              </div>
            </div>

            <.form
              :if={@can_assign}
              for={@assignment_form}
              id="bulk-assign-form"
              phx-submit="bulk_assign"
              class="mt-4 grid gap-3 sm:grid-cols-[1fr_auto]"
            >
              <.input
                field={@assignment_form[:counselor_id]}
                type="select"
                label="Assign all to counselor"
                options={[{"Select counselor", ""} | Enum.map(@counselors, &{&1.full_name, &1.id})]}
              />
              <button
                type="submit"
                class="inline-flex h-11 items-center justify-center rounded-full bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
              >
                Assign all
              </button>
            </.form>

            <p :if={!@can_assign} class="mt-4 text-sm text-slate-500">
              You do not have permission to assign leads.
            </p>

            <div
              :if={@unassigned_rows == []}
              class="mt-6 rounded-2xl bg-slate-50 p-6 text-sm text-slate-600"
            >
              No pending or failed rows to assign.
            </div>

            <div
              :if={@unassigned_rows != []}
              class="mt-6 overflow-hidden rounded-2xl border border-slate-200"
            >
              <table class="w-full text-left text-sm text-slate-700">
                <thead class="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th class="px-4 py-3">Row</th>
                    <th class="px-4 py-3">Student name</th>
                    <th class="px-4 py-3">Phone</th>
                    <th class="px-4 py-3">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for row <- @unassigned_rows do %>
                    <tr class="border-t border-slate-100">
                      <td class="px-4 py-3 font-semibold text-slate-900">{row.row_number}</td>
                      <td class="px-4 py-3">{row.student_name}</td>
                      <td class="px-4 py-3">{row.phone_number}</td>
                      <td class="px-4 py-3 text-slate-500">
                        {row.assignment_status}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-slate-900">Invalid rows (first 50)</h2>
              <span class="text-xs text-slate-500">Row # · Errors</span>
            </div>

            <div
              :if={@invalid_rows == []}
              class="mt-6 rounded-2xl bg-slate-50 p-6 text-sm text-slate-600"
            >
              No invalid rows detected in this import.
            </div>

            <div
              :if={@invalid_rows != []}
              class="mt-6 overflow-hidden rounded-2xl border border-slate-200"
            >
              <table class="w-full text-left text-sm text-slate-700">
                <thead class="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th class="px-4 py-3">Row</th>
                    <th class="px-4 py-3">Student name</th>
                    <th class="px-4 py-3">Phone</th>
                    <th class="px-4 py-3">Errors</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for row <- @invalid_rows do %>
                    <tr class="border-t border-slate-100">
                      <td class="px-4 py-3 font-semibold text-slate-900">{row.row_number}</td>
                      <td class="px-4 py-3">{row.student_name}</td>
                      <td class="px-4 py-3">{row.phone_number}</td>
                      <td class="px-4 py-3 text-rose-600">
                        {format_errors(row.errors)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <div class="rounded-3xl border border-amber-200 bg-amber-50 p-6 shadow-sm">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-amber-900">Assignment failures (first 50)</h2>
              <span class="text-xs text-amber-800">Row # · Reason</span>
            </div>

            <div
              :if={@assignment_failures == []}
              class="mt-6 rounded-2xl bg-white/70 p-6 text-sm text-amber-800"
            >
              No assignment failures for this import.
            </div>

            <div
              :if={@assignment_failures != []}
              class="mt-6 overflow-hidden rounded-2xl border border-amber-200 bg-white"
            >
              <table class="w-full text-left text-sm text-amber-900">
                <thead class="bg-amber-100 text-xs uppercase tracking-wide text-amber-800">
                  <tr>
                    <th class="px-4 py-3">Row</th>
                    <th class="px-4 py-3">Student name</th>
                    <th class="px-4 py-3">Phone</th>
                    <th class="px-4 py-3">Reason</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for row <- @assignment_failures do %>
                    <tr class="border-t border-amber-100">
                      <td class="px-4 py-3 font-semibold">{row.row_number}</td>
                      <td class="px-4 py-3">{row.student_name}</td>
                      <td class="px-4 py-3">{row.phone_number}</td>
                      <td class="px-4 py-3">{format_errors(row.assignment_error)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("bulk_assign", %{"assignment" => %{"counselor_id" => counselor_id}}, socket) do
    if socket.assigns.can_assign do
      case parse_id(counselor_id) do
        {:ok, id} ->
          case Imports.assign_rows_to_counselor(socket.assigns.job, id) do
            {:ok, count} ->
              job = Imports.get_import_job!(socket.assigns.job.id)

              {:noreply,
               socket
               |> assign(:job, job)
               |> assign(:unassigned_rows, Imports.list_unassigned_rows(job.id, 50))
               |> assign(:unassigned_count, Imports.count_unassigned_rows(job.id))
               |> assign(:assignment_failures, Imports.list_assignment_failures(job.id, 50))
               |> put_flash(:info, "Assigned #{count} rows.")}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Assignment failed: #{inspect(reason)}")}
          end

        :error ->
          {:noreply, put_flash(socket, :error, "Select a counselor before assigning.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have permission to assign leads.")}
    end
  end

  defp metrics(job) do
    [
      %{label: "Total rows", value: job.total_rows},
      %{label: "Valid rows", value: job.valid_rows},
      %{label: "Invalid rows", value: job.invalid_rows},
      %{label: "Inserted", value: job.inserted_rows}
    ]
  end

  defp dedupe_metrics(job) do
    summary = job.error_summary || %{}

    [
      %{label: "Hard duplicates", value: Map.get(summary, "dedupe_hard", 0)},
      %{label: "Soft matches", value: Map.get(summary, "dedupe_soft", 0)},
      %{label: "Candidates created", value: Map.get(summary, "dedupe_candidates", 0)},
      %{label: "Leads created", value: Map.get(summary, "leads_created", 0)}
    ]
  end

  defp format_errors(errors) when is_map(errors) do
    errors
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join(", ")
  end

  defp format_errors(_), do: ""

  defp format_status(status) when is_atom(status), do: Atom.to_string(status)
  defp format_status(status), do: to_string(status)

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, _} -> {:ok, id}
      :error -> :error
    end
  end

  defp parse_id(_), do: :error
end
