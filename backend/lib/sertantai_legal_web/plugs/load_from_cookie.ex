defmodule SertantaiLegalWeb.LoadFromCookie do
  @moduledoc """
  Reads the `sertantai_token` cookie and injects it as a Bearer Authorization header.

  This plug runs **before** `AuthPlug` in the pipeline. It only acts when no
  Authorization header is already present — Bearer header takes priority,
  cookie is the fallback.

  The cookie is set by sertantai-auth on `.sertantai.com` and sent automatically
  by the browser to all subdomains (e.g. `legal.sertantai.com`).
  """

  import Plug.Conn

  @cookie_name "sertantai_token"

  def init(opts), do: opts

  def call(conn, _opts) do
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

  defp has_bearer_header?(conn) do
    conn
    |> get_req_header("authorization")
    |> Enum.any?(&String.starts_with?(&1, "Bearer "))
  end
end
