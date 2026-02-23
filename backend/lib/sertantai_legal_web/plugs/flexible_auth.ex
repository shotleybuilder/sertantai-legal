defmodule SertantaiLegalWeb.Plugs.FlexibleAuth do
  @moduledoc """
  Flexible authentication plug that supports both JWT (Bearer) and session auth.

  Tries JWT first (for tenant users via sertantai-auth), falls back to session
  auth (for admin users via GitHub OAuth). Used for endpoints that should work
  with either authentication method (e.g., SSE parse-stream).
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> _] ->
        SertantaiLegalWeb.AuthPlug.call(conn, [])

      _ ->
        try_session_auth(conn)
    end
  end

  defp try_session_auth(conn) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Not authenticated"}))
        |> halt()

      _user ->
        conn
    end
  end
end
