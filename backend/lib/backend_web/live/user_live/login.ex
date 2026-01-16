defmodule BackendWeb.UserLive.Login do
  use BackendWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl">
        <div class="grid gap-8 lg:grid-cols-[1.1fr_0.9fr]">
          <div class="rounded-3xl border border-slate-200 bg-white/80 p-8 shadow-sm backdrop-blur">
            <p class="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
              KonCRM Console
            </p>
            <h1 class="display-text mt-4 text-3xl font-semibold text-slate-900 sm:text-4xl">
              Welcome back.
            </h1>
            <p class="mt-4 text-base text-slate-600">
              {if @current_scope,
                do: "Reauthenticate to keep sensitive settings secure.",
                else: "Sign in to access leads, imports, and counselor performance."}
            </p>
            <div class="mt-8 grid gap-4 sm:grid-cols-2">
              <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Secure</p>
                <p class="mt-2">Short-lived access tokens with refresh.</p>
              </div>
              <div class="rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Fast</p>
                <p class="mt-2">Live updates across imports and assignments.</p>
              </div>
            </div>
          </div>

          <div class="rounded-3xl border border-slate-200 bg-white p-8 shadow-lg">
            <h2 class="display-text text-xl font-semibold text-slate-900">Log in</h2>
            <p class="mt-2 text-sm text-slate-500">Use your KonCRM admin email to continue.</p>

            <.form
              for={@form}
              id="login_form_password"
              action={~p"/users/log-in"}
              phx-submit="submit_password"
              phx-trigger-action={@trigger_submit}
              class="mt-6 space-y-4"
            >
              <.input
                readonly={!!@current_scope}
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="email"
                required
                phx-mounted={JS.focus()}
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
                required
              />
              <.button class="w-full" name={@form[:remember_me].name} value="true">
                Log in and stay logged in <span aria-hidden="true">→</span>
              </.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "password" => ""}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
