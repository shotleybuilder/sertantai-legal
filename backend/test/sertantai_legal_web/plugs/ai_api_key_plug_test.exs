defmodule SertantaiLegalWeb.AiApiKeyPlugTest do
  use SertantaiLegalWeb.ConnCase, async: true

  alias SertantaiLegalWeb.AiApiKeyPlug

  @test_key "test-ai-service-key-12345"

  setup do
    System.put_env("AI_SERVICE_API_KEY", @test_key)
    on_exit(fn -> System.delete_env("AI_SERVICE_API_KEY") end)
    :ok
  end

  describe "valid API key" do
    test "passes with correct key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", @test_key)
        |> AiApiKeyPlug.call([])

      refute conn.halted
    end
  end

  describe "invalid API key" do
    test "halts with wrong key", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "wrong-key")
        |> AiApiKeyPlug.call([])

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Unauthorized"
    end

    test "halts with missing key", %{conn: conn} do
      conn = AiApiKeyPlug.call(conn, [])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts when env var is not set", %{conn: conn} do
      System.delete_env("AI_SERVICE_API_KEY")

      conn =
        conn
        |> put_req_header("x-api-key", "any-key")
        |> AiApiKeyPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "env option" do
    setup do
      System.put_env("WORKFLOW_API_KEY", "workflow-key-67890")
      on_exit(fn -> System.delete_env("WORKFLOW_API_KEY") end)
      :ok
    end

    test "checks the named env var instead of AI_SERVICE_API_KEY", %{conn: conn} do
      opts = AiApiKeyPlug.init(env: "WORKFLOW_API_KEY")

      ok = conn |> put_req_header("x-api-key", "workflow-key-67890") |> AiApiKeyPlug.call(opts)
      refute ok.halted

      ai_key =
        build_conn() |> put_req_header("x-api-key", @test_key) |> AiApiKeyPlug.call(opts)

      assert ai_key.halted
      assert ai_key.status == 401
    end
  end
end
