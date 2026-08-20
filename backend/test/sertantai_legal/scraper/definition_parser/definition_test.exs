defmodule SertantaiLegal.Scraper.DefinitionParser.DefinitionTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.DefinitionParser.Definition

  # ── normalise_term ─────────────────────────────────────────

  describe "normalise_term/1" do
    test "downcases and strips leading articles" do
      assert Definition.normalise_term("The Environment") == "environment"
      assert Definition.normalise_term("An Inspector") == "inspector"
      assert Definition.normalise_term("A Building") == "building"
    end

    test "strips quotes" do
      assert Definition.normalise_term(~s("employee")) == "employee"
      assert Definition.normalise_term("\u201Cemployee\u201D") == "employee"
    end

    test "normalises hyphens to spaces" do
      assert Definition.normalise_term("dual-purpose vehicle") == "dual purpose vehicle"
    end

    test "collapses multiple spaces after hyphen removal" do
      assert Definition.normalise_term("well-being") == "well being"
    end

    test "strips ellipsis" do
      assert Definition.normalise_term("employee...") == "employee"
      assert Definition.normalise_term("employee\u2026") == "employee"
    end

    test "returns empty string for nil" do
      assert Definition.normalise_term(nil) == ""
    end
  end

  # ── clean_definition ───────────────────────────────────────

  describe "clean_definition/1" do
    test "strips leading parenthesis" do
      assert Definition.clean_definition(") has the meaning") == "has the meaning"
    end

    test "strips trailing punctuation" do
      assert Definition.clean_definition("means a building;") == "means a building"
      assert Definition.clean_definition("means a building,") == "means a building"
      assert Definition.clean_definition("means a building.") == "means a building"
    end

    test "strips stray semicolons before years" do
      assert Definition.clean_definition("the Regulations ;2015") == "the Regulations 2015"
    end

    test "preserves semicolons not before years" do
      assert Definition.clean_definition("part A; part B") == "part A; part B"
    end

    test "strips trailing amendment markers" do
      assert Definition.clean_definition("means a building F123") == "means a building"
    end

    test "returns nil for nil" do
      assert Definition.clean_definition(nil) == nil
    end
  end

  # ── references_other_law? ──────────────────────────────────

  describe "references_other_law?/1" do
    test "detects 'has the meaning given in'" do
      assert Definition.references_other_law?(
               "has the meaning given in section 126(1) of the Scotland Act 1998"
             )
    end

    test "detects 'as defined in'" do
      assert Definition.references_other_law?("as defined by the Housing Act 2004")
    end

    test "returns false for substantive definitions" do
      refute Definition.references_other_law?("means a building used for residential purposes")
    end

    test "returns false for nil" do
      refute Definition.references_other_law?(nil)
    end
  end

  # ── citation? ──────────────────────────────────────────────

  describe "citation?/1" do
    test "detects year + type pattern" do
      assert Definition.citation?("1974 act")
      assert Definition.citation?("2016 regulations")
    end

    test "detects principal/amending pattern" do
      assert Definition.citation?("principal act")
      assert Definition.citation?("amending regulations")
    end

    test "returns false for normal terms" do
      refute Definition.citation?("employee")
      refute Definition.citation?("building")
    end
  end

  # ── citation detection via definition text ────────────────────
  # "the Act" means the Food Safety Act 1990 — term is "act",
  # definition IS a law name. Should be flagged as citation.

  describe "new/1 citation detection from definition text" do
    test "flags citation when definition IS a law name" do
      d =
        Definition.new(
          law_name: "UK_uksi_2013_2996",
          term: "act",
          definition: "the Food Safety Act 1990",
          source: :definition_list
        )

      assert d.citation == true
    end

    test "flags citation for Welsh law name definition" do
      d =
        Definition.new(
          law_name: "UK_wsi_2014_2303",
          term: "y ddeddf",
          definition: "means the Food Safety Act 1990",
          source: :definition_list
        )

      assert d.citation == true
    end

    test "does not flag citation for cross-reference definition" do
      d =
        Definition.new(
          law_name: "UK_uksi_2013_2196",
          term: "food authority",
          definition:
            "given by section 5 of the Act except that it does not include the Inner Temple",
          source: :definition_list
        )

      refute d.citation
    end

    test "does not flag citation for substantive definition" do
      d =
        Definition.new(
          law_name: "UK_uksi_2014_3001",
          term: "meat",
          definition:
            "the skeletal muscles of mammalian and bird species recognised as fit for human consumption",
          source: :definition_list
        )

      refute d.citation
    end
  end
end
