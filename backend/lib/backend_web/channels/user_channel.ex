defmodule BackendWeb.UserChannel do
  use Phoenix.Channel

  @impl true
  def join("user:" <> user_id, _params, socket) do
    if String.to_integer(user_id) == socket.assigns.user_id do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "presence_state", %{status: "online"})
    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{message: "pong"}}, socket}
  end
end
