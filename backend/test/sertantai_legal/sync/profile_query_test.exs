defmodule SertantaiLegal.Sync.ProfileQueryTest do
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.ProfileQuery

  @test_law_name "UK_uksi_2024_PQ01"

  setup do
    # Clean up from previous runs
    Repo.query!("DELETE FROM legal_register WHERE name = $1", [@test_law_name])

    # Create a test law
    {:ok, %{rows: [[law_id]]}} =
      Repo.query(
        """
        INSERT INTO legal_register (id, name, country, jurisdiction, title_en, year, type_code,
                                     is_making, live, family, created_at, updated_at)
        VALUES (gen_random_uuid(), $1, 'uk', 'UK', 'Profile Query Test Regs', 2024, 'uksi',
                true, '✔ In force', '💙 OH&S: Occupational / Personal Safety', NOW(), NOW())
        RETURNING id
        """,
        [@test_law_name]
      )

    law_uuid = Ecto.UUID.load!(law_id)

    # Create LAT provisions with different actor data scenarios
    Repo.query!(
      """
      INSERT INTO legal_articles (section_id, country, law_name, law_id, sort_key, position,
                                   section_type, depth, text, provision, language,
                                   drrp_types, governed_actors, actors, extraction_method,
                                   created_at, updated_at)
      VALUES
        -- s.1: parent section (no actors, structural)
        ($1 || ':s.1', 'uk', $1, $2, '001', 1, 'section', 0, 'Test section 1',
         '1', 'en', '{Duty}', NULL, NULL, NULL, NOW(), NOW()),

        -- s.1(1): has actors struct with active employer
        ($1 || ':s.1(1)', 'uk', $1, $2, '001.001', 2, 'sub_section', 1,
         'The employer shall ensure safety',
         '1', 'en', '{Duty}',
         '{"Org: Employer","Ind: Employee"}',
         ARRAY['{"label": "Org: Employer", "position": "active", "label_source": "canonical"}'::jsonb,
               '{"label": "Ind: Employee", "position": "counterparty", "label_source": "canonical"}'::jsonb],
         'classifier', NOW(), NOW()),

        -- s.1(2): has flat governed_actors but NO actors struct (older enrichment)
        ($1 || ':s.1(2)', 'uk', $1, $2, '001.002', 3, 'sub_section', 1,
         'Workers shall comply with instructions',
         '1', 'en', '{Duty}',
         '{"Ind: Worker","Ind: Person"}',
         NULL,
         'regex', NOW(), NOW()),

        -- s.2: has actors struct with active manufacturer (different provision)
        ($1 || ':s.2', 'uk', $1, $2, '002', 4, 'section', 0, 'Manufacturer duties',
         '2', 'en', '{Duty}',
         '{"SC: Manufacturer"}',
         ARRAY['{"label": "SC: Manufacturer", "position": "active", "label_source": "canonical"}'::jsonb],
         'regex', NOW(), NOW()),

        -- s.3: has actors struct but only invented labels (should be filtered)
        ($1 || ':s.3', 'uk', $1, $2, '003', 5, 'section', 0, 'Special duties',
         '3', 'en', '{Duty}',
         '{"Some Special Actor"}',
         ARRAY['{"label": "Some Special Actor", "position": "active", "label_source": "invented"}'::jsonb],
         'agentic_unvalidated', NOW(), NOW()),

        -- s.4: has actors struct with mixed positions (right provision)
        ($1 || ':s.4', 'uk', $1, $2, '004', 6, 'section', 0, 'Employee rights',
         '4', 'en', '{Right}',
         '{"Ind: Employee","Org: Employer"}',
         ARRAY['{"label": "Ind: Employee", "position": "active", "label_source": "canonical"}'::jsonb,
               '{"label": "Org: Employer", "position": "counterparty", "label_source": "canonical"}'::jsonb],
         'classifier', NOW(), NOW())
      """,
      [@test_law_name, law_id]
    )

    on_exit(fn ->
      Repo.query!("DELETE FROM legal_articles WHERE law_name = $1", [@test_law_name])
      Repo.query!("DELETE FROM legal_register WHERE name = $1", [@test_law_name])
    end)

    %{law_id: law_uuid, law_id_binary: law_id}
  end

  describe "query_lat_aggregated/2" do
    test "aggregates actors from struct (position=active)", %{law_id_binary: law_id} do
      {:ok, rows} = ProfileQuery.query_lat_aggregated([law_id])

      s1 = Enum.find(rows, &(&1.provision == "1"))
      assert s1 != nil
      # s.1(1) has Org: Employer as active in struct
      assert "Org: Employer" in (s1.governed_actors || [])
    end

    test "falls back to flat governed_actors when struct is null", %{law_id_binary: law_id} do
      {:ok, rows} = ProfileQuery.query_lat_aggregated([law_id])

      s1 = Enum.find(rows, &(&1.provision == "1"))
      # s.1(2) has no actors struct but has flat governed_actors with Worker + Person
      assert "Ind: Worker" in (s1.governed_actors || [])
      assert "Ind: Person" in (s1.governed_actors || [])
    end

    test "unions struct and flat actors in same provision group", %{law_id_binary: law_id} do
      {:ok, rows} = ProfileQuery.query_lat_aggregated([law_id])

      s1 = Enum.find(rows, &(&1.provision == "1"))
      actors = s1.governed_actors || []

      # From struct (s.1(1)): Org: Employer (active)
      assert "Org: Employer" in actors
      # From flat fallback (s.1(2)): Ind: Worker, Ind: Person
      assert "Ind: Worker" in actors
      # Counterparty from struct should NOT appear
      refute "Ind: Employee" in actors
    end

    test "does not include invented labels", %{law_id_binary: law_id} do
      {:ok, rows} = ProfileQuery.query_lat_aggregated([law_id])

      s3 = Enum.find(rows, &(&1.provision == "3"))
      # s.3 only has invented labels — governed_actors should be nil or empty
      actors = s3.governed_actors || []
      refute "Some Special Actor" in actors
    end

    test "filters by drrp_types", %{law_id_binary: law_id} do
      {:ok, duty_rows} = ProfileQuery.query_lat_aggregated([law_id], drrp_types: ["Duty"])

      provisions = Enum.map(duty_rows, & &1.provision)
      # s.4 is Right only, should be excluded
      refute "4" in provisions
      # s.1 and s.2 have Duty
      assert "1" in provisions
      assert "2" in provisions
    end

    test "aggregates drrp_types across sub-provisions", %{law_id_binary: law_id} do
      {:ok, rows} = ProfileQuery.query_lat_aggregated([law_id])

      s1 = Enum.find(rows, &(&1.provision == "1"))
      assert "Duty" in (s1.drrp_types || [])
    end

    test "returns section_id in correct format", %{law_id_binary: law_id} do
      {:ok, rows} = ProfileQuery.query_lat_aggregated([law_id])

      s2 = Enum.find(rows, &(&1.provision == "2"))
      # SI uses reg. prefix
      assert s2.section_id == "#{@test_law_name}:reg.2"
    end

    test "returns empty list for empty input" do
      {:ok, rows} = ProfileQuery.query_lat_aggregated([])
      assert rows == []
    end
  end
end
