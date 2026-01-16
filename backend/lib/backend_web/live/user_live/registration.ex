defmodule BackendWeb.UserLive.Registration do
  use BackendWeb, :live_view

  alias Backend.Accounts
  alias Backend.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="grid gap-8 lg:grid-cols-[1fr_1fr]">
          <div class="rounded-3xl border border-slate-200 bg-white/80 p-8 shadow-sm backdrop-blur">
            <p class="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
              New account
            </p>
            <h1 class="display-text mt-4 text-3xl font-semibold text-slate-900 sm:text-4xl">
              Set up a counselor workspace.
            </h1>
            <p class="mt-4 text-base text-slate-600">
              Get access to lead imports, assignment rules, and performance monitoring in minutes.
            </p>
            <p class="mt-6 text-sm text-slate-500">
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-slate-900 underline-offset-4 hover:underline">
                Log in
              </.link>
              to your account.
            </p>
          </div>

          <div class="rounded-3xl border border-slate-200 bg-white p-8 shadow-lg">
            <h2 class="display-text text-xl font-semibold text-slate-900">Register</h2>
            <p class="mt-2 text-sm text-slate-500">Use your official email to create an account.</p>

            <.form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              class="mt-6 space-y-4"
            >
              <.input
                field={@form[:full_name]}
                type="text"
                label="Full name"
                autocomplete="name"
                required
                phx-mounted={JS.focus()}
              />

              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                required
              />

              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="new-password"
                required
              />

              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm password"
                autocomplete="new-password"
              />

              <.button phx-disable-with="Creating account..." class="w-full">
                Create an account
              </.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: BackendWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    defaults = Accounts.registration_defaults() |> stringify_defaults()

    changeset =
      Accounts.change_user_registration(%User{}, defaults,
        validate_unique: false,
        hash_password: false
      )

    {:ok, socket |> assign(:defaults, defaults) |> assign_form(changeset),
     temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(merge_defaults(user_params, socket.assigns.defaults)) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Account created for #{user.email}. You can log in now."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(
        %User{},
        merge_defaults(user_params, socket.assigns.defaults),
        validate_unique: false,
        hash_password: false
      )

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  defp merge_defaults(user_params, defaults) do
    Map.merge(defaults, user_params)
  end

  defp stringify_defaults(defaults) do
    defaults
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end
end
