defmodule SertantaiLegalWeb.RequireAdmin do
  @moduledoc """
  Requires the authenticated user to have an admin or owner role.

  Must run after `AuthPlug`, which sets `conn.assigns.user_role` from JWT claims.
  Returns 403 JSON if the role is insufficient.
  """

  import Plug.Conn

  @behaviour Plug

  @admin_roles ~w(admin owner)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if conn.assigns[:user_role] in @admin_roles do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: "Admin privileges required"}))
      |> halt()
    end
  end
end
