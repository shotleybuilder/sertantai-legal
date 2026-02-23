defmodule SertantaiLegalWeb.Plugs.AuthHelpersTest do
  use SertantaiLegalWeb.ConnCase

  import SertantaiLegal.AuthHelpers

  setup :setup_auth

  describe "admin route protection" do
    test "returns 401 without session", %{conn: conn} do
      conn = get(conn, "/api/lat/stats")
      assert json_response(conn, 401)["error"] == "Not authenticated"
    end

    test "returns 403 for non-admin session user", %{conn: conn} do
      {:ok, result} = setup_non_admin_session(%{conn: conn})

      conn = get(result[:conn], "/api/lat/stats")
      assert json_response(conn, 403)["error"] == "Admin privileges required"
    end

    test "returns 200 for admin session user", %{conn: conn} do
      {:ok, result} = setup_admin_session(%{conn: conn})

      conn = get(result[:conn], "/api/lat/stats")
      assert conn.status == 200
    end
  end

  describe "tenant routes still use JWT" do
    test "uk-lrt write returns 401 without JWT", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/uk-lrt/#{Ecto.UUID.generate()}", Jason.encode!(%{}))

      assert json_response(conn, 401)
    end

    test "uk-lrt write works with valid JWT", %{conn: conn} do
      conn =
        conn
        |> put_auth_header()
        |> put_req_header("content-type", "application/json")
        |> patch("/api/uk-lrt/#{Ecto.UUID.generate()}", Jason.encode!(%{}))

      # 404 or 422 means auth succeeded but resource not found
      assert conn.status in [404, 422, 400]
    end
  end
end
