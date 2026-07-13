defmodule SertantaiLegal.Sync.ChangeDetectorTest do
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.ChangeDetector
  alias SertantaiLegal.Sync.ApplicabilityEvent

  @test_org_id "00000000-aaaa-bbbb-cccc-dddddddddddd"

  @test_laws [
    "UK_uksi_2024_CD01",
    "UK_uksi_2024_CD02",
    "UK_uksi_2024_CD03",
    "UK_uksi_2024_CD04",
    "UK_uksi_2024_CD05"
  ]

  setup do
    {:ok, org_id_binary} = Ecto.UUID.dump(@test_org_id)

    # Clean up from previous test runs
    Repo.query!("DELETE FROM applicability_events WHERE organization_id = $1", [org_id_binary])
    Repo.query!("DELETE FROM org_applicabilities WHERE organization_id = $1", [org_id_binary])
    Repo.query!("DELETE FROM org_screening_profiles WHERE organization_id = $1", [org_id_binary])
    Repo.query!("DELETE FROM org_entitlements WHERE organization_id = $1", [org_id_binary])
    Repo.query!("DELETE FROM legal_register WHERE name LIKE 'UK_uksi_2024_CD%'", [])

    # Seed test laws
    # CD01: In force, in register — no change expected
    # CD02: Revoked, in register — should trigger law_status_changed
    # CD03: Part revoked, in register — should trigger law_status_changed
    # CD04: In force, NOT in register, Making, matching profile — should trigger new_law_available
    # CD05: In force, NOT in register, Making, NOT matching profile — should NOT trigger
    Repo.query!(
      """
      INSERT INTO legal_register (id, name, country, jurisdiction, title_en, year, type_code,
                                   is_making, live, family, duty_holder, fitness_entities,
                                   geo_region, created_at, updated_at)
      VALUES
        (gen_random_uuid(), $1, 'uk', 'UK', 'Active Safety Regs', 2024, 'uksi',
         true, '✔ In force', '💙 OH&S: Occupational / Personal Safety',
         '{"values": ["Org: Employer"]}', '{employer,premises}', '{England}', NOW(), NOW()),
        (gen_random_uuid(), $2, 'uk', 'UK', 'Revoked Safety Regs', 2024, 'uksi',
         true, '❌ Revoked / Repealed / Abolished', '💙 OH&S: Occupational / Personal Safety',
         '{"values": ["Org: Employer"]}', '{employer,premises}', '{England}', NOW(), NOW()),
        (gen_random_uuid(), $3, 'uk', 'UK', 'Part Revoked Safety Regs', 2024, 'uksi',
         true, '⭕ Part Revocation / Repeal', '💙 OH&S: Occupational / Personal Safety',
         '{"values": ["Org: Employer"]}', '{employer,premises}', '{England}', NOW(), NOW()),
        (gen_random_uuid(), $4, 'uk', 'UK', 'New Matching Safety Regs', 2024, 'uksi',
         true, '✔ In force', '💙 OH&S: Occupational / Personal Safety',
         '{"values": ["Org: Employer"]}', '{employer,premises}', '{England}', NOW(), NOW()),
        (gen_random_uuid(), $5, 'uk', 'UK', 'New Non-Matching Regs', 2024, 'uksi',
         true, '✔ In force', '💚 WASTE',
         '{"values": ["Gvt: Authority"]}', '{landfill}', '{England}', NOW(), NOW())
      """,
      @test_laws
    )

    # Register CD01, CD02, CD03 (CD04, CD05 are not in register)
    for law_name <- Enum.take(@test_laws, 3) do
      Repo.query!(
        """
        INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, inserted_at, updated_at)
        VALUES (gen_random_uuid(), $1, $2, 'yes', 'manual', NOW(), NOW())
        """,
        [org_id_binary, law_name]
      )
    end

    # Org screening profile: Employer, premises
    Repo.query!(
      """
      INSERT INTO org_screening_profiles (id, organization_id, governed_actors, locations, inserted_at, updated_at)
      VALUES (gen_random_uuid(), $1, '{\"Org: Employer\"}', '{premises}', NOW(), NOW())
      """,
      [org_id_binary]
    )

    # Org entitlement: OH&S family only
    Repo.query!(
      """
      INSERT INTO org_entitlements (id, organization_id, families, data_tier, field_tier, source, granted_at, inserted_at, updated_at)
      VALUES (gen_random_uuid(), $1, $2, 'lrt_lat', 'standard', 'manual', NOW(), NOW(), NOW())
      """,
      [org_id_binary, ["💙 OH&S: Occupational / Personal Safety"]]
    )

    on_exit(fn ->
      Repo.query!("DELETE FROM applicability_events WHERE organization_id = $1", [org_id_binary])
      Repo.query!("DELETE FROM org_applicabilities WHERE organization_id = $1", [org_id_binary])

      Repo.query!("DELETE FROM org_screening_profiles WHERE organization_id = $1", [org_id_binary])

      Repo.query!("DELETE FROM org_entitlements WHERE organization_id = $1", [org_id_binary])
      Repo.query!("DELETE FROM legal_register WHERE name LIKE 'UK_uksi_2024_CD%'", [])
    end)

    %{org_id: @test_org_id, org_id_binary: org_id_binary}
  end

  describe "detect_status_changes/2" do
    test "detects revoked laws in register", %{org_id: org_id} do
      {:ok, events} = ChangeDetector.detect_status_changes(org_id)

      assert length(events) == 2
    end

    test "classifies full repeal as major", %{org_id: org_id, org_id_binary: org_id_binary} do
      {:ok, _events} = ChangeDetector.detect_status_changes(org_id)

      {:ok, %{rows: rows}} =
        Repo.query(
          """
          SELECT law_name, materiality, metadata->>'change_type' as change_type
          FROM applicability_events
          WHERE organization_id = $1 AND event = 'law_status_changed'
          ORDER BY law_name
          """,
          [org_id_binary]
        )

      assert length(rows) == 2

      [cd02, cd03] = rows
      [_name, materiality, change_type] = cd02
      assert materiality == "major"
      assert change_type in ["revoked", "repealed"]

      [_name3, materiality3, _change_type3] = cd03
      assert materiality3 == "major"
    end

    test "sets review_due_date 30 days out for major", %{
      org_id: org_id,
      org_id_binary: org_id_binary
    } do
      {:ok, _} = ChangeDetector.detect_status_changes(org_id)

      {:ok, %{rows: [[due_date]]}} =
        Repo.query(
          """
          SELECT review_due_date FROM applicability_events
          WHERE organization_id = $1 AND event = 'law_status_changed'
          LIMIT 1
          """,
          [org_id_binary]
        )

      expected = Date.add(Date.utc_today(), 30)
      assert due_date == expected
    end

    test "does not flag in-force laws", %{org_id: org_id, org_id_binary: org_id_binary} do
      {:ok, _} = ChangeDetector.detect_status_changes(org_id)

      {:ok, %{rows: rows}} =
        Repo.query(
          """
          SELECT law_name FROM applicability_events
          WHERE organization_id = $1 AND event = 'law_status_changed'
          """,
          [org_id_binary]
        )

      law_names = Enum.map(rows, fn [name] -> name end)
      refute "UK_uksi_2024_CD01" in law_names
    end

    test "is idempotent", %{org_id: org_id} do
      {:ok, first} = ChangeDetector.detect_status_changes(org_id)
      {:ok, second} = ChangeDetector.detect_status_changes(org_id)

      assert length(first) == 2
      assert length(second) == 0
    end
  end

  describe "detect_new_laws/1" do
    test "detects matching Making laws not in register", %{org_id: org_id} do
      {:ok, events} = ChangeDetector.detect_new_laws(org_id)

      # CD04 matches (OH&S, Employer, premises) — CD05 doesn't (Waste, Authority, landfill)
      assert length(events) == 1
    end

    test "logs new_law_available with major materiality", %{
      org_id: org_id,
      org_id_binary: org_id_binary
    } do
      {:ok, _} = ChangeDetector.detect_new_laws(org_id)

      {:ok, %{rows: rows}} =
        Repo.query(
          """
          SELECT law_name, materiality, metadata->>'match_score' as score,
                 metadata->>'family' as family
          FROM applicability_events
          WHERE organization_id = $1 AND event = 'new_law_available'
          """,
          [org_id_binary]
        )

      assert length(rows) == 1
      [[law_name, materiality, score, family]] = rows
      assert law_name == "UK_uksi_2024_CD04"
      assert materiality == "major"
      assert String.to_integer(score) > 0
      assert family == "💙 OH&S: Occupational / Personal Safety"
    end

    test "does not detect laws outside subscribed families", %{
      org_id: org_id,
      org_id_binary: org_id_binary
    } do
      {:ok, _} = ChangeDetector.detect_new_laws(org_id)

      {:ok, %{rows: rows}} =
        Repo.query(
          """
          SELECT law_name FROM applicability_events
          WHERE organization_id = $1 AND event = 'new_law_available'
          """,
          [org_id_binary]
        )

      law_names = Enum.map(rows, fn [name] -> name end)
      refute "UK_uksi_2024_CD05" in law_names
    end

    test "does not detect laws already in register", %{
      org_id: org_id,
      org_id_binary: org_id_binary
    } do
      {:ok, _} = ChangeDetector.detect_new_laws(org_id)

      {:ok, %{rows: rows}} =
        Repo.query(
          """
          SELECT law_name FROM applicability_events
          WHERE organization_id = $1 AND event = 'new_law_available'
          """,
          [org_id_binary]
        )

      law_names = Enum.map(rows, fn [name] -> name end)
      refute "UK_uksi_2024_CD01" in law_names
    end

    test "is idempotent", %{org_id: org_id} do
      {:ok, first} = ChangeDetector.detect_new_laws(org_id)
      {:ok, second} = ChangeDetector.detect_new_laws(org_id)

      assert length(first) == 1
      assert length(second) == 0
    end
  end

  describe "detect_score_changes/2" do
    test "returns empty without checkpoint", %{org_id: org_id} do
      {:ok, events} = ChangeDetector.detect_score_changes(org_id)
      assert events == []
    end

    test "detects changes since checkpoint", %{org_id: org_id, org_id_binary: org_id_binary} do
      # Push all test laws to 1 day ago, then move only CD01 to 1 hour ago
      Repo.query!(
        "UPDATE legal_register SET updated_at = NOW() - interval '1 day' WHERE name LIKE 'UK_uksi_2024_CD%'",
        []
      )

      Repo.query!(
        "UPDATE legal_register SET updated_at = NOW() - interval '1 hour' WHERE name = $1",
        ["UK_uksi_2024_CD01"]
      )

      checkpoint = DateTime.add(DateTime.utc_now(), -7200, :second)
      {:ok, events} = ChangeDetector.detect_score_changes(org_id, checkpoint)

      assert length(events) == 1

      {:ok, %{rows: [[law_name, materiality]]}} =
        Repo.query(
          """
          SELECT law_name, materiality FROM applicability_events
          WHERE organization_id = $1 AND event = 'match_score_changed'
          """,
          [org_id_binary]
        )

      assert law_name == "UK_uksi_2024_CD01"
      # manual source → minor
      assert materiality == "minor"
    end
  end

  describe "detect_for_org/2" do
    test "runs all three detectors", %{org_id: org_id} do
      {:ok, counts} = ChangeDetector.detect_for_org(org_id)

      assert counts.status_changes == 2
      assert counts.new_laws == 1
      assert counts.score_changes == 0
    end

    test "is idempotent across full run", %{org_id: org_id} do
      {:ok, first} = ChangeDetector.detect_for_org(org_id)
      {:ok, second} = ChangeDetector.detect_for_org(org_id)

      assert first.status_changes + first.new_laws + first.score_changes == 3
      assert second.status_changes + second.new_laws + second.score_changes == 0
    end
  end

  describe "detect_all/1" do
    test "detects changes across all orgs", %{} do
      {:ok, results} = ChangeDetector.detect_all()

      # At minimum our test org should be in results
      assert map_size(results) >= 1
    end
  end

  describe "pending_changes read action" do
    test "returns unreviewed change detection events", %{org_id: org_id} do
      {:ok, _} = ChangeDetector.detect_for_org(org_id)

      {:ok, pending} = ApplicabilityEvent.pending_changes(org_id)

      assert length(pending) == 3
      assert Enum.all?(pending, fn e -> is_nil(e.decision) end)

      assert Enum.all?(pending, fn e -> e.event in ["law_status_changed", "new_law_available"] end)
    end
  end

  describe "materiality classification" do
    test "revoked = major, part revoked = major", %{org_id: org_id, org_id_binary: org_id_binary} do
      {:ok, _} = ChangeDetector.detect_status_changes(org_id)

      {:ok, %{rows: rows}} =
        Repo.query(
          """
          SELECT law_name, materiality, metadata->>'change_type' as change_type
          FROM applicability_events
          WHERE organization_id = $1 AND event = 'law_status_changed'
          ORDER BY law_name
          """,
          [org_id_binary]
        )

      materialities = Enum.map(rows, fn [_, m, _] -> m end)
      assert Enum.all?(materialities, &(&1 == "major"))
    end

    test "new law available = major", %{org_id: org_id, org_id_binary: org_id_binary} do
      {:ok, _} = ChangeDetector.detect_new_laws(org_id)

      {:ok, %{rows: [[materiality]]}} =
        Repo.query(
          """
          SELECT materiality FROM applicability_events
          WHERE organization_id = $1 AND event = 'new_law_available'
          """,
          [org_id_binary]
        )

      assert materiality == "major"
    end
  end
end
