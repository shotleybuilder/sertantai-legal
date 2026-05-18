defmodule SertantaiLegalWeb.AuthPlugTest do
  use SertantaiLegalWeb.ConnCase, async: false

  alias SertantaiLegal.Auth.JwksClient
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
    setup do
      # Stub JWKS so refresh_sync doesn't crash — returns the same test key,
      # so token signed with a truly different key still fails after refresh
      Req.Test.set_req_test_to_shared()
      {_, pub_map} = JOSE.JWK.to_map(test_public_key())

      Req.Test.stub(JwksClient, fn conn ->
        jwks = %{"keys" => [Map.merge(pub_map, %{"use" => "sig", "kid" => "test-kid"})]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(jwks))
      end)

      on_exit(fn -> Req.Test.set_req_test_to_private() end)
      :ok
    end

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

  describe "JWKS auto-refresh on key rotation" do
    setup do
      Req.Test.set_req_test_to_shared()

      on_exit(fn ->
        Req.Test.set_req_test_to_private()
        # Restore the standard test key
        JwksClient.set_test_key(test_public_key())
      end)

      :ok
    end

    test "recovers when auth restarts with a new keypair", %{conn: conn} do
      # Simulate auth restart: generate a NEW keypair (the "rotated" key)
      new_private = JOSE.JWK.generate_key({:okp, :Ed25519})
      new_public = JOSE.JWK.to_public(new_private)
      {_, new_pub_map} = JOSE.JWK.to_map(new_public)

      # Sign a valid token with the NEW private key
      now = System.system_time(:second)

      claims = %{
        "sub" => "user?id=#{Ecto.UUID.generate()}",
        "org_id" => Ecto.UUID.generate(),
        "role" => "owner",
        "exp" => now + 3600,
        "iat" => now,
        "nbf" => now
      }

      {_, token} = JOSE.JWT.sign(new_private, %{"alg" => "EdDSA"}, claims) |> JOSE.JWS.compact()

      # JwksClient still has the OLD test key cached (from setup_auth).
      # First verify attempt will fail. Stub JWKS to return the NEW public key.
      Req.Test.stub(JwksClient, fn conn ->
        jwks = %{"keys" => [Map.merge(new_pub_map, %{"use" => "sig", "kid" => "rotated-kid"})]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(jwks))
      end)

      # AuthPlug should: fail verification → refresh_sync → get new key → retry → succeed
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      refute conn.halted, "Expected auth to succeed after JWKS refresh, but got 401"
      assert conn.assigns.current_user_id == claims["sub"] |> String.replace("user?id=", "")
      assert conn.assigns.organization_id == claims["org_id"]
      assert conn.assigns.user_role == "owner"
    end

    test "still rejects when refresh returns same key and token is truly invalid", %{conn: conn} do
      # Token signed with a random key that doesn't match anything
      wrong_key = JOSE.JWK.generate_key({:okp, :Ed25519})

      claims = %{
        "sub" => "user?id=#{Ecto.UUID.generate()}",
        "exp" => System.system_time(:second) + 3600
      }

      {_, token} = JOSE.JWT.sign(wrong_key, %{"alg" => "EdDSA"}, claims) |> JOSE.JWS.compact()

      # Stub JWKS to return the same old test key (no rotation happened)
      {_, pub_map} = JOSE.JWK.to_map(test_public_key())

      Req.Test.stub(JwksClient, fn conn ->
        jwks = %{"keys" => [Map.merge(pub_map, %{"use" => "sig", "kid" => "test-kid"})]}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(jwks))
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when JWKS endpoint is unreachable during refresh", %{conn: conn} do
      # Token signed with a different key
      wrong_key = JOSE.JWK.generate_key({:okp, :Ed25519})

      claims = %{
        "sub" => "user?id=#{Ecto.UUID.generate()}",
        "exp" => System.system_time(:second) + 3600
      }

      {_, token} = JOSE.JWT.sign(wrong_key, %{"alg" => "EdDSA"}, claims) |> JOSE.JWS.compact()

      # Stub JWKS to return 503 (auth service down)
      Req.Test.stub(JwksClient, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
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
      conn = get(conn, "/api/laws")
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
        |> patch("/api/laws/#{Ecto.UUID.generate()}", Jason.encode!(%{}))

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
        |> patch("/api/laws/#{Ecto.UUID.generate()}", Jason.encode!(%{}))

      # 404/422/400 means JWT auth passed (resource not found)
      assert conn.status in [400, 404, 422]
    end
  end
end
