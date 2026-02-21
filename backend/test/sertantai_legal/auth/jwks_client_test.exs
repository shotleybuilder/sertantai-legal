defmodule SertantaiLegal.Auth.JwksClientTest do
  use ExUnit.Case, async: false

  alias SertantaiLegal.Auth.JwksClient

  # Generate a test Ed25519 keypair for JWKS responses
  @test_jwk JOSE.JWK.generate_key({:okp, :Ed25519})
  @test_pub_jwk JOSE.JWK.to_public(@test_jwk)
  @test_pub_map elem(JOSE.JWK.to_map(@test_pub_jwk), 1)

  setup do
    # Reset key before each test
    :ok = JwksClient.set_test_key(nil)

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :test_mode, true)
      Req.Test.set_req_test_to_private()
      JwksClient.set_test_key(nil)
    end)

    :ok
  end

  describe "set_test_key/1 (test mode)" do
    test "sets a key directly without HTTP fetch" do
      assert {:error, :no_key} = JwksClient.public_key()

      :ok = JwksClient.set_test_key(@test_pub_jwk)

      assert {:ok, @test_pub_jwk} = JwksClient.public_key()
    end

    test "set key can verify a JWT signed with the corresponding private key" do
      :ok = JwksClient.set_test_key(@test_pub_jwk)

      claims = %{"sub" => "user?id=test-123", "exp" => System.system_time(:second) + 3600}
      jws = %{"alg" => "EdDSA"}
      {_, token} = JOSE.JWT.sign(@test_jwk, jws, claims) |> JOSE.JWS.compact()

      {:ok, jwk} = JwksClient.public_key()

      assert {true, %JOSE.JWT{fields: decoded}, _jws} =
               JOSE.JWT.verify_strict(jwk, ["EdDSA"], token)

      assert decoded["sub"] == "user?id=test-123"
    end
  end

  describe "HTTP fetch (non-test mode)" do
    setup do
      # Use shared mode so the GenServer can access stubs from any process
      Req.Test.set_req_test_to_shared()
      Application.put_env(:sertantai_legal, :test_mode, false)
      :ok
    end

    test "fetches and caches the public key" do
      stub_jwks_success()
      send(GenServer.whereis(JwksClient), :fetch)
      Process.sleep(200)

      assert {:ok, jwk} = JwksClient.public_key()
      {_meta, pub_map} = JOSE.JWK.to_map(JOSE.JWK.to_public(jwk))
      assert pub_map["kty"] == "OKP"
      assert pub_map["crv"] == "Ed25519"
    end

    test "can verify a JWT signed with the corresponding private key" do
      stub_jwks_success()
      send(GenServer.whereis(JwksClient), :fetch)
      Process.sleep(200)

      claims = %{"sub" => "user?id=test-123", "exp" => System.system_time(:second) + 3600}
      jws = %{"alg" => "EdDSA"}
      {_, token} = JOSE.JWT.sign(@test_jwk, jws, claims) |> JOSE.JWS.compact()

      {:ok, jwk} = JwksClient.public_key()

      assert {true, %JOSE.JWT{fields: decoded}, _jws} =
               JOSE.JWT.verify_strict(jwk, ["EdDSA"], token)

      assert decoded["sub"] == "user?id=test-123"
    end

    test "keeps nil key when auth returns error status" do
      Req.Test.stub(JwksClient, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      send(GenServer.whereis(JwksClient), :fetch)
      Process.sleep(200)

      assert {:error, :no_key} = JwksClient.public_key()
    end

    test "keeps nil key when JWKS has no keys" do
      Req.Test.stub(JwksClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"keys" => []}))
      end)

      send(GenServer.whereis(JwksClient), :fetch)
      Process.sleep(200)

      assert {:error, :no_key} = JwksClient.public_key()
    end
  end

  describe "refresh/0" do
    setup do
      Req.Test.set_req_test_to_shared()
      Application.put_env(:sertantai_legal, :test_mode, false)
      :ok
    end

    test "re-fetches the key after initial failure" do
      Req.Test.stub(JwksClient, fn conn ->
        Plug.Conn.send_resp(conn, 503, "down")
      end)

      send(GenServer.whereis(JwksClient), :fetch)
      Process.sleep(200)
      assert {:error, :no_key} = JwksClient.public_key()

      # Now stub success and refresh
      stub_jwks_success()
      JwksClient.refresh()
      Process.sleep(200)

      assert {:ok, _jwk} = JwksClient.public_key()
    end
  end

  # Helpers

  defp stub_jwks_success do
    Req.Test.stub(JwksClient, fn conn ->
      jwks = %{
        "keys" => [
          Map.merge(@test_pub_map, %{"use" => "sig", "kid" => "test-kid"})
        ]
      }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(jwks))
    end)
  end
end
