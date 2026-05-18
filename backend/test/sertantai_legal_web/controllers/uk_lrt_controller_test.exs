defmodule SertantaiLegalWeb.UkLrtControllerTest do
  use SertantaiLegalWeb.ConnCase

  setup :setup_auth

  # Note: Controller now uses LegalRegister resource (backed by partitioned legal_register table).
  # Legacy /api/laws routes still work via router aliases.
  # Tests use existing database records or test error paths.

  describe "GET /api/laws" do
    test "returns list structure", %{conn: conn} do
      conn = get(conn, "/api/laws")

      response = json_response(conn, 200)
      assert is_list(response["records"])
      assert is_integer(response["count"])
      assert is_integer(response["limit"])
      assert is_integer(response["offset"])
      assert is_boolean(response["has_more"])
    end

    test "supports pagination with limit and offset", %{conn: conn} do
      conn = get(conn, "/api/laws", %{limit: "10", offset: "0"})

      response = json_response(conn, 200)
      assert response["limit"] == 10
      assert response["offset"] == 0
    end

    test "respects max limit of 100", %{conn: conn} do
      conn = get(conn, "/api/laws", %{limit: "500"})

      response = json_response(conn, 200)
      assert response["limit"] == 100
    end

    test "defaults limit to 50", %{conn: conn} do
      conn = get(conn, "/api/laws")

      response = json_response(conn, 200)
      assert response["limit"] == 50
    end

    test "accepts family filter parameter", %{conn: conn} do
      conn = get(conn, "/api/laws", %{family: "Environment"})

      response = json_response(conn, 200)
      # All returned records should have the specified family (if any)
      Enum.each(response["records"], fn r ->
        assert r["family"] == "Environment" or response["count"] == 0
      end)
    end

    test "accepts year filter parameter", %{conn: conn} do
      conn = get(conn, "/api/laws", %{year: "2024"})

      response = json_response(conn, 200)

      Enum.each(response["records"], fn r ->
        assert r["year"] == 2024 or response["count"] == 0
      end)
    end

    test "accepts type_code filter parameter", %{conn: conn} do
      conn = get(conn, "/api/laws", %{type_code: "uksi"})

      response = json_response(conn, 200)

      Enum.each(response["records"], fn r ->
        assert r["type_code"] == "uksi" or response["count"] == 0
      end)
    end

    test "accepts search parameter", %{conn: conn} do
      conn = get(conn, "/api/laws", %{search: "regulations"})

      response = json_response(conn, 200)
      assert is_list(response["records"])
    end

    test "handles invalid limit gracefully", %{conn: conn} do
      conn = get(conn, "/api/laws", %{limit: "not-a-number"})

      response = json_response(conn, 200)
      # Should fall back to default
      assert response["limit"] == 50
    end
  end

  describe "GET /api/laws/:id" do
    test "returns 404 when record not found", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, "/api/laws/#{fake_id}")

      assert json_response(conn, 404)["error"] == "Record not found"
    end

    test "returns error for invalid UUID format", %{conn: conn} do
      conn = get(conn, "/api/laws/not-a-valid-uuid")

      # Should return error (either 400 or 500 depending on error handling)
      assert conn.status in [400, 404, 500]
    end
  end

  describe "PATCH /api/laws/:id" do
    test "returns 401 without auth", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = patch(conn, "/api/laws/#{fake_id}", %{title_en: "New Title"})

      assert conn.status == 401
    end

    test "returns 404 when record not found", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      conn =
        conn |> put_auth_header() |> patch("/api/laws/#{fake_id}", %{title_en: "New Title"})

      assert json_response(conn, 404)["error"] == "Record not found"
    end

    test "returns error for invalid UUID format", %{conn: conn} do
      conn =
        conn |> put_auth_header() |> patch("/api/laws/invalid-uuid", %{title_en: "New Title"})

      assert conn.status in [400, 404, 500]
    end
  end

  describe "DELETE /api/laws/:id" do
    test "returns 401 without auth", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, "/api/laws/#{fake_id}")

      assert conn.status == 401
    end

    test "returns 404 when record not found", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = conn |> put_auth_header() |> delete("/api/laws/#{fake_id}")

      assert json_response(conn, 404)["error"] == "Record not found"
    end

    test "returns error for invalid UUID format", %{conn: conn} do
      conn = conn |> put_auth_header() |> delete("/api/laws/invalid-uuid")

      assert conn.status in [400, 404, 500]
    end
  end

  describe "GET /api/laws/search" do
    test "works as alias for index", %{conn: conn} do
      conn = get(conn, "/api/laws/search", %{search: "health"})

      response = json_response(conn, 200)
      assert is_list(response["records"])
      assert Map.has_key?(response, "count")
    end
  end

  describe "GET /api/laws/:id/parse-stream" do
    test "returns 401 without auth", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, "/api/laws/#{fake_id}/parse-stream")

      assert conn.status == 401
    end

    test "returns 404 when record not found", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = conn |> put_auth_header() |> get("/api/laws/#{fake_id}/parse-stream")

      assert json_response(conn, 404)["error"] == "Record not found"
    end

    test "returns error for invalid UUID format", %{conn: conn} do
      conn = conn |> put_auth_header() |> get("/api/laws/invalid-uuid/parse-stream")

      assert conn.status in [400, 404, 500]
    end
  end

  describe "GET /api/laws/filters" do
    test "returns filter structure", %{conn: conn} do
      conn = get(conn, "/api/laws/filters")

      response = json_response(conn, 200)
      assert is_list(response["families"])
      assert is_list(response["years"])
    end

    test "families are sorted alphabetically", %{conn: conn} do
      conn = get(conn, "/api/laws/filters")

      response = json_response(conn, 200)
      families = response["families"]

      if length(families) > 1 do
        assert families == Enum.sort(families)
      end
    end

    test "years are sorted descending", %{conn: conn} do
      conn = get(conn, "/api/laws/filters")

      response = json_response(conn, 200)
      years = response["years"]

      if length(years) > 1 do
        assert years == Enum.sort(years, :desc)
      end
    end
  end
end
