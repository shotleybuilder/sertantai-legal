defmodule SertantaiLegalWeb.LoadFromCookie do
  @moduledoc """
  Injects a Bearer Authorization header from a cookie or query parameter.

  Runs **before** `AuthPlug` in the pipeline. Only acts when no
  Authorization header is already present — Bearer header takes priority.

  Token sources (checked in order):
  1. `Authorization: Bearer <token>` header (already present — skip)
  2. `sertantai_token` cookie (set by sertantai-auth on `.sertantai.com`)
  3. `token` query parameter (for EventSource/SSE which can't set headers)
  """

  import Plug.Conn

  @cookie_name "sertantai_token"

  def init(opts), do: opts

  def call(conn, _opts) do
    if has_bearer_header?(conn) do
      conn
    else
      conn
      |> try_cookie()
      |> try_query_param()
    end
  end

  defp try_cookie(conn) do
    if has_bearer_header?(conn) do
      conn
    else
      conn = fetch_cookies(conn)

      case conn.cookies[@cookie_name] do
        token when is_binary(token) and token != "" ->
          put_req_header(conn, "authorization", "Bearer #{token}")

        _ ->
          conn
      end
    end
  end

  defp try_query_param(conn) do
    if has_bearer_header?(conn) do
      conn
    else
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params["token"] do
        token when is_binary(token) and token != "" ->
          put_req_header(conn, "authorization", "Bearer #{token}")

        _ ->
          conn
      end
    end
  end

  defp has_bearer_header?(conn) do
    conn
    |> get_req_header("authorization")
    |> Enum.any?(&String.starts_with?(&1, "Bearer "))
  end
end
