defmodule BackendWeb.Admin.RecordingLive.Index do
  use BackendWeb, :live_view

  alias Backend.Recordings

  on_mount({BackendWeb.UserAuth, :require_authenticated})

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Recordings")
     |> assign(:recordings, Recordings.list_recordings(scope))
     |> assign(:selected_recording, nil)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("play", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    recording = Recordings.get_recording!(scope, id)

    case Recordings.get_playback_url(recording) do
      {:ok, url} ->
        {:noreply, assign(socket, :selected_recording, %{recording: recording, url: url})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not load recording")}
    end
  end

  @impl true
  def handle_event("close_player", _params, socket) do
    {:noreply, assign(socket, :selected_recording, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
    <div class="mx-auto max-w-5xl space-y-6">
      <div>
        <p class="text-xs font-semibold uppercase tracking-widest text-slate-500">Admin</p>
        <h1 class="mt-2 text-2xl font-semibold text-slate-900">{@page_title}</h1>
        <p class="mt-1 text-sm text-slate-500">Browse and play call recordings</p>
      </div>

      <%= if @selected_recording do %>
        <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-slate-900">
                Recording from {@selected_recording.recording.phone_number || "Unknown"}
              </p>
              <p class="text-xs text-slate-500">
                {Calendar.strftime(@selected_recording.recording.recorded_at, "%b %d, %Y at %I:%M %p")}
              </p>
            </div>
            <button
              phx-click="close_player"
              class="text-slate-400 hover:text-slate-600"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>
          <audio
            controls
            class="mt-4 w-full"
            src={@selected_recording.url}
          >
            Your browser does not support audio playback.
          </audio>
        </div>
      <% end %>

      <div class="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-slate-100">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Phone Number
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Duration
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Recorded At
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                Consent
              </th>
              <th class="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wide text-slate-500">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={recording <- @recordings} class="hover:bg-slate-50">
              <td class="whitespace-nowrap px-6 py-4 text-sm font-medium text-slate-900">
                {recording.phone_number || "—"}
              </td>
              <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                {format_duration(recording.duration_seconds)}
              </td>
              <td class="whitespace-nowrap px-6 py-4 text-sm text-slate-600">
                {Calendar.strftime(recording.recorded_at, "%b %d, %Y %I:%M %p")}
              </td>
              <td class="whitespace-nowrap px-6 py-4">
                <span class={[
                  "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                  recording.consent_granted && "bg-emerald-100 text-emerald-700",
                  !recording.consent_granted && "bg-amber-100 text-amber-700"
                ]}>
                  {if recording.consent_granted, do: "Yes", else: "No"}
                </span>
              </td>
              <td class="whitespace-nowrap px-6 py-4 text-right text-sm">
                <button
                  phx-click="play"
                  phx-value-id={recording.id}
                  class="font-medium text-slate-600 hover:text-slate-900"
                >
                  <.icon name="hero-play" class="mr-1 inline size-4" /> Play
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <div :if={@recordings == []} class="px-6 py-12 text-center text-sm text-slate-500">
          No recordings found
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end

  defp format_duration(nil), do: "—"
  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
