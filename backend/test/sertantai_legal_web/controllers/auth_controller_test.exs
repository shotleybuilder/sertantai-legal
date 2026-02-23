defmodule SertantaiLegalWeb.AuthControllerTest do
  use SertantaiLegalWeb.ConnCase

  import SertantaiLegal.AuthHelpers

  describe "GET /api/auth/me" do
    test "returns 401 without session", %{conn: conn} do
      conn = get(conn, "/api/auth/me")
      assert json_response(conn, 401)["error"] == "Not authenticated"
    end

    test "returns user JSON with valid admin session", %{conn: conn} do
      {:ok, result} = setup_admin_session(%{conn: conn})

      conn = get(result[:conn], "/api/auth/me")
      resp = json_response(conn, 200)

      assert resp["id"] == result[:admin_user].id
      assert resp["github_login"] == "test-admin"
      assert resp["is_admin"] == true
    end

    test "returns user JSON for non-admin session", %{conn: conn} do
      {:ok, result} = setup_non_admin_session(%{conn: conn})

      conn = get(result[:conn], "/api/auth/me")
      resp = json_response(conn, 200)

      assert resp["id"] == result[:non_admin_user].id
      assert resp["is_admin"] == false
    end
  end
end
