defmodule SertantaiLegalWeb.LatAdminControllerTest do
  use SertantaiLegalWeb.ConnCase

  import SertantaiLegal.AuthHelpers

  alias SertantaiLegal.Repo

  setup :setup_auth

  setup do
    law_id = Ecto.UUID.generate()
    {:ok, law_id_binary} = Ecto.UUID.dump(law_id)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.query!(
      "INSERT INTO uk_lrt (id, name, title_en, type_code, year, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
      [law_id_binary, "UK_ukpga_2024_1", "Test Act 2024", "ukpga", 2024, now, now]
    )

    Repo.insert_all("lat", [
      %{
        section_id: "UK_ukpga_2024_1:title",
        law_name: "UK_ukpga_2024_1",
        law_id: law_id_binary,
        section_type: "title",
        sort_key: "000.000.000~",
        position: 0,
        depth: 0,
        text: "Test Act 2024",
        language: "en",
        created_at: now,
        updated_at: now
      },
      %{
        section_id: "UK_ukpga_2024_1:s.1",
        law_name: "UK_ukpga_2024_1",
        law_id: law_id_binary,
        section_type: "section",
        sort_key: "001.000.000~",
        position: 1,
        depth: 1,
        text: "First section text",
        language: "en",
        amendment_count: 2,
        created_at: now,
        updated_at: now
      },
      %{
        section_id: "UK_ukpga_2024_1:s.2",
        law_name: "UK_ukpga_2024_1",
        law_id: law_id_binary,
        section_type: "section",
        sort_key: "002.000.000~",
        position: 2,
        depth: 1,
        text: "Second section text",
        language: "en",
        created_at: now,
        updated_at: now
      }
    ])

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
      },
      %{
        id: "UK_ukpga_2024_1:amendment:2",
        law_name: "UK_ukpga_2024_1",
        law_id: law_id_binary,
        code: "F2",
        code_type: "amendment",
        source: "csv_import",
        text: "S. 2 repealed by 2024 c. 5",
        affected_sections: ["UK_ukpga_2024_1:s.2"],
        created_at: now,
        updated_at: now
      }
    ])

    %{law_id: law_id, now: now}
  end

  # ── Auth ────────────────────────────────────────────────────────

  describe "auth" do
    test "returns 401 without auth header", %{conn: conn} do
      conn = get(conn, "/api/lat/stats")
      assert json_response(conn, 401)
    end

    test "returns 200 with valid auth", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/stats")
      assert json_response(conn, 200)
    end
  end

  # ── Stats ──────────────────────────────────────────────────────

  describe "GET /api/lat/stats" do
    test "returns expected stats shape", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/stats")
      resp = json_response(conn, 200)

      assert is_integer(resp["total_lat_rows"])
      assert resp["total_lat_rows"] >= 3
      assert is_integer(resp["laws_with_lat"])
      assert resp["laws_with_lat"] >= 1
      assert is_integer(resp["total_annotations"])
      assert resp["total_annotations"] >= 2
      assert is_integer(resp["laws_with_annotations"])
      assert resp["laws_with_annotations"] >= 1
      assert is_map(resp["section_type_counts"])
      assert is_map(resp["code_type_counts"])
    end

    test "section_type_counts includes test data types", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/stats")
      resp = json_response(conn, 200)

      assert resp["section_type_counts"]["section"] >= 2
      assert resp["section_type_counts"]["title"] >= 1
    end
  end

  # ── Laws list ──────────────────────────────────────────────────

  describe "GET /api/lat/laws" do
    test "returns law list with counts", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws")
      resp = json_response(conn, 200)

      assert is_list(resp["laws"])
      assert resp["count"] >= 1

      law = Enum.find(resp["laws"], &(&1["law_name"] == "UK_ukpga_2024_1"))
      assert law
      assert law["title_en"] == "Test Act 2024"
      assert law["year"] == 2024
      assert law["type_code"] == "ukpga"
      assert law["lat_count"] == 3
      assert law["annotation_count"] == 2
    end

    test "search filters by title", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws", search: "Test Act")
      resp = json_response(conn, 200)

      assert Enum.any?(resp["laws"], &(&1["law_name"] == "UK_ukpga_2024_1"))
    end

    test "search filters by law_name", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws", search: "UK_ukpga_2024")
      resp = json_response(conn, 200)

      assert Enum.any?(resp["laws"], &(&1["law_name"] == "UK_ukpga_2024_1"))
    end

    test "search with no matches returns empty", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws", search: "zzz_nonexistent")
      resp = json_response(conn, 200)

      refute Enum.any?(resp["laws"], &(&1["law_name"] == "UK_ukpga_2024_1"))
    end

    test "type_code filter works", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws", type_code: "ukpga")
      resp = json_response(conn, 200)

      assert Enum.any?(resp["laws"], &(&1["law_name"] == "UK_ukpga_2024_1"))
    end

    test "type_code filter excludes non-matching", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws", type_code: "uksi")
      resp = json_response(conn, 200)

      refute Enum.any?(resp["laws"], &(&1["law_name"] == "UK_ukpga_2024_1"))
    end
  end

  # ── Show (LAT rows) ───────────────────────────────────────────

  describe "GET /api/lat/laws/:law_name" do
    test "returns LAT rows in document order", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_2024_1")
      resp = json_response(conn, 200)

      assert resp["law_name"] == "UK_ukpga_2024_1"
      assert resp["count"] == 3
      assert resp["total_count"] == 3
      assert resp["has_more"] == false

      # Check document order (sort_key ASC)
      types = Enum.map(resp["rows"], & &1["section_type"])
      assert types == ["title", "section", "section"]
    end

    test "rows include expected fields", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_2024_1")
      resp = json_response(conn, 200)

      row = Enum.find(resp["rows"], &(&1["section_id"] == "UK_ukpga_2024_1:s.1"))
      assert row["text"] == "First section text"
      assert row["depth"] == 1
      assert row["amendment_count"] == 2
      assert row["language"] == "en"
      assert is_binary(row["created_at"])
    end

    test "pagination with limit and offset", %{conn: conn} do
      conn =
        conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_2024_1", limit: "2", offset: "0")

      resp = json_response(conn, 200)

      assert resp["count"] == 2
      assert resp["total_count"] == 3
      assert resp["has_more"] == true
      assert resp["limit"] == 2
      assert resp["offset"] == 0
    end

    test "pagination offset works", %{conn: conn} do
      conn =
        conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_2024_1", limit: "2", offset: "2")

      resp = json_response(conn, 200)

      assert resp["count"] == 1
      assert resp["has_more"] == false
    end

    test "non-existent law returns empty", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_9999_1")
      resp = json_response(conn, 200)

      assert resp["count"] == 0
      assert resp["total_count"] == 0
      assert resp["rows"] == []
    end
  end

  # ── Annotations ────────────────────────────────────────────────

  describe "GET /api/lat/laws/:law_name/annotations" do
    test "returns annotations for a law", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_2024_1/annotations")
      resp = json_response(conn, 200)

      assert resp["law_name"] == "UK_ukpga_2024_1"
      assert resp["count"] == 2
    end

    test "annotations include expected fields", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_2024_1/annotations")
      resp = json_response(conn, 200)

      ann = Enum.find(resp["annotations"], &(&1["id"] == "UK_ukpga_2024_1:amendment:1"))
      assert ann["code"] == "F1"
      assert ann["code_type"] == "amendment"
      assert ann["source"] == "csv_import"
      assert ann["text"] == "Words substituted by S.I. 2024/100"
      assert ann["affected_sections"] == ["UK_ukpga_2024_1:s.1"]
    end

    test "non-existent law returns empty", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/lat/laws/UK_ukpga_9999_1/annotations")
      resp = json_response(conn, 200)

      assert resp["count"] == 0
      assert resp["annotations"] == []
    end
  end

  # ── Reparse ────────────────────────────────────────────────────

  describe "POST /api/lat/laws/:law_name/reparse" do
    test "returns 422 for non-existent law", %{conn: conn} do
      conn = conn |> put_auth_header() |> post("/api/lat/laws/UK_ukpga_9999_1/reparse")
      resp = json_response(conn, 422)

      assert is_binary(resp["error"])
    end
  end
end
