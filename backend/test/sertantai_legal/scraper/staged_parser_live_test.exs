defmodule SertantaiLegal.Scraper.StagedParserLiveTest do
  @moduledoc """
  Live integration tests that hit legislation.gov.uk.

  These tests verify the full parsing pipeline against real laws.
  Tagged with :live to exclude from routine test runs.

  Run with: mix test --only live
  """
  use ExUnit.Case, async: false

  alias SertantaiLegal.Scraper.StagedParser
  alias SertantaiLegal.Scraper.TaxaParser

  @moduletag :live

  # Disable test mode to hit real legislation.gov.uk
  setup do
    original_value = Application.get_env(:sertantai_legal, :test_mode, false)
    Application.put_env(:sertantai_legal, :test_mode, false)

    on_exit(fn ->
      Application.put_env(:sertantai_legal, :test_mode, original_value)
    end)

    :ok
  end

  describe "TaxaParser.run/3 - live" do
    @tag :live
    test "UK_uksi_1991_899 returns role with Ind: Worker" do
      # This law is known to have "Ind: Worker" in the body text
      # DB has: role = ["Ind: Worker"]
      {:ok, result} = TaxaParser.run("uksi", "1991", "899")

      assert result.taxa_text_source == "body", "Should use body text, not introduction"
      assert result.taxa_text_length > 0, "Should have fetched text"
      assert is_list(result.role), "role should be a list"
      assert "Ind: Worker" in result.role, "Should detect 'Ind: Worker' in body text"
    end

    @tag :live
    test "UK_uksi_2016_680 returns role with Ind: Worker" do
      # Financial Services and Markets Act 2000 (Market Abuse) Regulations
      # DB has: role includes "Ind: Worker"
      {:ok, result} = TaxaParser.run("uksi", "2016", "680")

      assert result.taxa_text_source == "body"
      assert result.taxa_text_length > 100_000, "Body should be ~105KB"
      assert "Ind: Worker" in result.role
    end

    @tag :live
    test "uses body text as primary source, not introduction" do
      # Test a law where introduction exists but body has more actors
      {:ok, result} = TaxaParser.run("uksi", "2016", "680")

      # Body text is much larger than introduction
      assert result.taxa_text_source == "body"
      assert result.taxa_text_length > 50_000

      # Should find multiple actors from body
      assert length(result.role) > 3, "Should find multiple actors from body text"
    end
  end

  describe "StagedParser.parse/1 - live" do
    @tag :live
    test "UK_uksi_1991_899 full parse returns role with Ind: Worker" do
      record = %{type_code: "uksi", Year: 1991, Number: "899", name: "UK_uksi_1991_899"}

      {:ok, result} = StagedParser.parse(record)

      # Taxa stage should succeed
      assert result.stages[:taxa].status == :ok, "Taxa stage should succeed"

      # Final record should have role populated
      assert is_list(result.record[:role]), "role should be a list"
      assert "Ind: Worker" in result.record[:role], "Should have 'Ind: Worker' in final record"

      # role_gvt should also be populated
      assert result.record[:role_gvt] != nil, "role_gvt should be populated"
    end

    @tag :live
    test "amendments 404 does not crash taxa stage" do
      # Use a law that may return 404 for amendments but should still run taxa
      record = %{type_code: "uksi", Year: 1991, Number: "899", name: "UK_uksi_1991_899"}

      {:ok, result} = StagedParser.parse(record)

      # All stages should complete (not crash)
      assert Map.has_key?(result.stages, :extent)
      assert Map.has_key?(result.stages, :enacted_by)
      assert Map.has_key?(result.stages, :amendments)
      assert Map.has_key?(result.stages, :repeal_revoke)
      assert Map.has_key?(result.stages, :taxa)

      # Taxa should run regardless of amendment errors
      assert result.stages[:taxa].status == :ok
    end

    @tag :live
    test "full parse populates all taxa fields" do
      record = %{type_code: "uksi", Year: 2016, Number: "680", name: "UK_uksi_2016_680"}

      {:ok, result} = StagedParser.parse(record)

      # Check taxa stage
      assert result.stages[:taxa].status == :ok

      # Check all taxa fields are populated in the ParsedLaw struct
      # Note: We check result.law (the struct) not result.record (comparison map)
      # because empty lists are valid results and are filtered from comparison map
      assert is_list(result.law.role)
      assert is_list(result.law.role_gvt)
      assert is_list(result.law.duty_type)
      assert is_list(result.law.duty_holder)
      assert is_list(result.law.rights_holder)
      assert is_list(result.law.responsibility_holder)
      assert is_list(result.law.power_holder)
      assert is_list(result.law.popimar)

      # Role should have multiple entries for this complex law
      assert length(result.law.role) >= 5
    end
  end

  describe "regression tests" do
    @tag :live
    test "role field is not empty when body text contains actors" do
      # This is the specific bug we're fixing:
      # The diff view showed role: ["Ind: Worker"] (old) vs role: [] (new)
      # Because TaxaParser was using introduction instead of body

      # These laws have been verified to contain the expected actors in their body text
      # Note: Some DB records may have legacy data that doesn't match current parsing
      laws_with_known_roles = [
        {"uksi", "1991", "899", ["Ind: Worker"]},
        {"uksi", "2016", "680", ["Ind: Worker"]}
        # uksi/2005/324 removed - DB has "Ind: Worker" but body text doesn't contain "worker"
      ]

      for {type_code, year, number, expected_roles} <- laws_with_known_roles do
        {:ok, result} = TaxaParser.run(type_code, year, number)

        for expected_role <- expected_roles do
          assert expected_role in result.role,
                 "#{type_code}/#{year}/#{number} should have '#{expected_role}' in role, got: #{inspect(result.role)}"
        end
      end
    end

    @tag :live
    test "enacted_by names use UK_type_year_number format" do
      # This SI is enacted by the Planning Act 2008 (ukpga/2008/29)
      # enacted_by names should be in UK_ format for DB consistency
      record = %{type_code: "uksi", Year: 2025, Number: "622", name: "UK_uksi_2025_622"}

      {:ok, result} = StagedParser.parse(record)

      assert result.stages[:enacted_by].status == :ok

      enacted_by = result.record[:enacted_by]
      assert is_list(enacted_by), "enacted_by should be a list"
      assert length(enacted_by) > 0, "Should have at least one enacted_by"

      # All enacted_by entries should have UK_ format names
      for entry <- enacted_by do
        assert is_map(entry), "enacted_by entry should be a map"

        assert String.starts_with?(entry.name, "UK_"),
               "enacted_by name should start with UK_, got: #{entry.name}"
      end
    end
  end
end
