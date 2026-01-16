defmodule BackendWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use BackendWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates("layouts/*")

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  )

  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-slate-50">
      <%!-- Sidebar --%>
      <aside
        :if={@current_scope}
        class="fixed inset-y-0 left-0 z-50 hidden w-64 flex-col border-r border-slate-200 bg-white lg:flex"
      >
        <div class="flex h-16 items-center gap-3 border-b border-slate-100 px-6">
          <span class="grid h-9 w-9 place-items-center rounded-xl bg-slate-900 text-sm font-bold text-white">
            KC
          </span>
          <div>
            <p class="text-sm font-semibold text-slate-900">KonCRM</p>
            <p class="text-[10px] text-slate-400">Admin Console</p>
          </div>
        </div>

        <nav class="flex-1 space-y-1 overflow-y-auto px-3 py-4">
          <p class="mb-2 px-3 text-[10px] font-semibold uppercase tracking-widest text-slate-400">
            Main
          </p>
          <.sidebar_link href={~p"/dashboard"} icon="hero-squares-2x2">Dashboard</.sidebar_link>
          <.sidebar_link href={~p"/leads"} icon="hero-users">Leads</.sidebar_link>
          <.sidebar_link href={~p"/imports/leads"} icon="hero-arrow-up-tray">Imports</.sidebar_link>
          <.sidebar_link href={~p"/assignments/rules"} icon="hero-adjustments-horizontal">
            Assignment Rules
          </.sidebar_link>

          <p class="mb-2 mt-6 px-3 text-[10px] font-semibold uppercase tracking-widest text-slate-400">
            Admin
          </p>
          <.sidebar_link href={~p"/admin/users"} icon="hero-user-group">Users</.sidebar_link>
          <.sidebar_link href={~p"/admin/branches"} icon="hero-building-office-2">Branches</.sidebar_link>
          <.sidebar_link href={~p"/admin/universities"} icon="hero-academic-cap">Universities</.sidebar_link>
          <.sidebar_link href={~p"/admin/recordings"} icon="hero-microphone">Recordings</.sidebar_link>
          <.sidebar_link href={~p"/admin/audit"} icon="hero-document-magnifying-glass">Audit Log</.sidebar_link>
          <.sidebar_link href={~p"/admin/organization"} icon="hero-cog-6-tooth">Settings</.sidebar_link>
        </nav>

        <div class="border-t border-slate-100 p-4">
          <div class="flex items-center gap-3">
            <div class="grid h-9 w-9 place-items-center rounded-full bg-slate-100 text-xs font-semibold text-slate-600">
              {String.first(@current_scope.user.email) |> String.upcase()}
            </div>
            <div class="flex-1 truncate">
              <p class="truncate text-sm font-medium text-slate-900">
                {@current_scope.user.full_name || @current_scope.user.email}
              </p>
              <p class="truncate text-xs text-slate-500">{@current_scope.user.email}</p>
            </div>
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <div class={["flex-1", @current_scope && "lg:ml-64"]}>
        <header class="sticky top-0 z-40 border-b border-slate-200/60 bg-white/90 backdrop-blur">
          <div class="flex h-16 items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
            <a
              :if={!@current_scope}
              href={~p"/"}
              class="flex items-center gap-3"
            >
              <span class="grid h-10 w-10 place-items-center rounded-2xl bg-slate-900 text-sm font-semibold text-white">
                KC
              </span>
              <div>
                <p class="text-base font-semibold text-slate-900">KonCRM</p>
                <p class="text-xs text-slate-500">Counselor Console</p>
              </div>
            </a>

            <%!-- Mobile nav toggle placeholder --%>
            <div :if={@current_scope} class="lg:hidden">
              <span class="text-sm font-semibold text-slate-600">KonCRM</span>
            </div>

            <div class="flex items-center gap-3">
              <.link
                :if={@current_scope}
                href={~p"/users/settings"}
                class="hidden h-9 items-center rounded-full border border-slate-200 px-4 text-xs font-semibold text-slate-600 transition hover:border-slate-300 sm:inline-flex"
              >
                Settings
              </.link>
              <.link
                :if={@current_scope}
                href={~p"/users/log-out"}
                method="delete"
                class="inline-flex h-9 items-center rounded-full border border-slate-200 px-4 text-xs font-semibold text-slate-600 transition hover:border-slate-300"
              >
                Log out
              </.link>
              <.link
                :if={!@current_scope}
                href={~p"/users/log-in"}
                class="inline-flex h-9 items-center rounded-full bg-slate-900 px-4 text-xs font-semibold text-white transition hover:bg-slate-800"
              >
                Log in
              </.link>
              <.theme_toggle />
            </div>
          </div>
        </header>

        <main class="p-4 sm:p-6 lg:p-8">
          <div class="animate-rise">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900"
    >
      <.icon name={@icon} class="size-5" />
      <span>{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="fixed right-4 top-4 z-50 flex w-[min(420px,90vw)] flex-col gap-3"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex items-center rounded-full border border-slate-200 bg-white px-1 py-1 shadow-sm">
      <div class="absolute left-[1.55rem] h-7 w-7 rounded-full bg-slate-900/10 transition-[left] duration-200 [[data-theme=light]_&]:left-1 [[data-theme=dark]_&]:left-[3.15rem]" />

      <button
        class="relative flex h-7 w-7 items-center justify-center text-slate-600 transition hover:text-slate-900"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="relative flex h-7 w-7 items-center justify-center text-slate-600 transition hover:text-slate-900"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="relative flex h-7 w-7 items-center justify-center text-slate-600 transition hover:text-slate-900"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
