defmodule SertantaiLegalWeb.AuthPlugTest do
  use SertantaiLegalWeb.ConnCase, async: true

  alias SertantaiLegalWeb.AuthPlug

  setup :setup_auth

  describe "valid token" do
    test "assigns user_id, org_id, and role from JWT claims", %{conn: conn} do
      conn =
        conn
        |> put_auth_header()
        |> AuthPlug.call([])

      refute conn.halted
      assert conn.assigns.current_user_id == default_user_id()
      assert conn.assigns.organization_id == default_org_id()
      assert conn.assigns.user_role == "owner"
      assert is_map(conn.assigns.jwt_claims)
    end

    test "extracts user_id from AshAuthentication sub format", %{conn: conn} do
      user_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_auth_header(%{"sub" => "user?id=#{user_id}"})
        |> AuthPlug.call([])

      refute conn.halted
      assert conn.assigns.current_user_id == user_id
    end

    test "handles bare UUID in sub claim", %{conn: conn} do
      user_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_auth_header(%{"sub" => user_id})
        |> AuthPlug.call([])

      refute conn.halted
      assert conn.assigns.current_user_id == user_id
    end

    test "passes custom org_id through", %{conn: conn} do
      org_id = Ecto.UUID.generate()

      conn =
        conn
        |> put_auth_header(%{"org_id" => org_id})
        |> AuthPlug.call([])

      refute conn.halted
      assert conn.assigns.organization_id == org_id
    end

    test "passes role through", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"role" => "member"})
        |> AuthPlug.call([])

      refute conn.halted
      assert conn.assigns.user_role == "member"
    end
  end

  describe "missing authorization header" do
    test "returns 401", %{conn: conn} do
      conn = AuthPlug.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Unauthorized"
      assert body["reason"] =~ "Authorization header"
    end
  end

  describe "invalid token format" do
    test "returns 401 for non-Bearer scheme", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 for malformed JWT", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not.a.jwt")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["reason"] =~ "Malformed" or body["reason"] =~ "Invalid"
    end

    test "returns 401 for empty Bearer token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "expired token" do
    test "returns 401", %{conn: conn} do
      token = build_expired_token()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["reason"] =~ "expired"
    end
  end

  describe "wrong signing key" do
    test "returns 401 when signed with a different Ed25519 key", %{conn: conn} do
      wrong_key = JOSE.JWK.generate_key({:okp, :Ed25519})
      jws = %{"alg" => "EdDSA"}

      claims = %{
        "sub" => "user?id=#{Ecto.UUID.generate()}",
        "exp" => System.system_time(:second) + 3600
      }

      {_, token} = JOSE.JWT.sign(wrong_key, jws, claims) |> JOSE.JWS.compact()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["reason"] =~ "Invalid token signature"
    end
  end

  describe "missing claims" do
    test "returns 401 when sub is missing", %{conn: conn} do
      token = build_token(%{"sub" => nil})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["reason"] =~ "sub"
    end

    test "returns 401 when exp is missing", %{conn: conn} do
      token = build_token(%{"exp" => nil})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["reason"] =~ "expiry"
    end
  end

  describe "integration with router" do
    test "public UK LRT endpoint works without auth", %{conn: conn} do
      conn = get(conn, "/api/uk-lrt")
      assert conn.status == 200
    end

    test "health endpoint works without auth", %{conn: conn} do
      conn = get(conn, "/health")
      assert conn.status == 200
    end

    test "JWT endpoint returns 401 without auth", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> patch("/api/uk-lrt/#{Ecto.UUID.generate()}", Jason.encode!(%{}))

      assert conn.status == 401
    end

    test "admin endpoint returns 401 without session", %{conn: conn} do
      conn = get(conn, "/api/sessions")
      assert conn.status == 401
    end

    test "protected endpoint works with valid auth", %{conn: conn} do
      # uk-lrt write routes still use JWT auth
      conn =
        conn
        |> put_auth_header()
        |> put_req_header("content-type", "application/json")
        |> patch("/api/uk-lrt/#{Ecto.UUID.generate()}", Jason.encode!(%{}))

      # 404/422/400 means JWT auth passed (resource not found)
      assert conn.status in [400, 404, 422]
    end
  end
end
