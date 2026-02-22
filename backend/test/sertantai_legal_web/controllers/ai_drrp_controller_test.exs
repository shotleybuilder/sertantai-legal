defmodule SertantaiLegalWeb.AiDrrpControllerTest do
  use SertantaiLegalWeb.ConnCase

  @test_key "test-ai-service-key-12345"

  setup do
    System.put_env("AI_SERVICE_API_KEY", @test_key)
    on_exit(fn -> System.delete_env("AI_SERVICE_API_KEY") end)
    :ok
  end

  defp put_api_key(conn, key \\ @test_key) do
    put_req_header(conn, "x-api-key", key)
  end

  describe "GET /api/ai/drrp/clause/queue - auth" do
    test "returns 401 without API key", %{conn: conn} do
      conn = get(conn, "/api/ai/drrp/clause/queue")
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end

    test "returns 401 with invalid API key", %{conn: conn} do
      conn = conn |> put_api_key("wrong-key") |> get("/api/ai/drrp/clause/queue")
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end
  end

  describe "GET /api/ai/drrp/clause/queue - response structure" do
    test "returns expected response keys", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/drrp/clause/queue")
      response = json_response(conn, 200)

      assert is_list(response["items"])
      assert is_integer(response["count"])
      assert is_integer(response["total_count"])
      assert is_integer(response["limit"])
      assert is_integer(response["offset"])
      assert is_boolean(response["has_more"])
      assert is_number(response["threshold"])
    end

    test "items have correct field names for AI service", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/drrp/clause/queue", %{"limit" => "1"})
      response = json_response(conn, 200)

      if response["count"] > 0 do
        item = hd(response["items"])

        assert Map.has_key?(item, "law_id")
        assert Map.has_key?(item, "law_name")
        assert Map.has_key?(item, "provision")
        assert Map.has_key?(item, "drrp_type")
        assert Map.has_key?(item, "holder")
        assert Map.has_key?(item, "regex_clause")
        assert Map.has_key?(item, "drrp_column")
        assert Map.has_key?(item, "entry_index")
        assert Map.has_key?(item, "scraped_at")

        # drrp_type should be lowercase
        assert item["drrp_type"] == String.downcase(item["drrp_type"])

        # drrp_column should be one of the 4 DRRP columns
        assert item["drrp_column"] in ~w(duties responsibilities rights powers)
      end
    end
  end

  describe "GET /api/ai/drrp/clause/queue - pagination" do
    test "respects limit parameter", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/drrp/clause/queue", %{"limit" => "5"})
      response = json_response(conn, 200)

      assert response["limit"] == 5
      assert response["count"] <= 5
    end

    test "respects offset parameter", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/drrp/clause/queue", %{"limit" => "5", "offset" => "10"})

      response = json_response(conn, 200)

      assert response["limit"] == 5
      assert response["offset"] == 10
    end

    test "caps limit at max (500)", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/drrp/clause/queue", %{"limit" => "9999"})
      response = json_response(conn, 200)

      assert response["limit"] == 500
    end

    test "defaults limit to 100", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/drrp/clause/queue")
      response = json_response(conn, 200)

      assert response["limit"] == 100
    end
  end

  describe "GET /api/ai/drrp/clause/queue - threshold" do
    test "accepts threshold parameter", %{conn: conn} do
      conn =
        conn |> put_api_key() |> get("/api/ai/drrp/clause/queue", %{"threshold" => "0.5"})

      response = json_response(conn, 200)
      assert response["threshold"] == 0.5
    end

    test "defaults threshold to 0.7", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/drrp/clause/queue")
      response = json_response(conn, 200)

      assert response["threshold"] == 0.7
    end

    test "ignores invalid threshold and uses default", %{conn: conn} do
      conn =
        conn |> put_api_key() |> get("/api/ai/drrp/clause/queue", %{"threshold" => "abc"})

      response = json_response(conn, 200)
      assert response["threshold"] == 0.7
    end
  end
end
