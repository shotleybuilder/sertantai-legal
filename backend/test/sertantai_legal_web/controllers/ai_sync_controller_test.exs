defmodule SertantaiLegalWeb.AiSyncControllerTest do
  use SertantaiLegalWeb.ConnCase

  alias SertantaiLegal.Repo

  @test_key "test-ai-service-key-12345"

  setup do
    System.put_env("AI_SERVICE_API_KEY", @test_key)
    on_exit(fn -> System.delete_env("AI_SERVICE_API_KEY") end)

    # Insert a test uk_lrt record as FK target
    law_id = Ecto.UUID.generate()
    {:ok, law_id_binary} = Ecto.UUID.dump(law_id)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.query!(
      "INSERT INTO uk_lrt (id, name, title_en, type_code, year, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
      [law_id_binary, "UK_ukpga_2024_1", "Test Act 2024", "ukpga", 2024, now, now]
    )

    # Insert test LAT rows
    Repo.insert_all("lat", [
      %{
        section_id: "UK_ukpga_2024_1:s.1",
        law_name: "UK_ukpga_2024_1",
        law_id: law_id_binary,
        section_type: "section",
        sort_key: "section~0001",
        position: 1,
        depth: 1,
        text: "Test section text",
        language: "en",
        created_at: now,
        updated_at: now
      },
      %{
        section_id: "UK_ukpga_2024_1:s.2",
        law_name: "UK_ukpga_2024_1",
        law_id: law_id_binary,
        section_type: "section",
        sort_key: "section~0002",
        position: 2,
        depth: 1,
        text: "Another section",
        language: "en",
        amendment_count: 3,
        created_at: now,
        updated_at: now
      }
    ])

    # Insert test annotation rows
    Repo.insert_all("amendment_annotations", [
      %{
        id: "UK_ukpga_2024_1:amendment:1",
        law_name: "UK_ukpga_2024_1",
        law_id: law_id_binary,
        code: "F1",
        code_type: "amendment",
        source: "csv_import",
        text: "Words substituted by S.I. 2024/100",
        affected_sections: ["UK_ukpga_2024_1:s.1"],
        created_at: now,
        updated_at: now
      }
    ])

    %{law_id: law_id, now: now}
  end

  defp put_api_key(conn, key \\ @test_key) do
    put_req_header(conn, "x-api-key", key)
  end

  # ── Auth (shared for both endpoints) ─────────────────────────────

  describe "auth" do
    test "GET /api/ai/sync/lat returns 401 without API key", %{conn: conn} do
      conn = get(conn, "/api/ai/sync/lat")
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end

    test "GET /api/ai/sync/lat returns 401 with invalid key", %{conn: conn} do
      conn = conn |> put_api_key("wrong") |> get("/api/ai/sync/lat")
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end

    test "GET /api/ai/sync/annotations returns 401 without API key", %{conn: conn} do
      conn = get(conn, "/api/ai/sync/annotations")
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end
  end

  # ── LAT Sync ─────────────────────────────────────────────────────

  describe "GET /api/ai/sync/lat - response structure" do
    test "returns expected envelope keys", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat")
      response = json_response(conn, 200)

      assert is_list(response["items"])
      assert is_integer(response["count"])
      assert is_integer(response["total_count"])
      assert is_integer(response["limit"])
      assert is_integer(response["offset"])
      assert is_boolean(response["has_more"])
      assert is_binary(response["since"])
      assert is_binary(response["sync_timestamp"])
    end

    test "items have correct LAT fields", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat")
      response = json_response(conn, 200)

      assert response["count"] >= 2
      item = hd(response["items"])

      # Core fields
      assert Map.has_key?(item, "section_id")
      assert Map.has_key?(item, "law_name")
      assert Map.has_key?(item, "law_id")
      assert Map.has_key?(item, "section_type")
      assert Map.has_key?(item, "text")
      assert Map.has_key?(item, "language")
      assert Map.has_key?(item, "sort_key")
      assert Map.has_key?(item, "position")
      assert Map.has_key?(item, "depth")

      # Hierarchy fields
      assert Map.has_key?(item, "part")
      assert Map.has_key?(item, "chapter")
      assert Map.has_key?(item, "heading_group")
      assert Map.has_key?(item, "provision")
      assert Map.has_key?(item, "paragraph")
      assert Map.has_key?(item, "sub_paragraph")
      assert Map.has_key?(item, "schedule")

      # Annotation counts
      assert Map.has_key?(item, "amendment_count")
      assert Map.has_key?(item, "modification_count")

      # Timestamps
      assert Map.has_key?(item, "created_at")
      assert Map.has_key?(item, "updated_at")
    end

    test "items include denormalized uk_lrt fields", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat")
      response = json_response(conn, 200)

      item = hd(response["items"])
      assert item["law_title"] == "Test Act 2024"
      assert item["law_type_code"] == "ukpga"
      assert item["law_year"] == 2024
    end

    test "items exclude embedding/token fields", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat")
      response = json_response(conn, 200)

      item = hd(response["items"])
      refute Map.has_key?(item, "embedding")
      refute Map.has_key?(item, "embedding_model")
      refute Map.has_key?(item, "embedded_at")
      refute Map.has_key?(item, "token_ids")
      refute Map.has_key?(item, "tokenizer_model")
      refute Map.has_key?(item, "legacy_id")
    end
  end

  describe "GET /api/ai/sync/lat - pagination" do
    test "respects limit parameter", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat", %{"limit" => "1"})
      response = json_response(conn, 200)

      assert response["limit"] == 1
      assert response["count"] == 1
      assert response["total_count"] >= 2
      assert response["has_more"] == true
    end

    test "respects offset parameter", %{conn: conn} do
      conn =
        conn |> put_api_key() |> get("/api/ai/sync/lat", %{"limit" => "1", "offset" => "1"})

      response = json_response(conn, 200)

      assert response["offset"] == 1
      assert response["count"] == 1
    end

    test "caps limit at max (2000)", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat", %{"limit" => "9999"})
      response = json_response(conn, 200)

      assert response["limit"] == 2000
    end

    test "defaults limit to 500", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat")
      response = json_response(conn, 200)

      assert response["limit"] == 500
    end
  end

  describe "GET /api/ai/sync/lat - since filter" do
    test "returns records since a specific timestamp", %{conn: conn} do
      conn =
        conn |> put_api_key() |> get("/api/ai/sync/lat", %{"since" => "2020-01-01T00:00:00Z"})

      response = json_response(conn, 200)

      assert response["count"] >= 2
      assert response["since"] =~ "2020-01-01"
    end

    test "far future since returns no records", %{conn: conn} do
      conn =
        conn |> put_api_key() |> get("/api/ai/sync/lat", %{"since" => "2099-01-01T00:00:00Z"})

      response = json_response(conn, 200)

      assert response["count"] == 0
      assert response["items"] == []
    end

    test "invalid since falls back to default (30 days)", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/lat", %{"since" => "not-a-date"})
      response = json_response(conn, 200)

      # Should still work — defaults to 30 days ago, which includes our test data
      assert is_binary(response["since"])
    end
  end

  describe "GET /api/ai/sync/lat - law_name filter" do
    test "filters by specific law_name", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/sync/lat", %{
          "since" => "2020-01-01T00:00:00Z",
          "law_name" => "UK_ukpga_2024_1"
        })

      response = json_response(conn, 200)

      assert response["count"] >= 2

      for item <- response["items"] do
        assert item["law_name"] == "UK_ukpga_2024_1"
      end
    end

    test "non-matching law_name returns empty", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/sync/lat", %{
          "since" => "2020-01-01T00:00:00Z",
          "law_name" => "UK_nonexistent_9999_1"
        })

      response = json_response(conn, 200)
      assert response["count"] == 0
    end
  end

  # ── Annotations Sync ─────────────────────────────────────────────

  describe "GET /api/ai/sync/annotations - response structure" do
    test "returns expected envelope keys", %{conn: conn} do
      conn = conn |> put_api_key() |> get("/api/ai/sync/annotations")
      response = json_response(conn, 200)

      assert is_list(response["items"])
      assert is_integer(response["count"])
      assert is_integer(response["total_count"])
      assert is_integer(response["limit"])
      assert is_integer(response["offset"])
      assert is_boolean(response["has_more"])
      assert is_binary(response["since"])
      assert is_binary(response["sync_timestamp"])
    end

    test "items have correct annotation fields", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/sync/annotations", %{"since" => "2020-01-01T00:00:00Z"})

      response = json_response(conn, 200)

      assert response["count"] >= 1
      item = hd(response["items"])

      assert Map.has_key?(item, "id")
      assert Map.has_key?(item, "law_name")
      assert Map.has_key?(item, "law_id")
      assert Map.has_key?(item, "law_title")
      assert Map.has_key?(item, "code")
      assert Map.has_key?(item, "code_type")
      assert Map.has_key?(item, "source")
      assert Map.has_key?(item, "text")
      assert Map.has_key?(item, "affected_sections")
      assert Map.has_key?(item, "created_at")
      assert Map.has_key?(item, "updated_at")
    end

    test "annotation fields have expected values", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/sync/annotations", %{"since" => "2020-01-01T00:00:00Z"})

      response = json_response(conn, 200)
      item = hd(response["items"])

      assert item["id"] == "UK_ukpga_2024_1:amendment:1"
      assert item["code"] == "F1"
      assert item["code_type"] == "amendment"
      assert item["source"] == "csv_import"
      assert item["law_title"] == "Test Act 2024"
      assert is_list(item["affected_sections"])
      assert "UK_ukpga_2024_1:s.1" in item["affected_sections"]
    end
  end

  describe "GET /api/ai/sync/annotations - pagination" do
    test "respects limit and offset", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/sync/annotations", %{
          "since" => "2020-01-01T00:00:00Z",
          "limit" => "1",
          "offset" => "0"
        })

      response = json_response(conn, 200)
      assert response["limit"] == 1
      assert response["offset"] == 0
      assert response["count"] == 1
    end

    test "caps limit at max (2000)", %{conn: conn} do
      conn =
        conn |> put_api_key() |> get("/api/ai/sync/annotations", %{"limit" => "9999"})

      response = json_response(conn, 200)
      assert response["limit"] == 2000
    end
  end

  describe "GET /api/ai/sync/annotations - law_name filter" do
    test "filters by specific law_name", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/sync/annotations", %{
          "since" => "2020-01-01T00:00:00Z",
          "law_name" => "UK_ukpga_2024_1"
        })

      response = json_response(conn, 200)
      assert response["count"] >= 1

      for item <- response["items"] do
        assert item["law_name"] == "UK_ukpga_2024_1"
      end
    end

    test "non-matching law_name returns empty", %{conn: conn} do
      conn =
        conn
        |> put_api_key()
        |> get("/api/ai/sync/annotations", %{
          "since" => "2020-01-01T00:00:00Z",
          "law_name" => "UK_nonexistent_9999_1"
        })

      response = json_response(conn, 200)
      assert response["count"] == 0
    end
  end
end
