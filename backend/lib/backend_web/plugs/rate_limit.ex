defmodule BackendWeb.Plugs.RateLimit do
  import Plug.Conn

  @default_limit 5
  @default_window_ms 60_000

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, @default_limit),
      window_ms: Keyword.get(opts, :window_ms, @default_window_ms),
      key_prefix: Keyword.get(opts, :key_prefix, "rate_limit")
    }
  end

  def call(conn, opts) do
    key = build_key(conn, opts.key_prefix)

    case check_rate(key, opts.limit, opts.window_ms) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{
          error: "too_many_requests",
          retry_after: div(opts.window_ms, 1000)
        })
        |> halt()
    end
  end

  defp build_key(conn, prefix) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    "#{prefix}:#{ip}"
  end

  defp check_rate(key, limit, window_ms) do
    case Hammer.check_rate(key, window_ms, limit) do
      {:allow, count} -> {:allow, count}
      {:deny, limit} -> {:deny, limit}
    end
  end
end
