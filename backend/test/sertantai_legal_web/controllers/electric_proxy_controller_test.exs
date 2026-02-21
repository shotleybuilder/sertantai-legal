defmodule SertantaiLegalWeb.ElectricProxyControllerTest do
  use SertantaiLegalWeb.ConnCase, async: true

  alias SertantaiLegalWeb.ElectricProxyController

  import SertantaiLegal.AuthHelpers

  setup :setup_auth

  setup do
    # Stub the Electric upstream with Req.Test
    Req.Test.stub(ElectricProxyController, fn conn ->
      query = URI.decode_query(conn.query_string)

      case conn.method do
        "GET" ->
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

  # Helper: stub Gatekeeper to approve a table with optional where/columns
  defp stub_gatekeeper_approve(table, opts \\ []) do
    where = Keyword.get(opts, :where)
    columns = Keyword.get(opts, :columns)

    Req.Test.stub(SertantaiLegalWeb.GatekeeperClient, fn conn ->
      shape =
        %{"table" => table}
        |> then(fn s -> if where, do: Map.put(s, "where", where), else: s end)
        |> then(fn s -> if columns, do: Map.put(s, "columns", columns), else: s end)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          status: "success",
          token: "shape-token",
          proxy_url: "http://electric:3000",
          expires_at: System.system_time(:second) + 3600,
          shape: shape
        })
      )
    end)
  end

  # --- All shapes require Gatekeeper validation ---

  describe "GET /api/electric/v1/shape - uk_lrt (via Gatekeeper)" do
    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert json_response(conn, 401)["error"] == "Authentication required"
    end

    test "proxies uk_lrt when Gatekeeper approves", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["table"] == "uk_lrt"
    end

    test "forwards where clause from Gatekeeper response", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt", where: "year >= 2024")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["params"]["where"] == "year >= 2024"
    end

    test "forwards columns from Gatekeeper response", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt", columns: "id,name,year")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["params"]["columns"] == "id,name,year"
    end

    test "forwards passthrough params (offset, handle, live, cursor, replica)", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{
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

    test "forwards electric headers to client", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      assert get_resp_header(conn, "electric-handle") == ["test-handle-123"]
      assert get_resp_header(conn, "electric-offset") == ["0_0"]
      assert get_resp_header(conn, "electric-schema") == ["{}"]
    end

    test "does not forward non-electric headers", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert get_resp_header(conn, "x-custom-header") == []
    end
  end

  # --- Org-scoped shapes ---

  describe "GET /api/electric/v1/shape - org-scoped tables" do
    test "returns 401 when no auth header for org-scoped table", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert json_response(conn, 401)["error"] == "Authentication required"
    end

    test "returns 401 for location_screenings without auth", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "location_screenings"})

      assert json_response(conn, 401)["error"] == "Authentication required"
    end

    test "forwards to Electric when Gatekeeper approves", %{conn: conn} do
      org_id = default_org_id()
      stub_gatekeeper_approve("organization_locations", where: "organization_id = '#{org_id}'")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["table"] == "organization_locations"
      assert body["params"]["where"] == "organization_id = '#{org_id}'"
    end

    test "forwards passthrough params for org-scoped shapes", %{conn: conn} do
      org_id = default_org_id()
      stub_gatekeeper_approve("organization_locations", where: "organization_id = '#{org_id}'")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{
          "table" => "organization_locations",
          "offset" => "0_5",
          "handle" => "some-handle"
        })

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["params"]["offset"] == "0_5"
      assert body["params"]["handle"] == "some-handle"
    end

    test "returns 403 when Gatekeeper denies access", %{conn: conn} do
      Req.Test.stub(SertantaiLegalWeb.GatekeeperClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            status: "error",
            message: "You do not have permission to access this table",
            reason: "unauthorized_table"
          })
        )
      end)

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert json_response(conn, 403)["error"] ==
               "You do not have permission to access this table"

      assert json_response(conn, 403)["reason"] == "unauthorized_table"
    end

    test "returns 502 when Gatekeeper is unavailable", %{conn: conn} do
      Req.Test.stub(SertantaiLegalWeb.GatekeeperClient, fn conn ->
        conn
        |> Plug.Conn.send_resp(503, "Service Unavailable")
      end)

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert json_response(conn, 502)["error"] == "Auth service error"
    end

    test "sends JWT to Gatekeeper in authorization header", %{conn: conn} do
      test_pid = self()
      org_id = default_org_id()

      Req.Test.stub(SertantaiLegalWeb.GatekeeperClient, fn conn ->
        [auth_header] = Plug.Conn.get_req_header(conn, "authorization")
        send(test_pid, {:gatekeeper_auth, auth_header})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            status: "success",
            token: "shape-token",
            proxy_url: "http://electric:3000",
            expires_at: System.system_time(:second) + 3600,
            shape: %{table: "organization_locations", where: "organization_id = '#{org_id}'"}
          })
        )
      end)

      token = build_token()

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert_receive {:gatekeeper_auth, received_header}
      assert received_header == "Bearer #{token}"
    end

    test "sends shape body to Gatekeeper", %{conn: conn} do
      test_pid = self()
      org_id = default_org_id()

      Req.Test.stub(SertantaiLegalWeb.GatekeeperClient, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:gatekeeper_body, Jason.decode!(body)})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            status: "success",
            token: "shape-token",
            proxy_url: "http://electric:3000",
            expires_at: System.system_time(:second) + 3600,
            shape: %{table: "organization_locations", where: "organization_id = '#{org_id}'"}
          })
        )
      end)

      conn
      |> put_auth_header()
      |> get("/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert_receive {:gatekeeper_body, body}
      assert body["shape"]["table"] == "organization_locations"
    end
  end

  # --- Missing/invalid table ---

  describe "GET /api/electric/v1/shape - invalid requests" do
    test "returns 400 for missing table param", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{})

      assert json_response(conn, 400)["error"] == "Missing or invalid table parameter"
    end

    test "unknown table returns 401 without auth (needs Gatekeeper)", %{conn: conn} do
      conn = get(conn, "/api/electric/v1/shape", %{"table" => "users"})

      assert json_response(conn, 401)["error"] == "Authentication required"
    end
  end

  # --- DELETE shape recovery ---

  describe "DELETE /api/electric/v1/shape" do
    test "deletes uk_lrt shape for recovery", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 202
    end

    test "deletes organization_locations shape for recovery", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape", %{"table" => "organization_locations"})

      assert conn.status == 202
    end

    test "deletes location_screenings shape for recovery", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape", %{"table" => "location_screenings"})

      assert conn.status == 202
    end

    test "rejects delete for unknown table", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape", %{"table" => "unknown_table"})

      assert json_response(conn, 400)["error"] == "Unknown or disallowed shape"
    end
  end

  # --- Electric secret handling ---

  describe "Electric secret handling" do
    test "does not include secret when not configured", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      refute Map.has_key?(body["params"], "secret")
    end

    test "includes secret when configured", %{conn: conn} do
      original = Application.get_env(:sertantai_legal, :electric_secret)

      try do
        Application.put_env(:sertantai_legal, :electric_secret, "test-electric-secret")
        stub_gatekeeper_approve("uk_lrt")

        Req.Test.stub(ElectricProxyController, fn conn ->
          query = URI.decode_query(conn.query_string)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{params: query}))
        end)

        conn =
          conn
          |> put_auth_header()
          |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

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

  # --- Electric upstream errors ---

  describe "Electric upstream errors" do
    test "returns error status when Electric returns 503", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      Req.Test.stub(ElectricProxyController, fn conn ->
        Plug.Conn.send_resp(conn, 503, "Service Unavailable")
      end)

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 503
    end

    test "forwards 400 errors from Electric", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      Req.Test.stub(ElectricProxyController, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{error: "offset out of bounds"}))
      end)

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 400
    end

    test "forwards 409 errors from Electric (stale handle)", %{conn: conn} do
      stub_gatekeeper_approve("uk_lrt")

      Req.Test.stub(ElectricProxyController, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(409, Jason.encode!(%{error: "shape handle mismatch"}))
      end)

      conn =
        conn
        |> put_auth_header()
        |> get("/api/electric/v1/shape", %{"table" => "uk_lrt"})

      assert conn.status == 409
    end
  end
end
