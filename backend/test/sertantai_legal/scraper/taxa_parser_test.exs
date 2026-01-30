defmodule SertantaiLegal.Scraper.TaxaParserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.TaxaParser

  describe "large_law_threshold/0" do
    test "returns default threshold of 200,000 characters" do
      # Default threshold should be 200KB
      assert TaxaParser.large_law_threshold() == 200_000
    end

    test "threshold is configurable via application env" do
      # Save original value
      original = Application.get_env(:sertantai_legal, :large_law_threshold)

      try do
        # Set custom threshold
        Application.put_env(:sertantai_legal, :large_law_threshold, 100_000)
        assert TaxaParser.large_law_threshold() == 100_000

        # Set another value
        Application.put_env(:sertantai_legal, :large_law_threshold, 500_000)
        assert TaxaParser.large_law_threshold() == 500_000
      after
        # Restore original value
        if original do
          Application.put_env(:sertantai_legal, :large_law_threshold, original)
        else
          Application.delete_env(:sertantai_legal, :large_law_threshold)
        end
      end
    end
  end

  describe "large_law?/1" do
    test "returns false for text under threshold" do
      refute TaxaParser.large_law?(100_000)
      refute TaxaParser.large_law?(199_999)
      refute TaxaParser.large_law?(0)
    end

    test "returns false for text at exactly threshold" do
      # At threshold is NOT large (must exceed)
      refute TaxaParser.large_law?(200_000)
    end

    test "returns true for text over threshold" do
      assert TaxaParser.large_law?(200_001)
      assert TaxaParser.large_law?(500_000)
      assert TaxaParser.large_law?(1_000_000)
    end

    test "respects custom threshold from application env" do
      original = Application.get_env(:sertantai_legal, :large_law_threshold)

      try do
        Application.put_env(:sertantai_legal, :large_law_threshold, 50_000)

        # Under new threshold
        refute TaxaParser.large_law?(40_000)
        refute TaxaParser.large_law?(50_000)

        # Over new threshold
        assert TaxaParser.large_law?(50_001)
        assert TaxaParser.large_law?(100_000)
      after
        if original do
          Application.put_env(:sertantai_legal, :large_law_threshold, original)
        else
          Application.delete_env(:sertantai_legal, :large_law_threshold)
        end
      end
    end
  end

  describe "classify_text/2 with telemetry" do
    test "emits telemetry with large_law: false for small text" do
      # Attach a telemetry handler to capture events
      test_pid = self()
      handler_id = "test-small-law-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:taxa, :classify, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      try do
        text = "The employer shall ensure safety."
        _result = TaxaParser.classify_text(text, "test", law_name: "test/2024/1")

        assert_receive {:telemetry, measurements, metadata}, 5000
        assert measurements.text_length < TaxaParser.large_law_threshold()
        assert metadata.large_law == false
      after
        :telemetry.detach(handler_id)
      end
    end

    test "emits telemetry with large_law: true for large text" do
      # Attach a telemetry handler to capture events
      test_pid = self()
      handler_id = "test-large-law-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:taxa, :classify, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      try do
        # Set a low threshold for testing
        original = Application.get_env(:sertantai_legal, :large_law_threshold)
        Application.put_env(:sertantai_legal, :large_law_threshold, 50)

        text =
          "The employer shall ensure the health and safety of employees at work. " <>
            String.duplicate("Additional text. ", 10)

        _result = TaxaParser.classify_text(text, "test", law_name: "test/2024/1")

        assert_receive {:telemetry, measurements, metadata}, 5000
        assert measurements.text_length > 50
        assert metadata.large_law == true

        # Restore threshold
        if original do
          Application.put_env(:sertantai_legal, :large_law_threshold, original)
        else
          Application.delete_env(:sertantai_legal, :large_law_threshold)
        end
      after
        :telemetry.detach(handler_id)
      end
    end
  end

  describe "classify_text/2" do
    test "classifies employer duty provision" do
      text = "The employer shall ensure the health and safety of employees at work."

      result = TaxaParser.classify_text(text, "test")

      # Actor extraction
      assert "Org: Employer" in result.role
      assert "Ind: Employee" in result.role

      # Duty type classification
      assert "Duty" in result.duty_type

      # Duty holder - returns plain list
      assert is_list(result.duty_holder)
      assert "Org: Employer" in result.duty_holder

      # Metadata
      assert result.taxa_text_source == "test"
      assert result.taxa_text_length > 0
    end

    test "classifies government responsibility provision" do
      text = "The local authority must investigate all reported incidents."

      result = TaxaParser.classify_text(text, "test")

      # Government actor - now returns list, not jsonb map
      assert result.role_gvt != nil
      assert "Gvt: Authority: Local" in result.role_gvt

      # Responsibility type
      assert "Responsibility" in result.duty_type

      # Responsibility holder
      assert result.responsibility_holder != nil
    end

    test "classifies training provision with POPIMAR" do
      text = "The employer shall provide training to all employees."

      result = TaxaParser.classify_text(text, "test")

      # POPIMAR classification - returns list, not map
      assert result.popimar != nil
      assert "Organisation - Competence" in result.popimar
    end

    test "classifies record keeping provision" do
      text = "The employer shall keep a record of all risk assessments conducted."

      result = TaxaParser.classify_text(text, "test")

      # POPIMAR - Records category (returns list)
      assert result.popimar != nil
      assert "Records" in result.popimar
    end

    test "classifies rights provision" do
      text = "The employee may request a copy of any relevant assessment."

      result = TaxaParser.classify_text(text, "test")

      # Right classification
      assert "Right" in result.duty_type

      # Rights holder - returns plain list
      assert is_list(result.rights_holder)
      assert "Ind: Employee" in result.rights_holder
    end

    test "classifies ministerial power provision" do
      text = "The Secretary of State may by regulations prescribe additional requirements."

      result = TaxaParser.classify_text(text, "test")

      # Government actor - now returns list, not jsonb map
      assert result.role_gvt != nil
      assert "Gvt: Minister" in result.role_gvt

      # Power classification
      assert "Power" in result.duty_type or "Power Conferred" in result.duty_type

      # Power holder
      assert result.power_holder != nil
    end

    test "handles empty text" do
      result = TaxaParser.classify_text("", "test")

      assert result.role == []
      assert result.role_gvt == nil
      assert result.duty_type == []
      assert result.taxa_text_length == 0
    end

    test "handles text with no actors" do
      text = "The requirements set out in Schedule 1 shall apply."

      result = TaxaParser.classify_text(text, "test")

      # Should still process without errors
      assert is_list(result.role)
      assert is_list(result.duty_type)
      assert result.taxa_text_length > 0
    end

    test "classifies multi-actor provision" do
      text = """
      The employer shall consult with employees and their representatives
      on matters of health and safety.
      """

      result = TaxaParser.classify_text(text, "test")

      # Multiple actors
      assert "Org: Employer" in result.role
      assert "Ind: Employee" in result.role

      # Communication & Consultation POPIMAR (returns list)
      assert result.popimar != nil
      assert "Organisation - Communication & Consultation" in result.popimar
    end

    test "classifies supply chain actors" do
      text = "The manufacturer shall provide instructions to the supplier and importer."

      result = TaxaParser.classify_text(text, "test")

      # Supply chain actors
      assert "SC: Manufacturer" in result.role
      assert "SC: Supplier" in result.role
      assert "SC: Importer" in result.role
    end

    test "classifies notification provision" do
      text = "The employer shall notify the authority of any dangerous occurrence."

      result = TaxaParser.classify_text(text, "test")

      # Notification POPIMAR (returns list)
      assert result.popimar != nil
      assert "Notification" in result.popimar
    end

    test "classifies risk assessment provision" do
      text = "The employer shall carry out a suitable and sufficient risk assessment."

      result = TaxaParser.classify_text(text, "test")

      # Risk assessment POPIMAR (returns list)
      assert result.popimar != nil
      assert "Planning & Risk / Impact Assessment" in result.popimar
    end

    test "classifies policy provision" do
      text = "The employer shall establish a health and safety policy."

      result = TaxaParser.classify_text(text, "test")

      # Policy POPIMAR (returns list)
      assert result.popimar != nil
      assert "Policy" in result.popimar
    end

    test "classifies review provision" do
      text = "The employer shall review the assessment whenever circumstances change."

      result = TaxaParser.classify_text(text, "test")

      # Review POPIMAR (returns list)
      assert result.popimar != nil
      assert "Review" in result.popimar
    end
  end

  describe "result format" do
    test "returns all expected keys" do
      text = "The employer shall ensure safety."

      result = TaxaParser.classify_text(text, "test")

      assert Map.has_key?(result, :role)
      assert Map.has_key?(result, :role_gvt)
      assert Map.has_key?(result, :duty_type)
      assert Map.has_key?(result, :duty_holder)
      assert Map.has_key?(result, :rights_holder)
      assert Map.has_key?(result, :responsibility_holder)
      assert Map.has_key?(result, :power_holder)
      assert Map.has_key?(result, :popimar)
      assert Map.has_key?(result, :taxa_text_source)
      assert Map.has_key?(result, :taxa_text_length)
    end

    test "role_gvt is empty list when no government actors" do
      text = "The employer shall ensure safety."

      result = TaxaParser.classify_text(text, "test")

      assert result.role_gvt == []
    end

    test "role_gvt is list when government actors present" do
      text = "The Minister may prescribe requirements."

      result = TaxaParser.classify_text(text, "test")

      assert is_list(result.role_gvt)
      assert length(result.role_gvt) > 0
      assert "Gvt: Minister" in result.role_gvt
    end
  end

  describe "classify_text_chunked/4 (Phase 6 P1 chunking)" do
    # P1 chunking processes each section in parallel for large laws

    test "processes multiple P1 sections and merges results" do
      # Full text for actor extraction
      text = """
      The employer shall ensure health and safety.
      The employee may request information.
      The local authority must investigate complaints.
      The Secretary of State may by regulations prescribe requirements.
      """

      # Simulate P1 sections (what would be extracted from XML)
      p1_sections = [
        {"section-1", "The employer shall ensure health and safety."},
        {"section-2", "The employee may request information."},
        {"section-3", "The local authority must investigate complaints."},
        {"section-4", "The Secretary of State may by regulations prescribe requirements."}
      ]

      result =
        TaxaParser.classify_text_chunked(text, "test", p1_sections, law_name: "test/chunked")

      # Should find all duty types from different sections
      assert "Duty" in result.duty_type
      assert "Right" in result.duty_type
      assert "Responsibility" in result.duty_type
      assert "Power" in result.duty_type

      # Should find duty holder from section 1
      assert "Org: Employer" in result.duty_holder

      # Should find rights holder from section 2
      assert "Ind: Employee" in result.rights_holder

      # Should find responsibility holder from section 3
      assert "Gvt: Authority: Local" in result.responsibility_holder

      # Should find power holder from section 4
      assert "Gvt: Minister" in result.power_holder
    end

    test "deduplicates results across sections" do
      text = """
      The employer shall ensure safety. The employer shall provide training.
      The employer shall maintain equipment.
      """

      # Same actor across multiple sections
      p1_sections = [
        {"section-1", "The employer shall ensure safety."},
        {"section-2", "The employer shall provide training."},
        {"section-3", "The employer shall maintain equipment."}
      ]

      result = TaxaParser.classify_text_chunked(text, "test", p1_sections, law_name: "test/dedup")

      # Duty type should appear once, not three times
      duty_count = Enum.count(result.duty_type, &(&1 == "Duty"))
      assert duty_count == 1

      # Employer should appear once in duty holders
      employer_count = Enum.count(result.duty_holder, &(&1 == "Org: Employer"))
      assert employer_count == 1
    end

    test "handles empty P1 sections gracefully" do
      text = "The employer shall ensure safety."

      # Mix of empty and non-empty sections
      p1_sections = [
        {"section-1", ""},
        {"section-2", "The employer shall ensure safety."},
        {"section-3", "   "}
      ]

      result = TaxaParser.classify_text_chunked(text, "test", p1_sections, law_name: "test/empty")

      # Should still find duty from non-empty section
      assert "Duty" in result.duty_type
      assert "Org: Employer" in result.duty_holder
    end

    test "extracts actors from full text, not just sections" do
      # Full text mentions employee, but sections only have employer duties
      text = """
      The employer and employee must work together.
      The employer shall ensure safety.
      The employer shall provide training.
      """

      p1_sections = [
        {"section-1", "The employer shall ensure safety."},
        {"section-2", "The employer shall provide training."}
      ]

      result =
        TaxaParser.classify_text_chunked(text, "test", p1_sections, law_name: "test/actors")

      # Should find both actors from full text
      assert "Org: Employer" in result.role
      assert "Ind: Employee" in result.role

      # But only employer has duties (from sections)
      assert "Org: Employer" in result.duty_holder
    end

    test "returns proper structure with all expected fields" do
      text = "The employer shall ensure safety."
      p1_sections = [{"section-1", "The employer shall ensure safety."}]

      result =
        TaxaParser.classify_text_chunked(text, "test", p1_sections, law_name: "test/structure")

      # Verify all expected fields are present
      assert Map.has_key?(result, :role)
      assert Map.has_key?(result, :role_gvt)
      assert Map.has_key?(result, :duty_type)
      assert Map.has_key?(result, :duty_holder)
      assert Map.has_key?(result, :rights_holder)
      assert Map.has_key?(result, :responsibility_holder)
      assert Map.has_key?(result, :power_holder)
      assert Map.has_key?(result, :popimar)
      assert Map.has_key?(result, :purpose)
      assert Map.has_key?(result, :taxa_text_source)
      assert Map.has_key?(result, :taxa_text_length)
    end

    test "JSONB holder fields contain article from section_id (regression for Issue #14 bug)" do
      # This test verifies the fix for the bug where JSONB holder fields
      # (duties, rights, responsibilities, powers) were not receiving the
      # article field from P1 section IDs in the chunked processing path.
      #
      # Root cause was: result map was getting JSONB fields from `merged_record`
      # (which didn't have them) instead of `duty_type_results`.
      #
      # JSONB structure is: %{"articles" => [...], "entries" => [...], "holders" => [...]}

      text = """
      The employer shall ensure the health and safety of employees at work.
      The employee may request a copy of any risk assessment.
      The local authority must investigate all reported incidents.
      The Secretary of State may by regulations prescribe additional requirements.
      """

      p1_sections = [
        {"regulation-4", "The employer shall ensure the health and safety of employees at work."},
        {"regulation-5", "The employee may request a copy of any risk assessment."},
        {"regulation-6", "The local authority must investigate all reported incidents."},
        {"regulation-7",
         "The Secretary of State may by regulations prescribe additional requirements."}
      ]

      result =
        TaxaParser.classify_text_chunked(text, "test", p1_sections, law_name: "uksi/2024/test")

      # Verify JSONB fields are populated (not nil)
      assert result.duties != nil, "duties should be populated"
      assert result.rights != nil, "rights should be populated"
      assert result.responsibilities != nil, "responsibilities should be populated"
      assert result.powers != nil, "powers should be populated"

      # Verify duties JSONB structure and article field
      assert is_map(result.duties), "duties should be a map"
      assert Map.has_key?(result.duties, "articles"), "duties should have 'articles' key"
      assert Map.has_key?(result.duties, "entries"), "duties should have 'entries' key"
      assert Map.has_key?(result.duties, "holders"), "duties should have 'holders' key"

      # Articles list should contain the section ID
      assert "regulation-4" in result.duties["articles"],
             "duties articles should contain 'regulation-4'"

      # Entries should have article field on each entry
      duty_entry =
        Enum.find(result.duties["entries"], fn entry ->
          Map.get(entry, "holder") == "Org: Employer"
        end)

      assert duty_entry != nil, "Should find employer duty entry"

      assert Map.get(duty_entry, "article") == "regulation-4",
             "Duty entry should have article 'regulation-4'"

      # Verify rights JSONB structure and article field
      assert is_map(result.rights), "rights should be a map"

      assert "regulation-5" in result.rights["articles"],
             "rights articles should contain 'regulation-5'"

      rights_entry =
        Enum.find(result.rights["entries"], fn entry ->
          Map.get(entry, "holder") == "Ind: Employee"
        end)

      assert rights_entry != nil, "Should find employee rights entry"

      assert Map.get(rights_entry, "article") == "regulation-5",
             "Rights entry should have article 'regulation-5'"

      # Verify responsibilities JSONB structure and article field
      assert is_map(result.responsibilities), "responsibilities should be a map"

      assert "regulation-6" in result.responsibilities["articles"],
             "responsibilities articles should contain 'regulation-6'"

      resp_entry =
        Enum.find(result.responsibilities["entries"], fn entry ->
          Map.get(entry, "holder") == "Gvt: Authority: Local"
        end)

      assert resp_entry != nil, "Should find local authority responsibility entry"

      assert Map.get(resp_entry, "article") == "regulation-6",
             "Responsibility entry should have article 'regulation-6'"

      # Verify powers JSONB structure and article field
      assert is_map(result.powers), "powers should be a map"

      assert "regulation-7" in result.powers["articles"],
             "powers articles should contain 'regulation-7'"

      power_entry =
        Enum.find(result.powers["entries"], fn entry ->
          Map.get(entry, "holder") == "Gvt: Minister"
        end)

      assert power_entry != nil, "Should find minister power entry"

      assert Map.get(power_entry, "article") == "regulation-7",
             "Power entry should have article 'regulation-7'"
    end

    test "JSONB fields merge articles from multiple sections for same holder" do
      # When the same holder appears in multiple sections, their articles should be merged
      # JSONB structure: %{"articles" => [...], "entries" => [...], "holders" => [...]}

      text = """
      The employer shall ensure health and safety.
      The employer shall provide training.
      The employer shall maintain equipment.
      """

      p1_sections = [
        {"regulation-4", "The employer shall ensure health and safety."},
        {"regulation-5", "The employer shall provide training."},
        {"regulation-6", "The employer shall maintain equipment."}
      ]

      result =
        TaxaParser.classify_text_chunked(text, "test", p1_sections, law_name: "uksi/2024/merge")

      assert is_map(result.duties), "duties should be a map"

      # Top-level articles should contain all sections where employer appears
      articles = Map.get(result.duties, "articles", [])
      assert is_list(articles)

      # Should contain articles from all three sections
      assert "regulation-4" in articles, "Should have regulation-4"
      assert "regulation-5" in articles, "Should have regulation-5"
      assert "regulation-6" in articles, "Should have regulation-6"

      # Entries should have individual article fields
      entries = Map.get(result.duties, "entries", [])
      assert length(entries) == 3, "Should have 3 duty entries"

      # Each entry should have the correct article
      entry_articles = Enum.map(entries, &Map.get(&1, "article"))
      assert "regulation-4" in entry_articles
      assert "regulation-5" in entry_articles
      assert "regulation-6" in entry_articles
    end
  end
end
