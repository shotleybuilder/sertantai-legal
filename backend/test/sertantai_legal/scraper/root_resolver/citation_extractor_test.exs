defmodule SertantaiLegal.Scraper.RootResolver.CitationExtractorTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.RootResolver.CitationExtractor

  # ── extract_named_law/1 ─────────────────────────────────────
  # Extracts "Title Year" from definition text containing
  # "Act|Regulations|Order YYYY" patterns.

  describe "extract_named_law/1" do
    test "extracts full Act title with year" do
      definition = "has the meaning given by section 126(1) of the Scotland Act 1998"
      assert {:ok, "Scotland Act 1998", "1998"} = CitationExtractor.extract_named_law(definition)
    end

    test "extracts Regulations title with year" do
      definition =
        "has the meaning given in regulation 2(1) of the Environmental Permitting (England and Wales) Regulations 2016"

      assert {:ok, title, "2016"} = CitationExtractor.extract_named_law(definition)
      assert title =~ "Regulations 2016"
    end

    test "extracts Order title with year" do
      definition =
        "has the meaning given by article 2 of the Road Traffic (Northern Ireland) Order 1981"

      assert {:ok, title, "1981"} = CitationExtractor.extract_named_law(definition)
      assert title =~ "Order 1981"
    end

    test "strips preamble before law title" do
      definition =
        "has the meaning given in section 7 of the Acquisition of Land Act 1981"

      assert {:ok, "Acquisition of Land Act 1981", "1981"} =
               CitationExtractor.extract_named_law(definition)
    end

    test "returns :no_match for definition without law reference" do
      assert :no_match = CitationExtractor.extract_named_law("means a device used for measuring")
    end

    test "returns :no_match for empty string" do
      assert :no_match = CitationExtractor.extract_named_law("")
    end
  end

  # ── extract_section/1 ────────────────────────────────────────
  # Extracts "section 126(1)", "regulation 3", "article 2(1)" etc.

  describe "extract_section/1" do
    test "extracts section with subsection" do
      assert CitationExtractor.extract_section("given by section 126(1) of the Scotland Act 1998") ==
               "section 126(1)"
    end

    test "extracts regulation without subsection" do
      assert CitationExtractor.extract_section("given by regulation 3 of those Regulations") ==
               "regulation 3"
    end

    test "extracts article with subsection" do
      assert CitationExtractor.extract_section("given by article 2(1) of that Order") ==
               "article 2(1)"
    end

    test "extracts paragraph" do
      assert CitationExtractor.extract_section("given in paragraph 5 of that Schedule") ==
               "paragraph 5"
    end

    test "returns nil when no section reference" do
      assert CitationExtractor.extract_section("means a device") == nil
    end
  end

  # ── internal_ref?/1 ──────────────────────────────────────────
  # Detects same-law references like "given by regulation 3"
  # (no external law name).

  describe "internal_ref?/1" do
    test "true for 'given by section N' without law name" do
      assert CitationExtractor.internal_ref?("given by section 3 above")
    end

    test "true for 'specified in regulation N' without law name" do
      assert CitationExtractor.internal_ref?("specified in regulation 2(1)")
    end

    test "true for 'set out in paragraph N'" do
      assert CitationExtractor.internal_ref?("set out in paragraph 1 of Schedule 2")
    end

    test "true for 'defined in subsection (2)'" do
      assert CitationExtractor.internal_ref?(
               "defined in accordance with subsection 2 of this section"
             )
    end

    test "false when text contains a named Act" do
      refute CitationExtractor.internal_ref?("given by section 126 of the Scotland Act 1998")
    end

    test "false when text contains short name 'the 1998 Act'" do
      refute CitationExtractor.internal_ref?("given by section 126 of the 1998 Act")
    end

    test "false when text contains Directive reference" do
      refute CitationExtractor.internal_ref?("given in Directive 2008/98/EC")
    end

    test "false for plain definition without reference pattern" do
      refute CitationExtractor.internal_ref?("means a building used for habitation")
    end
  end

  # ── normalise_title/1 ────────────────────────────────────────
  # Downcases, strips punctuation, normalises whitespace.

  describe "normalise_title/1" do
    test "downcases and strips punctuation" do
      assert CitationExtractor.normalise_title("Scotland Act") == "scotland act"
    end

    test "normalises whitespace" do
      assert CitationExtractor.normalise_title("  Scotland   Act  ") == "scotland act"
    end

    test "strips commas and parentheses" do
      assert CitationExtractor.normalise_title(
               "Environmental Permitting (England and Wales) Regulations"
             ) ==
               "environmental permitting england and wales regulations"
    end
  end

  # ── extract_citation/3 ──────────────────────────────────────
  # Full pipeline: named law → short name → abbreviation → nil.

  describe "extract_citation/3" do
    test "extracts named law citation with section" do
      definition = "has the meaning given by section 126(1) of the Scotland Act 1998"
      result = CitationExtractor.extract_citation(definition, "UK_uksi_2005_1541", %{})
      assert result =~ "Scotland Act 1998"
      assert result =~ "section 126(1)"
    end

    test "extracts short name via citation index" do
      definition = "has the meaning given by regulation 3 of the 2016 Regulations"

      citation_index = %{
        {"UK_uksi_2020_1265", "2016 regulations"} =>
          "Environmental Permitting (England and Wales) Regulations 2016"
      }

      result =
        CitationExtractor.extract_citation(definition, "UK_uksi_2020_1265", citation_index)

      assert result =~ "Environmental Permitting"
      assert result =~ "regulation 3"
    end

    test "falls back to 'the YYYY Type' when citation index has no match" do
      definition = "has the meaning given in the 2003 Regulations"
      result = CitationExtractor.extract_citation(definition, "UK_uksi_2020_1265", %{})
      assert result =~ "the 2003 Regulations"
    end

    test "extracts abbreviation citation via citation index" do
      definition = "has the same meaning as in the Waste Directive"

      citation_index = %{
        {"UK_uksi_2011_988", "waste directive"} => "Directive 2008/98/EC"
      }

      result = CitationExtractor.extract_citation(definition, "UK_uksi_2011_988", citation_index)
      assert result == "Directive 2008/98/EC"
    end

    test "returns nil when nothing matches" do
      definition = "means a building used for habitation"
      assert CitationExtractor.extract_citation(definition, "UK_uksi_2020_1265", %{}) == nil
    end
  end

  # ── extract_eu_law_name/1 ───────────────────────────────────
  # Already tested in root_resolver_test.exs, but moving here for completeness.

  describe "extract_eu_law_name/1" do
    test "Directive YYYY/NN/EC" do
      assert CitationExtractor.extract_eu_law_name("Directive 2008/98/EC") == "UK_eudr_2008_98"
    end

    test "Directive (EU) YYYY/NNN" do
      assert CitationExtractor.extract_eu_law_name("Directive (EU) 2018/851") ==
               "UK_eudr_2018_851"
    end

    test "Council Directive NN/NNN/EEC (2-digit year)" do
      assert CitationExtractor.extract_eu_law_name("Council Directive 92/43/EEC") ==
               "UK_eudr_1992_43"
    end

    test "Regulation (EC) No NNN/YYYY" do
      assert CitationExtractor.extract_eu_law_name("Regulation (EC) No 178/2002") ==
               "UK_eur_2002_178"
    end

    test "nil for non-EU" do
      assert CitationExtractor.extract_eu_law_name("Housing Act 2004") == nil
    end

    test "nil for nil input" do
      assert CitationExtractor.extract_eu_law_name(nil) == nil
    end
  end
end
