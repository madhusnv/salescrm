defmodule BackendWeb.UserSocket do
  use Phoenix.Socket

  channel "user:*", BackendWeb.UserChannel

  require Logger

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case BackendWeb.ApiToken.verify_access_token(token) do
      {:ok, %{user_id: user_id}} ->
        Logger.debug("UserSocket connected for user_id=#{user_id}")
        {:ok, assign(socket, :user_id, user_id)}

      {:error, reason} ->
        Logger.warning("UserSocket connection failed: #{inspect(reason)}")
        :error
    end
  end

  def connect(params, _socket, _connect_info) do
    Logger.warning("UserSocket connection failed: missing token, params=#{inspect(params)}")
    :error
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
