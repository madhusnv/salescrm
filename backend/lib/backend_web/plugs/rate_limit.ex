defmodule BackendWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug using Hammer.

  Supports both JSON API and browser (HTML) responses.

  ## Options

    * `:limit` - Maximum requests allowed in window (default: 5)
    * `:window_ms` - Time window in milliseconds (default: 60_000)
    * `:key_prefix` - Prefix for rate limit key (default: "rate_limit")
    * `:format` - Response format, `:json` or `:html` (default: `:json`)
    * `:redirect_to` - Path to redirect on rate limit (only for :html format)

  ## Examples

      # API rate limiting
      plug BackendWeb.Plugs.RateLimit,
           limit: 5, window_ms: 60_000, key_prefix: "login"

      # Browser rate limiting with redirect
      plug BackendWeb.Plugs.RateLimit,
           limit: 5, window_ms: 60_000, key_prefix: "browser_login",
           format: :html, redirect_to: "/users/log-in"
  """

  import Plug.Conn

  @default_limit 5
  @default_window_ms 60_000

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, @default_limit),
      window_ms: Keyword.get(opts, :window_ms, @default_window_ms),
      key_prefix: Keyword.get(opts, :key_prefix, "rate_limit"),
      format: Keyword.get(opts, :format, :json),
      redirect_to: Keyword.get(opts, :redirect_to)
    }
  end

  def call(conn, opts) do
    if rate_limiting_enabled?() do
      key = build_key(conn, opts.key_prefix)

      case check_rate(key, opts.limit, opts.window_ms) do
        {:allow, _count} ->
          conn

        {:deny, _limit} ->
          deny_request(conn, opts)
      end
    else
      conn
    end
  end

  defp rate_limiting_enabled? do
    Application.get_env(:backend, :rate_limiting_enabled, true)
  end

  defp deny_request(conn, %{format: :html, redirect_to: redirect_to} = opts)
       when is_binary(redirect_to) do
    conn
    |> Phoenix.Controller.put_flash(:error, rate_limit_message(opts.window_ms))
    |> Phoenix.Controller.redirect(to: redirect_to)
    |> halt()
  end

  defp deny_request(conn, %{format: :html} = opts) do
    conn
    |> put_status(:too_many_requests)
    |> Phoenix.Controller.put_view(html: BackendWeb.ErrorHTML)
    |> Phoenix.Controller.render("429.html", %{retry_after: div(opts.window_ms, 1000)})
    |> halt()
  end

  defp deny_request(conn, opts) do
    conn
    |> put_status(:too_many_requests)
    |> Phoenix.Controller.json(%{
      error: "too_many_requests",
      retry_after: div(opts.window_ms, 1000)
    })
    |> halt()
  end

  defp rate_limit_message(window_ms) do
    seconds = div(window_ms, 1000)
    "Too many login attempts. Please try again in #{seconds} seconds."
  end

  defp build_key(conn, prefix) do
    ip = get_client_ip(conn)
    "#{prefix}:#{ip}"
  end

  defp get_client_ip(conn) do
    if trust_forwarded_for?() do
      forwarded_for =
        conn
        |> get_req_header("x-forwarded-for")
        |> List.first()

      case forwarded_for do
        nil ->
          conn.remote_ip |> :inet.ntoa() |> to_string()

        forwarded ->
          forwarded
          |> String.split(",")
          |> List.first()
          |> String.trim()
      end
    else
      conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp trust_forwarded_for? do
    Application.get_env(:backend, :rate_limit_trust_x_forwarded_for, false)
  end

  defp check_rate(key, limit, window_ms) do
    case Hammer.check_rate(key, window_ms, limit) do
      {:allow, count} -> {:allow, count}
      {:deny, limit} -> {:deny, limit}
    end
  end
end
