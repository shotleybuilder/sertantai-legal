defmodule SertantaiLegalWeb.Plugs.AuthHelpers do
  @moduledoc """
  Authentication plugs for GitHub OAuth admin route protection.

  Returns JSON responses (not HTML redirects) since admin routes
  are consumed by the SvelteKit frontend.
  """

  import Plug.Conn

  require Logger

  def init(opts), do: opts

  def call(conn, :load_current_user), do: load_current_user(conn, [])
  def call(conn, :require_authenticated_user), do: require_authenticated_user(conn, [])
  def call(conn, :require_admin_user), do: require_admin_user(conn, [])

  @doc "Loads the current user from the Phoenix session."
  def load_current_user(conn, _opts) do
    conn = Plug.Conn.fetch_session(conn)

    case get_session(conn, "user_id") do
      nil ->
        conn

      user_id ->
        case Ash.get(SertantaiLegal.Accounts.User, user_id) do
          {:ok, user} ->
            user = maybe_refresh_admin_status(user)
            assign(conn, :current_user, user)

          {:error, _} ->
            conn
        end
    end
  end

  @doc "Returns 401 JSON if no user is in the session."
  def require_authenticated_user(conn, _opts) do
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

  @doc "Returns 403 JSON if the session user is not an admin."
  def require_admin_user(conn, _opts) do
    case conn.assigns[:current_user] do
      %{is_admin: true} ->
        conn

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{error: "Admin privileges required"}))
        |> halt()
    end
  end

  defp maybe_refresh_admin_status(%{admin_checked_at: nil} = user) do
    refresh_admin_status(user)
  end

  defp maybe_refresh_admin_status(%{admin_checked_at: checked_at} = user) do
    if DateTime.diff(DateTime.utc_now(), checked_at, :second) > 3600 do
      refresh_admin_status(user)
    else
      user
    end
  end

  defp refresh_admin_status(user) do
    config = Application.get_env(:sertantai_legal, :github_admin, [])
    allowed_users = Keyword.get(config, :allowed_users, [])

    is_admin =
      is_list(allowed_users) and length(allowed_users) > 0 and
        user.github_login in allowed_users

    case Ash.update(user, %{is_admin: is_admin, admin_checked_at: DateTime.utc_now()},
           action: :update_admin_status
         ) do
      {:ok, updated} ->
        updated

      {:error, reason} ->
        Logger.warning("Failed to refresh admin status: #{inspect(reason)}")
        user
    end
  end
end
