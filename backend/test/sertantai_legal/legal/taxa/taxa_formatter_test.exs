defmodule SertantaiLegal.Legal.Taxa.TaxaFormatterTest do
  @moduledoc """
  TDD tests for Phase 2b: TaxaFormatter with structured match data.

  These tests define the expected behavior after refactoring TaxaFormatter
  to convert structured match data directly to JSONB, instead of parsing
  emoji-formatted text strings.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.TaxaFormatter

  describe "matches_to_jsonb/1 - Phase 2b new function" do
    test "converts structured matches to JSONB format" do
      matches = [
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "shall ensure safety"},
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "must provide equipment"}
      ]

      result = TaxaFormatter.matches_to_jsonb(matches)

      assert is_map(result)
      assert Map.has_key?(result, "entries")
      assert Map.has_key?(result, "holders")
      assert Map.has_key?(result, "articles")
    end

    test "entry structure matches JSONB schema" do
      matches = [
        %{holder: "Ind: Person", duty_type: "DUTY", clause: "shall do something"}
      ]

      result = TaxaFormatter.matches_to_jsonb(matches)

      [entry | _] = result["entries"]

      # Verify entry fields
      assert Map.has_key?(entry, "holder")
      assert Map.has_key?(entry, "duty_type")
      assert Map.has_key?(entry, "clause")
      assert Map.has_key?(entry, "article")

      # Verify values
      assert entry["holder"] == "Ind: Person"
      assert entry["duty_type"] == "DUTY"
      assert entry["clause"] == "shall do something"
    end

    test "extracts unique holders list" do
      matches = [
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "first"},
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "second"},
        %{holder: "Ind: Employee", duty_type: "DUTY", clause: "third"}
      ]

      result = TaxaFormatter.matches_to_jsonb(matches)

      assert is_list(result["holders"])
      assert "Org: Employer" in result["holders"]
      assert "Ind: Employee" in result["holders"]
      # Should be deduplicated
      assert length(result["holders"]) == 2
    end

    test "returns nil for empty matches" do
      assert TaxaFormatter.matches_to_jsonb([]) == nil
      assert TaxaFormatter.matches_to_jsonb(nil) == nil
    end

    test "handles matches with nil clauses" do
      matches = [
        %{holder: "Org: Employer", duty_type: "DUTY", clause: nil}
      ]

      result = TaxaFormatter.matches_to_jsonb(matches)

      [entry | _] = result["entries"]
      assert entry["clause"] == nil
    end

    test "articles field is empty list when no article in matches" do
      # Phase 2b matches don't have article info (that comes from TaxaParser context)
      matches = [
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "shall ensure"}
      ]

      result = TaxaFormatter.matches_to_jsonb(matches)

      # Articles should be empty or nil since match doesn't have article context
      assert result["articles"] == [] or result["articles"] == nil
    end
  end

  describe "matches_to_jsonb/2 with article context - Phase 2b" do
    test "adds article to entries when provided" do
      matches = [
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "shall ensure safety"}
      ]

      result = TaxaFormatter.matches_to_jsonb(matches, article: "regulation/4")

      [entry | _] = result["entries"]
      assert entry["article"] == "regulation/4"
    end

    test "extracts unique articles list" do
      # When article context provided, it should appear in articles list
      matches = [
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "first"}
      ]

      result = TaxaFormatter.matches_to_jsonb(matches, article: "regulation/4")

      assert "regulation/4" in result["articles"]
    end
  end

  describe "legacy text_to_jsonb/2 still works (Phase 2a compatibility)" do
    test "parses legacy text format" do
      text = """
      [Ind: Person]
      https://legislation.gov.uk/uksi/2005/621/regulation/4
      DUTY
      👤Ind: Person
      📌shall ensure safety
      """

      result = TaxaFormatter.text_to_jsonb(text, "DUTY")

      assert is_map(result)
      assert Map.has_key?(result, "entries")
      assert length(result["entries"]) > 0
    end

    test "returns nil for empty text" do
      assert TaxaFormatter.text_to_jsonb(nil, "DUTY") == nil
      assert TaxaFormatter.text_to_jsonb("", "DUTY") == nil
    end
  end

  describe "convenience wrappers with matches - Phase 2b" do
    test "duties_from_matches/1 converts duty matches" do
      matches = [
        %{holder: "Org: Employer", duty_type: "DUTY", clause: "shall ensure"}
      ]

      result = TaxaFormatter.duties_from_matches(matches)

      assert is_map(result)
      [entry | _] = result["entries"]
      assert entry["duty_type"] == "DUTY"
    end

    test "rights_from_matches/1 converts right matches" do
      matches = [
        %{holder: "Ind: Employee", duty_type: "RIGHT", clause: "may request"}
      ]

      result = TaxaFormatter.rights_from_matches(matches)

      assert is_map(result)
      [entry | _] = result["entries"]
      assert entry["duty_type"] == "RIGHT"
    end

    test "responsibilities_from_matches/1 converts responsibility matches" do
      matches = [
        %{
          holder: "Gvt: Authority: Local",
          duty_type: "RESPONSIBILITY",
          clause: "must investigate"
        }
      ]

      result = TaxaFormatter.responsibilities_from_matches(matches)

      assert is_map(result)
      [entry | _] = result["entries"]
      assert entry["duty_type"] == "RESPONSIBILITY"
    end

    test "powers_from_matches/1 converts power matches" do
      matches = [
        %{holder: "Gvt: Minister", duty_type: "POWER", clause: "may prescribe"}
      ]

      result = TaxaFormatter.powers_from_matches(matches)

      assert is_map(result)
      [entry | _] = result["entries"]
      assert entry["duty_type"] == "POWER"
    end
  end
end
