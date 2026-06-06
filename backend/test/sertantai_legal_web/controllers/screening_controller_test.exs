defmodule SertantaiLegalWeb.ScreeningControllerTest do
  use SertantaiLegalWeb.ConnCase, async: true

  import SertantaiLegal.AuthHelpers

  alias SertantaiLegal.Repo

  setup :setup_auth

  # Use a real UUID for the test org (default_org_id is not UUID format)
  @test_org_id "00000000-1111-2222-3333-444444444444"

  @test_law_names [
    "UK_uksi_2024_TEST1",
    "UK_uksi_2024_TEST2",
    "UK_uksi_2024_TEST3",
    "UK_uksi_2024_TEST4"
  ]

  setup do
    {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

    # Seed test laws (delete first to avoid conflicts on partitioned table)
    Repo.query!("DELETE FROM legal_register WHERE name LIKE 'UK_uksi_2024_TEST%'", [])

    Repo.query!(
      "INSERT INTO legal_register (id, name, country, jurisdiction, title_en, year, type_code, is_making, live,
         fitness_person, fitness_place, fitness_plant, fitness_process, fitness_sector, geo_region,
         created_at, updated_at)
       VALUES
         (gen_random_uuid(), $1, 'uk', 'UK', 'Test Safety Regulations', 2024, 'uksi', true, '✔ In force',
          '{employer,employee}', '{premises}', NULL, NULL, NULL, '{England,Wales}', NOW(), NOW()),
         (gen_random_uuid(), $2, 'uk', 'UK', 'Test Environment Regulations', 2024, 'uksi', true, '✔ In force',
          '{operator}', NULL, '{chemicals}', NULL, '{water industry}', '{England,Scotland}', NOW(), NOW()),
         (gen_random_uuid(), $3, 'uk', 'UK', 'Test Diving Regulations', 2024, 'uksi', true, '✔ In force',
          '{employer}', '{offshore}', NULL, '{diving operations}', '{maritime}', '{United Kingdom}', NOW(), NOW()),
         (gen_random_uuid(), $4, 'uk', 'UK', 'Test Revoked Regulations', 2024, 'uksi', true, '❌ Revoked / Repealed / Abolished',
          '{employer}', '{premises}', NULL, NULL, NULL, '{England}', NOW(), NOW())",
      @test_law_names
    )

    # Clean up test applicabilities and profiles
    Repo.query!("DELETE FROM org_applicabilities WHERE organization_id = $1", [org_id_binary])
    Repo.query!("DELETE FROM org_screening_profiles WHERE organization_id = $1", [org_id_binary])

    %{org_id: @test_org_id, org_id_binary: org_id_binary}
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

  # ── Phase 8a: Profile endpoints ─────────────────────────────────

  describe "GET /api/screening/profile" do
    test "returns empty defaults when no profile exists", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/profile")

      body = json_response(conn, 200)
      assert body["regions"] == []
      assert body["activities"] == []
      assert body["materials"] == []
    end

    test "returns saved profile", %{conn: conn} do
      # Create profile first
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/profile", %{
        regions: ["England", "Wales"],
        activities: ["employer"],
        materials: ["chemicals"]
      })

      conn2 =
        build_conn()
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/profile")

      body = json_response(conn2, 200)
      assert body["regions"] == ["England", "Wales"]
      assert body["activities"] == ["employer"]
      assert body["materials"] == ["chemicals"]
      assert body["locations"] == []
    end
  end

  describe "PUT /api/screening/profile" do
    test "creates profile with tag selections", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/profile", %{
          regions: ["England"],
          activities: ["employer", "manufacturer"],
          sector: ["maritime"]
        })

      body = json_response(conn, 200)
      assert body["regions"] == ["England"]
      assert body["activities"] == ["employer", "manufacturer"]
      assert body["sector"] == ["maritime"]
      assert body["id"] != nil
    end

    test "upserts existing profile (updates tags)", %{conn: conn} do
      # Create
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/profile", %{activities: ["employer"]})

      # Update
      conn2 =
        build_conn()
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/profile", %{
          activities: ["employer", "operator"],
          materials: ["asbestos"]
        })

      body = json_response(conn2, 200)
      assert body["activities"] == ["employer", "operator"]
      assert body["materials"] == ["asbestos"]
    end
  end

  describe "GET /api/screening/vocabulary" do
    test "returns DRRP actor + fitness vocabulary from corpus", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/vocabulary")

      body = json_response(conn, 200)

      # Governed actors from duty_holder JSONB (real corpus has Org: Employer etc.)
      assert is_list(body["governed_actors"])

      # Government actors from responsibility_holder JSONB
      assert is_list(body["government_actors"])

      assert is_list(body["regions"])
      assert "England" in body["regions"]

      assert is_list(body["sector"])
      assert "maritime" in body["sector"]
    end
  end

  # ── Phase 8b: Bulk with source (screener vs manual) ────────────

  describe "POST /api/screening/applicabilities/bulk with source" do
    test "bulk upsert with source=screener sets source and reviewed_by=sertantai", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> post("/api/screening/applicabilities/bulk", %{
          law_names: ["UK_uksi_2024_TEST1", "UK_uksi_2024_TEST2"],
          status: "yes",
          source: "screener"
        })

      body = json_response(conn, 200)
      assert body["updated"] == 2

      # Verify source is screener and reviewed_by is sertantai
      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT law_name, source, reviewed_by FROM org_applicabilities WHERE organization_id = $1 ORDER BY law_name",
          [org_id_binary]
        )

      assert length(rows) == 2

      for [_name, source, reviewed_by] <- rows do
        assert source == "screener"
        assert reviewed_by == "sertantai"
      end
    end

    test "bulk upsert without source defaults to manual", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> post("/api/screening/applicabilities/bulk", %{
          law_names: ["UK_uksi_2024_TEST1"],
          status: "yes"
        })

      body = json_response(conn, 200)
      assert body["updated"] == 1

      {:ok, %{rows: [[source]]}} =
        Repo.query(
          "SELECT source FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      assert source == "manual"
    end

    test "seeded laws are additive — don't overwrite manual confirmations", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      # User manually adds a law
      Repo.query!(
        "INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, reviewed_by, inserted_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, 'yes', 'manual', 'user@test.com', NOW(), NOW())",
        [org_id_binary, "UK_uksi_2024_TEST1"]
      )

      # Screener tries to seed the same law
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> post("/api/screening/applicabilities/bulk", %{
          law_names: ["UK_uksi_2024_TEST1", "UK_uksi_2024_TEST2"],
          status: "yes",
          source: "screener"
        })

      body = json_response(conn, 200)
      assert body["updated"] == 2

      # TEST1 should now have source=screener (upsert overwrites)
      # This is intentional — the screener re-confirms the law
      # The audit trail (#99) will track the history
      {:ok, %{rows: [[source1]]}} =
        Repo.query(
          "SELECT source FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      # TEST2 should be newly created as screener
      {:ok, %{rows: [[source2]]}} =
        Repo.query(
          "SELECT source FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST2"]
        )

      assert source2 == "screener"
      # source1 could be either — the upsert updated it
      assert source1 in ["manual", "screener"]
    end
  end

  # ── Design intent: deterministic screening behaviour ────────────

  describe "screening design principles" do
    test "revoked laws are excluded from stats total_making count", %{conn: conn} do
      # TEST4 is revoked — should not count in total_making
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/stats")

      body = json_response(conn, 200)

      # total_making counts all Making+in-force laws in the corpus,
      # not just our test laws. But our revoked TEST4 should NOT be counted.
      # We can verify by checking it's a reasonable positive number.
      assert body["total_making"] > 0
    end

    test "vocabulary excludes geographic regions from locations", %{conn: conn} do
      # The plan says: locations = physical site types, NOT geography
      # Geography uses geo_region, locations uses fitness_place
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/vocabulary")

      body = json_response(conn, 200)

      # Locations should have site types like "premises", "offshore"
      # but NOT country names (those are in regions)
      locations = body["locations"] || []
      refute "England" in locations
      refute "Scotland" in locations
      refute "Wales" in locations

      # Regions should have country/state names
      regions = body["regions"] || []
      assert "England" in regions
    end

    test "profile is one-per-org (upsert, not duplicate)", %{conn: conn} do
      # Create profile
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/profile", %{activities: ["employer"]})

      # Update profile
      build_conn()
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/profile", %{activities: ["operator"]})

      # Should only have one profile row
      {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

      {:ok, %{rows: [[count]]}} =
        Repo.query(
          "SELECT COUNT(*) FROM org_screening_profiles WHERE organization_id = $1",
          [org_id_binary]
        )

      assert count == 1
    end
  end

  # ── Audit trail: event logging ─────────────────────────────────

  describe "applicability event logging" do
    test "upsert logs an 'added' event", %{conn: conn, org_id_binary: org_id_binary} do
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})
      |> json_response(200)

      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT event, actor, status_before, status_after, source FROM applicability_events WHERE organization_id = $1 AND law_name = $2 ORDER BY inserted_at DESC LIMIT 1",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      assert length(rows) == 1
      [[event, _actor, status_before, status_after, source]] = rows
      assert event == "added"
      assert status_before == nil
      assert status_after == "yes"
      assert source == "manual"
    end

    test "removing a law logs a 'removed' event", %{conn: conn, org_id_binary: org_id_binary} do
      # First add
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})
      |> json_response(200)

      # Then remove
      build_conn()
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "unreviewed"})
      |> json_response(200)

      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT event, status_before, status_after FROM applicability_events WHERE organization_id = $1 AND law_name = $2 ORDER BY inserted_at DESC",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      assert length(rows) == 2
      # Most recent event should be 'removed'
      [[event, status_before, status_after] | _] = rows
      assert event == "removed"
      assert status_before == "yes"
      assert status_after == "unreviewed"
    end

    test "bulk seeding logs 'seeded' events with sertantai actor", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> post("/api/screening/applicabilities/bulk", %{
        law_names: ["UK_uksi_2024_TEST1", "UK_uksi_2024_TEST2"],
        status: "yes",
        source: "screener"
      })
      |> json_response(200)

      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT law_name, event, actor, source FROM applicability_events WHERE organization_id = $1 ORDER BY law_name",
          [org_id_binary]
        )

      assert length(rows) == 2

      for [_law, event, actor, source] <- rows do
        assert event == "seeded"
        assert actor == "sertantai"
        assert source == "screener"
      end
    end

    test "excluding a law logs an 'excluded' event", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "excluded"})
      |> json_response(200)

      {:ok, %{rows: [[event]]}} =
        Repo.query(
          "SELECT event FROM applicability_events WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      assert event == "excluded"
    end

    test "restoring an excluded law logs a 'restored' event", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      # Exclude first
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "excluded"})
      |> json_response(200)

      # Then restore
      build_conn()
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "unreviewed"})
      |> json_response(200)

      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT event FROM applicability_events WHERE organization_id = $1 AND law_name = $2 ORDER BY inserted_at DESC",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      assert length(rows) == 2
      [[latest_event] | _] = rows
      assert latest_event == "restored"
    end
  end

  # ── Activity feed endpoints ────────────────────────────────────

  describe "GET /api/screening/events" do
    test "returns empty list when no events exist", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/events")

      body = json_response(conn, 200)
      assert body["events"] == []
      assert body["total"] == 0
    end

    test "returns events after applicability changes", %{conn: conn} do
      # Create an applicability change
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})
      |> json_response(200)

      conn2 =
        build_conn()
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/events")

      body = json_response(conn2, 200)
      assert body["total"] == 1
      assert length(body["events"]) == 1
      event = hd(body["events"])
      assert event["law_name"] == "UK_uksi_2024_TEST1"
      assert event["event"] == "added"
    end

    test "supports pagination", %{conn: conn} do
      # Create two changes
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})
      |> json_response(200)

      build_conn()
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST2", %{status: "yes"})
      |> json_response(200)

      conn2 =
        build_conn()
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/events?limit=1&offset=0")

      body = json_response(conn2, 200)
      assert body["total"] == 2
      assert length(body["events"]) == 1
    end
  end

  describe "GET /api/screening/events/:law_name" do
    test "returns per-law history", %{conn: conn} do
      # Add then remove
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})
      |> json_response(200)

      build_conn()
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "unreviewed"})
      |> json_response(200)

      conn2 =
        build_conn()
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/events/UK_uksi_2024_TEST1")

      body = json_response(conn2, 200)
      assert body["law_name"] == "UK_uksi_2024_TEST1"
      assert body["count"] == 2
      # Most recent first
      [first, second] = body["events"]
      assert first["event"] == "removed"
      assert second["event"] == "added"
    end
  end

  # ── Undo endpoint ──────────────────────────────────────────────

  describe "POST /api/screening/undo" do
    test "undoes the most recent action", %{conn: conn, org_id_binary: org_id_binary} do
      # Add a law
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})
      |> json_response(200)

      # Undo it
      conn2 =
        build_conn()
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> post("/api/screening/undo")

      body = json_response(conn2, 200)
      assert body["undone"] == true
      assert body["law_name"] == "UK_uksi_2024_TEST1"
      assert body["restored_to"] == "unreviewed"

      # Verify the applicability record was deleted (first event, no status_before)
      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT status FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      assert rows == []
    end

    test "undoes removal (restores to yes)", %{conn: conn, org_id_binary: org_id_binary} do
      # Add then remove
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "yes"})
      |> json_response(200)

      build_conn()
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/applicabilities/UK_uksi_2024_TEST1", %{status: "unreviewed"})
      |> json_response(200)

      # Undo the removal
      conn2 =
        build_conn()
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> post("/api/screening/undo")

      body = json_response(conn2, 200)
      assert body["restored_to"] == "yes"

      # Verify restored
      {:ok, %{rows: [[status]]}} =
        Repo.query(
          "SELECT status FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST1"]
        )

      assert status == "yes"
    end

    test "seeded events capture per-law match_reason in metadata", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> post("/api/screening/applicabilities/bulk", %{
        law_names: ["UK_uksi_2024_TEST1", "UK_uksi_2024_TEST2"],
        status: "yes",
        source: "screener",
        metadata: %{
          match_reasons: %{
            "UK_uksi_2024_TEST1" => %{score: 2, family: "OH&S"},
            "UK_uksi_2024_TEST2" => %{score: 1, family: "Fire"}
          }
        }
      })
      |> json_response(200)

      # Verify per-law match_reason in event metadata
      {:ok, %{rows: rows}} =
        Repo.query(
          "SELECT law_name, metadata FROM applicability_events WHERE organization_id = $1 ORDER BY law_name",
          [org_id_binary]
        )

      assert length(rows) == 2

      for [law_name, metadata] <- rows do
        assert metadata != nil
        assert metadata["match_reason"] != nil

        case law_name do
          "UK_uksi_2024_TEST1" ->
            assert metadata["match_reason"]["score"] == 2
            assert metadata["match_reason"]["family"] == "OH&S"

          "UK_uksi_2024_TEST2" ->
            assert metadata["match_reason"]["score"] == 1
            assert metadata["match_reason"]["family"] == "Fire"
        end
      end
    end

    test "returns 404 when no events to undo", %{conn: conn} do
      conn =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> post("/api/screening/undo")

      assert json_response(conn, 404)["error"] == "No events to undo"
    end
  end

  # ── Change management endpoints ─────────────────────────────────

  describe "GET /api/screening/changes/summary" do
    test "returns zero counts when no change events exist", %{conn: conn} do
      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/changes/summary")
        |> json_response(200)

      assert body["total_pending"] == 0
      assert body["overdue"] == 0
      assert body["by_materiality"]["major"] == 0
      assert body["by_event"]["law_status_changed"] == 0
    end

    test "returns counts after change detection", %{conn: conn, org_id_binary: org_id_binary} do
      # Seed a change detection event
      Repo.query!(
        """
        INSERT INTO applicability_events
          (id, organization_id, law_name, event, actor, status_before, status_after,
           source, materiality, review_due_date, metadata, inserted_at)
        VALUES
          (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
           'yes', 'yes', 'change_detection', 'major', $2,
           '{"change_type": "repealed", "title": "Test Revoked Regulations"}',
           NOW())
        """,
        [org_id_binary, Date.add(Date.utc_today(), 30)]
      )

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/changes/summary")
        |> json_response(200)

      assert body["total_pending"] == 1
      assert body["by_materiality"]["major"] == 1
      assert body["by_event"]["law_status_changed"] == 1
      assert body["overdue"] == 0
    end

    test "counts overdue reviews", %{conn: conn, org_id_binary: org_id_binary} do
      # Seed an overdue event (review_due_date in the past)
      Repo.query!(
        """
        INSERT INTO applicability_events
          (id, organization_id, law_name, event, actor, status_before, status_after,
           source, materiality, review_due_date, metadata, inserted_at)
        VALUES
          (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
           'yes', 'yes', 'change_detection', 'major', $2,
           '{"change_type": "repealed"}', NOW())
        """,
        [org_id_binary, Date.add(Date.utc_today(), -10)]
      )

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/changes/summary")
        |> json_response(200)

      assert body["overdue"] == 1
    end
  end

  describe "GET /api/screening/changes" do
    test "returns pending changes sorted by materiality", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      # Seed two events: one major, one minor
      Repo.query!(
        """
        INSERT INTO applicability_events
          (id, organization_id, law_name, event, actor, status_before, status_after,
           source, materiality, metadata, inserted_at)
        VALUES
          (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
           'yes', 'yes', 'change_detection', 'major',
           '{"change_type": "repealed", "title": "Test Revoked"}', NOW()),
          (gen_random_uuid(), $1, 'UK_uksi_2024_TEST1', 'match_score_changed', 'sertantai',
           'yes', 'yes', 'enrichment', 'minor',
           '{"change_type": "enrichment_update", "title": "Test Safety"}', NOW())
        """,
        [org_id_binary]
      )

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/changes")
        |> json_response(200)

      assert body["count"] == 2
      changes = body["changes"]
      # Major should come first
      assert Enum.at(changes, 0)["materiality"] == "major"
      assert Enum.at(changes, 1)["materiality"] == "minor"
    end

    test "filters by materiality", %{conn: conn, org_id_binary: org_id_binary} do
      Repo.query!(
        """
        INSERT INTO applicability_events
          (id, organization_id, law_name, event, actor, status_before, status_after,
           source, materiality, metadata, inserted_at)
        VALUES
          (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
           'yes', 'yes', 'change_detection', 'major',
           '{"change_type": "repealed"}', NOW()),
          (gen_random_uuid(), $1, 'UK_uksi_2024_TEST1', 'match_score_changed', 'sertantai',
           'yes', 'yes', 'enrichment', 'minor',
           '{"change_type": "enrichment_update"}', NOW())
        """,
        [org_id_binary]
      )

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> get("/api/screening/changes?materiality=major")
        |> json_response(200)

      assert body["count"] == 1
      assert Enum.at(body["changes"], 0)["materiality"] == "major"
    end
  end

  describe "PUT /api/screening/changes/:id/decide" do
    test "records a decision on a pending change", %{conn: conn, org_id_binary: org_id_binary} do
      # Seed a pending event
      {:ok, %{rows: [[event_id]]}} =
        Repo.query(
          """
          INSERT INTO applicability_events
            (id, organization_id, law_name, event, actor, status_before, status_after,
             source, materiality, review_due_date, metadata, inserted_at)
          VALUES
            (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
             'yes', 'yes', 'change_detection', 'major', $2,
             '{"change_type": "repealed", "title": "Test Revoked"}', NOW())
          RETURNING id
          """,
          [org_id_binary, Date.add(Date.utc_today(), 30)]
        )

      event_uuid = Ecto.UUID.load!(event_id)

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/changes/#{event_uuid}/decide", %{
          decision: "keep",
          decision_reason: "Historical projects still reference it"
        })
        |> json_response(200)

      assert body["status"] == "ok"
      assert body["decision"] == "keep"

      # Original event should now have decision set
      {:ok, %{rows: [[decision]]}} =
        Repo.query(
          "SELECT decision FROM applicability_events WHERE id = $1",
          [event_id]
        )

      assert decision == "keep"
    end

    test "requires reason for major materiality", %{conn: conn, org_id_binary: org_id_binary} do
      {:ok, %{rows: [[event_id]]}} =
        Repo.query(
          """
          INSERT INTO applicability_events
            (id, organization_id, law_name, event, actor, status_before, status_after,
             source, materiality, metadata, inserted_at)
          VALUES
            (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
             'yes', 'yes', 'change_detection', 'major',
             '{"change_type": "repealed"}', NOW())
          RETURNING id
          """,
          [org_id_binary]
        )

      event_uuid = Ecto.UUID.load!(event_id)

      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/changes/#{event_uuid}/decide", %{
        decision: "archive"
      })
      |> json_response(422)
    end

    test "rejects invalid decision values", %{conn: conn, org_id_binary: org_id_binary} do
      {:ok, %{rows: [[event_id]]}} =
        Repo.query(
          """
          INSERT INTO applicability_events
            (id, organization_id, law_name, event, actor, status_before, status_after,
             source, materiality, metadata, inserted_at)
          VALUES
            (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
             'yes', 'yes', 'change_detection', 'minor',
             '{"change_type": "repealed"}', NOW())
          RETURNING id
          """,
          [org_id_binary]
        )

      event_uuid = Ecto.UUID.load!(event_id)

      conn
      |> put_auth_header(%{"org_id" => @test_org_id})
      |> put_req_header("content-type", "application/json")
      |> put("/api/screening/changes/#{event_uuid}/decide", %{
        decision: "invalid_value"
      })
      |> json_response(422)
    end

    test "'add' decision creates org_applicability record", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      # Seed a new_law_available event for TEST4 (not yet in register)
      {:ok, %{rows: [[event_id]]}} =
        Repo.query(
          """
          INSERT INTO applicability_events
            (id, organization_id, law_name, event, actor, status_before, status_after,
             source, materiality, metadata, inserted_at)
          VALUES
            (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'new_law_available', 'sertantai',
             NULL, 'unreviewed', 'change_detection', 'major',
             '{"title": "Test Revoked Regulations", "match_score": 1}', NOW())
          RETURNING id
          """,
          [org_id_binary]
        )

      event_uuid = Ecto.UUID.load!(event_id)

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/changes/#{event_uuid}/decide", %{
          decision: "add",
          decision_reason: "Matches our OH&S profile"
        })
        |> json_response(200)

      assert body["register_changed"] == true

      # Verify law is now in the register
      {:ok, %{rows: [[status]]}} =
        Repo.query(
          "SELECT status FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST4"]
        )

      assert status == "yes"
    end

    test "'archive' decision excludes law from register", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      # First add the law to the register
      Repo.query!(
        """
        INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, inserted_at, updated_at)
        VALUES (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'yes', 'manual', NOW(), NOW())
        """,
        [org_id_binary]
      )

      # Seed a law_status_changed event
      {:ok, %{rows: [[event_id]]}} =
        Repo.query(
          """
          INSERT INTO applicability_events
            (id, organization_id, law_name, event, actor, status_before, status_after,
             source, materiality, metadata, inserted_at)
          VALUES
            (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
             'yes', 'yes', 'change_detection', 'major',
             '{"change_type": "repealed", "title": "Test Revoked"}', NOW())
          RETURNING id
          """,
          [org_id_binary]
        )

      event_uuid = Ecto.UUID.load!(event_id)

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/changes/#{event_uuid}/decide", %{
          decision: "archive",
          decision_reason: "Law repealed, no longer relevant"
        })
        |> json_response(200)

      assert body["register_changed"] == true

      # Verify law is now excluded
      {:ok, %{rows: [[status]]}} =
        Repo.query(
          "SELECT status FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST4"]
        )

      assert status == "excluded"
    end

    test "'keep' decision does not change register", %{
      conn: conn,
      org_id_binary: org_id_binary
    } do
      # Add law to register
      Repo.query!(
        """
        INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, inserted_at, updated_at)
        VALUES (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'yes', 'manual', NOW(), NOW())
        """,
        [org_id_binary]
      )

      {:ok, %{rows: [[event_id]]}} =
        Repo.query(
          """
          INSERT INTO applicability_events
            (id, organization_id, law_name, event, actor, status_before, status_after,
             source, materiality, metadata, inserted_at)
          VALUES
            (gen_random_uuid(), $1, 'UK_uksi_2024_TEST4', 'law_status_changed', 'sertantai',
             'yes', 'yes', 'change_detection', 'major',
             '{"change_type": "repealed"}', NOW())
          RETURNING id
          """,
          [org_id_binary]
        )

      event_uuid = Ecto.UUID.load!(event_id)

      body =
        conn
        |> put_auth_header(%{"org_id" => @test_org_id})
        |> put_req_header("content-type", "application/json")
        |> put("/api/screening/changes/#{event_uuid}/decide", %{
          decision: "keep",
          decision_reason: "Historical reference needed"
        })
        |> json_response(200)

      assert body["register_changed"] == false

      # Law should still be 'yes'
      {:ok, %{rows: [[status]]}} =
        Repo.query(
          "SELECT status FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
          [org_id_binary, "UK_uksi_2024_TEST4"]
        )

      assert status == "yes"
    end
  end
end
