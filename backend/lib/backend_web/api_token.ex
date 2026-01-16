defmodule BackendWeb.ApiToken do
  @access_token_ttl_seconds 30 * 60
  @access_token_salt "user_access"

  def sign_access_token(user) do
    Phoenix.Token.sign(BackendWeb.Endpoint, @access_token_salt, %{user_id: user.id})
  end

  def verify_access_token(token) do
    Phoenix.Token.verify(BackendWeb.Endpoint, @access_token_salt, token,
      max_age: @access_token_ttl_seconds
    )
  end

  def access_token_ttl_seconds, do: @access_token_ttl_seconds
end
