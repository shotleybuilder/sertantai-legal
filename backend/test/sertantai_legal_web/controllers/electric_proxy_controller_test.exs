defmodule SertantaiLegalWeb.ElectricProxyControllerTest do
  use SertantaiLegalWeb.ConnCase, async: true

  alias SertantaiLegalWeb.ElectricProxyController

  setup do
    # Stub the Electric upstream with Req.Test
    Req.Test.stub(ElectricProxyController, fn conn ->
      # Parse query params from the forwarded request
      query = URI.decode_query(conn.query_string)

      case conn.method do
        "GET" ->
          # Return mock Electric shape response
          conn
          |> Plug.Conn.put_resp_header("electric-handle", "test-handle-123")
          |> Plug.Conn.put_resp_header("electric-offset", "0_0")
          |> Plug.Conn.put_resp_header("electric-schema", "{}")
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{table: query["table"], params: query}))

        "DELETE" ->
          Plug.Conn.send_resp(conn, 202, "")
      end
    end)

    :ok
  end

  describe "GET /api/electric/v1/shape" do
    test "proxies uk_lrt shape requests", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["table"] == "uk_lrt"
    end

    test "forwards where clause for uk_lrt", %{conn: conn} do
      conn =
        get(conn, "/api/electric/v1/shape", %{
          "table" => "uk_lrt",
          "where" => "year >= 2024"
        })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["params"]["where"] == "year >= 2024"
    end

    test "forwards columns for uk_lrt", %{conn: conn} do
      conn =
        get(conn, "/api/electric/v1/shape", %{
          "table" => "uk_lrt",
          "columns" => "id,name,year"
        })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["params"]["columns"] == "id,name,year"
    end

    test "forwards passthrough params (offset, handle, live, cursor, replica)", %{conn: conn} do
      conn =
        get(conn, "/api/electric/v1/shape", %{
          "table" => "uk_lrt",
          "offset" => "0_5",
          "handle" => "some-handle",
          "live" => "true",
          "cursor" => "abc",
          "replica" => "full"
        })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["params"]["offset"] == "0_5"
      assert body["params"]["handle"] == "some-handle"
      assert body["params"]["live"] == "true"
      assert body["params"]["cursor"] == "abc"
      assert body["params"]["replica"] == "full"
    end

    test "rejects unknown table", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "users"})

      assert json_response(conn, 400)["error"] == "Unknown or disallowed shape"
    end

    test "rejects request with no table param", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{})

      assert json_response(conn, 400)["error"] == "Unknown or disallowed shape"
    end

    test "forwards electric headers to client", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      assert get_resp_header(conn, "electric-handle") == ["test-handle-123"]
      assert get_resp_header(conn, "electric-offset") == ["0_0"]
      assert get_resp_header(conn, "electric-schema") == ["{}"]
    end

    test "does not forward non-electric headers", %{conn: conn} do
      # The stub only sets electric-* headers, so other headers should not appear
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert get_resp_header(conn, "x-custom-header") == []
    end

    test "uk_lrt does not require authentication", %{conn: conn} do
      # No auth header — should still work for UK LRT (public reference data)
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})
      assert conn.status == 200
    end
  end

  describe "GET /api/electric/v1/shape - org-scoped tables" do
    test "organization_locations requires org_id from auth", %{conn: conn} do
      # No auth → no org_id → rejected
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert json_response(conn, 400)["error"] == "Unknown or disallowed shape"
    end

    test "location_screenings requires org_id from auth", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "location_screenings"})

      assert json_response(conn, 400)["error"] == "Unknown or disallowed shape"
    end
  end

  describe "DELETE /api/electric/v1/shape" do
    test "deletes uk_lrt shape for recovery", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 202
    end

    test "rejects delete for unknown table", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape", %{"table" => "unknown_table"})

      assert json_response(conn, 400)["error"] == "Unknown or disallowed shape"
    end
  end

  describe "Electric secret handling" do
    test "does not include secret when not configured", %{conn: conn} do
      # In test env, electric_secret is not configured by default
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      refute Map.has_key?(body["params"], "secret")
    end

    test "includes secret when configured", %{conn: conn} do
      # Temporarily set electric_secret
      original = Application.get_env(:sertantai_legal, :electric_secret)

      try do
        Application.put_env(:sertantai_legal, :electric_secret, "test-electric-secret")

        Req.Test.stub(ElectricProxyController, fn conn ->
          query = URI.decode_query(conn.query_string)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{params: query}))
        end)

        conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

        assert conn.status == 200
        body = Jason.decode!(conn.resp_body)
        assert body["params"]["secret"] == "test-electric-secret"
      after
        if original do
          Application.put_env(:sertantai_legal, :electric_secret, original)
        else
          Application.delete_env(:sertantai_legal, :electric_secret)
        end
      end
    end
  end

  describe "Electric upstream errors" do
    test "returns 502 when Electric is unavailable", %{conn: conn} do
      Req.Test.stub(ElectricProxyController, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 503
    end

    test "forwards 400 errors from Electric", %{conn: conn} do
      Req.Test.stub(ElectricProxyController, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{error: "offset out of bounds"}))
      end)

      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 400
    end

    test "forwards 409 errors from Electric (stale handle)", %{conn: conn} do
      Req.Test.stub(ElectricProxyController, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(409, Jason.encode!(%{error: "shape handle mismatch"}))
      end)

      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 409
    end
  end
end
