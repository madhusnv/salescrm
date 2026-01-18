defmodule BackendWeb.Plugs.SecurityHeaders do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("content-security-policy", csp_policy())
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
  end

  defp csp_policy do
    "default-src 'self'; " <>
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " <>
      "style-src 'self' 'unsafe-inline'; " <>
      "img-src 'self' data: blob:; " <>
      "font-src 'self' data:; " <>
      "connect-src 'self' wss:; " <>
      "frame-ancestors 'none';"
  end
end
