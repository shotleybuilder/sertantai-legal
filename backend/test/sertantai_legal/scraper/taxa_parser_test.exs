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
end
