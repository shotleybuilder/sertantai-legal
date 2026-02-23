defmodule SertantaiLegalWeb.AuthController do
  @moduledoc """
  Handles GitHub OAuth callbacks and session management.

  On successful GitHub authentication:
  1. Stores the user in the Phoenix session
  2. Redirects to the SvelteKit frontend callback page

  The frontend then calls `GET /api/auth/me` to verify the session
  and get user details.
  """

  use SertantaiLegalWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, token) do
    require Logger

    Logger.info(
      "OAuth SUCCESS: user=#{inspect(user.id)}, email=#{inspect(user.email)}, token=#{inspect(token != nil)}, activity=#{inspect(activity)}"
    )

    frontend_url = Application.get_env(:sertantai_legal, :frontend_url, "http://localhost:5175")

    conn
    |> store_in_session(user)
    |> put_session("user_id", user.id)
    |> redirect(external: "#{frontend_url}/auth/callback")
  end

  def failure(conn, activity, reason) do
    require Logger
    Logger.error("OAuth FAILURE: activity=#{inspect(activity)}, reason=#{inspect(reason)}")
    frontend_url = Application.get_env(:sertantai_legal, :frontend_url, "http://localhost:5175")

    conn
    |> redirect(external: "#{frontend_url}/auth/callback?error=auth_failed")
  end

  def sign_out(conn, _params) do
    frontend_url = Application.get_env(:sertantai_legal, :frontend_url, "http://localhost:5175")

    conn
    |> clear_session(:sertantai_legal)
    |> redirect(external: frontend_url)
  end

  @doc "Returns the current session user as JSON (for frontend auth verification)."
  def me(conn, _params) do
    conn = Plug.Conn.fetch_session(conn)

    case get_session(conn, "user_id") do
      nil ->
        conn |> put_status(401) |> json(%{error: "Not authenticated"})

      user_id ->
        case Ash.get(SertantaiLegal.Accounts.User, user_id) do
          {:ok, user} ->
            json(conn, %{
              id: user.id,
              email: to_string(user.email),
              name: user.name,
              github_login: user.github_login,
              avatar_url: user.avatar_url,
              is_admin: user.is_admin
            })

          {:error, _} ->
            conn |> put_status(401) |> json(%{error: "Not authenticated"})
        end
    end
  end
end
