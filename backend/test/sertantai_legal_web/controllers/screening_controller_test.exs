defmodule SertantaiLegalWeb.ScreeningControllerTest do
  use SertantaiLegalWeb.ConnCase, async: true

  import SertantaiLegal.AuthHelpers

  alias SertantaiLegal.Repo

  setup :setup_auth

  # Use a real UUID for the test org (default_org_id is not UUID format)
  @test_org_id "00000000-1111-2222-3333-444444444444"

  setup do
    {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

    # Seed test laws (delete first to avoid conflicts on partitioned table)
    Repo.query!(
      "DELETE FROM legal_register WHERE name IN ($1, $2)",
      ["UK_uksi_2024_TEST1", "UK_uksi_2024_TEST2"]
    )

    Repo.query!(
      "INSERT INTO legal_register (id, name, country, jurisdiction, title_en, year, type_code, is_making, live, created_at, updated_at)
       VALUES (gen_random_uuid(), $1, 'uk', 'UK', $2, 2024, 'uksi', true, '✔ In force', NOW(), NOW()),
              (gen_random_uuid(), $3, 'uk', 'UK', $4, 2024, 'uksi', true, '✔ In force', NOW(), NOW())",
      [
        "UK_uksi_2024_TEST1",
        "Test Safety Regulations",
        "UK_uksi_2024_TEST2",
        "Test Environment Regulations"
      ]
    )

    # Clean up any prior test applicabilities
    Repo.query!("DELETE FROM org_applicabilities WHERE organization_id = $1", [org_id_binary])

    %{org_id: @test_org_id}
  end

  describe "GET /api/screening/applicabilities" do
    test "returns empty list when no applicabilities exist", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/applicabilities")

      body = json_response(conn, 200)

      assert body["count"] == 0
      assert body["applicabilities"] == []
    end

    test "returns applicabilities for the org", %{conn: conn} do
      {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

      Repo.query!(
        "INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, inserted_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, 'yes', 'manual', NOW(), NOW())",
        [org_id_binary, "UK_uksi_2024_TEST1"]
      )

      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/applicabilities")

      body = json_response(conn, 200)

      assert body["count"] == 1
      assert hd(body["applicabilities"])["law_name"] == "UK_uksi_2024_TEST1"
      assert hd(body["applicabilities"])["status"] == "yes"
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/screening/applicabilities")
      assert json_response(conn, 401)
    end
  end

  describe "PUT /api/screening/applicabilities/:law_name" do
    test "creates new applicability record", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})

      body = json_response(conn, 200)
      assert body["law_name"] == "UK_uksi_2024_TEST1"
      assert body["status"] == "yes"
      assert body["source"] == "manual"
      assert body["reviewed_at"] != nil
    end

    test "upserts existing record", %{conn: conn} do
      {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

      Repo.query!(
        "INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, inserted_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, 'no', 'enhesa_import', NOW(), NOW())",
        [org_id_binary, "UK_uksi_2024_TEST1"]
      )

      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{
          status: "yes",
          notes: "Confirmed applicable"
        })

      body = json_response(conn, 200)
      assert body["status"] == "yes"
      assert body["notes"] == "Confirmed applicable"
      assert body["source"] == "manual"
    end
  end

  describe "POST /api/screening/applicabilities/bulk" do
    test "bulk updates multiple laws", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> post("/api/screening/applicabilities/bulk", %{
          law_names: ["UK_uksi_2024_TEST1", "UK_uksi_2024_TEST2"],
          status: "yes"
        })

      body = json_response(conn, 200)
      assert body["updated"] == 2
      assert body["failed"] == 0
      assert body["total"] == 2
    end

    test "returns 400 without required params", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> post("/api/screening/applicabilities/bulk", %{status: "yes"})

      assert json_response(conn, 400)
    end
  end

  describe "GET /api/screening/stats" do
    test "returns screening statistics", %{conn: conn} do
      {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

      Repo.query!(
        "INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, inserted_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, 'yes', 'manual', NOW(), NOW())",
        [org_id_binary, "UK_uksi_2024_TEST1"]
      )

      Repo.query!(
        "INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, inserted_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, 'no', 'manual', NOW(), NOW())",
        [org_id_binary, "UK_uksi_2024_TEST2"]
      )

      conn = conn |> put_auth_header(%{"org_id" => @test_org_id}) |> get("/api/screening/stats")
      body = json_response(conn, 200)

      assert body["total_making"] > 0
      assert body["reviewed"] == 2
      assert body["by_status"]["yes"] == 1
      assert body["by_status"]["no"] == 1
    end
  end
end
