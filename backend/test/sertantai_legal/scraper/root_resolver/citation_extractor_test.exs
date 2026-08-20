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

    test "true for plural 'paragraphs (2) to (4)'" do
      assert CitationExtractor.internal_ref?("has the meaning given in paragraphs (2) to (4)")
    end

    test "true for plural 'subsections (3) and (4)'" do
      assert CitationExtractor.internal_ref?("has the meaning given in subsections (3) and (4)")
    end

    test "true for plural 'regulations 3 and 4'" do
      assert CitationExtractor.internal_ref?("specified in regulations 3 and 4")
    end

    test "false for plain definition without reference pattern" do
      refute CitationExtractor.internal_ref?("means a building used for habitation")
    end
  end

  # ── international_convention?/1 ──────────────────────────────

  describe "international_convention?/1" do
    test "true for SOLAS reference" do
      assert CitationExtractor.international_convention?(
               "as defined in regulation 8.1 of Chapter VII in the Annex to SOLAS"
             )
    end

    test "true for Chicago Convention" do
      assert CitationExtractor.international_convention?(
               "have the meanings given in Chapter 1 of Annex 6 to the Chicago Convention"
             )
    end

    test "true for Convention on/for pattern" do
      assert CitationExtractor.international_convention?(
               "given by Article 2 of the Convention on the Law Applicable to Trusts"
             )
    end

    test "false when Convention is in a UK Act title" do
      refute CitationExtractor.international_convention?(
               "given by section 1 of the Safety Convention Act 2005"
             )
    end

    test "false for plain definition" do
      refute CitationExtractor.international_convention?("means a building used for habitation")
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

    test "strips leading 'the'" do
      assert CitationExtractor.normalise_title("the New Roads and Street Works Act") ==
               "new roads and street works act"
    end

    test "strips leading 'the' case-insensitively" do
      assert CitationExtractor.normalise_title("The Planning Act") == "planning act"
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

  # ── extract_eu_regulation_citation/1 ─────────────────────────
  # EU Regulation short-form: "Regulation 853/2004", "Regulation (EC) No 178/2002"

  describe "extract_eu_regulation_citation/1" do
    test "extracts bare Regulation NNN/YYYY" do
      definition = "as defined in Regulation 853/2004"
      assert {:ok, citation} = CitationExtractor.extract_eu_regulation_citation(definition)
      assert citation =~ "Regulation 853/2004"
    end

    test "extracts Regulation (EU) YYYY/NNN" do
      definition = "within the meaning of Article 3(49) of Regulation (EU) 2017/625"
      assert {:ok, citation} = CitationExtractor.extract_eu_regulation_citation(definition)
      assert citation =~ "Regulation (EU) 2017/625"
    end

    test "extracts Regulation (EC) No NNN/YYYY" do
      definition = "as defined in Regulation (EC) No 178/2002"
      assert {:ok, citation} = CitationExtractor.extract_eu_regulation_citation(definition)
      assert citation =~ "Regulation (EC) No 178/2002"
    end

    test "extracts from Annex context" do
      definition = "as set out in Annex I to Regulation 853/2004"
      assert {:ok, citation} = CitationExtractor.extract_eu_regulation_citation(definition)
      assert citation =~ "Regulation 853/2004"
    end

    test "returns :no_match for UK law" do
      definition = "as defined in the Housing Act 2004"
      assert :no_match = CitationExtractor.extract_eu_regulation_citation(definition)
    end

    test "returns :no_match for plain definition" do
      definition = "means a building used for habitation"
      assert :no_match = CitationExtractor.extract_eu_regulation_citation(definition)
    end
  end

  # ── extract_citation/3 with EU regulation ───────────────────

  describe "extract_citation/3 with EU regulation short-form" do
    test "extracts EU regulation when no named UK law present" do
      definition = "has the meaning given in Regulation 853/2004"
      result = CitationExtractor.extract_citation(definition, "UK_uksi_2006_14", %{})
      assert result =~ "Regulation 853/2004"
    end

    test "named UK law takes priority over EU regulation" do
      definition =
        "has the meaning given in the Food Safety Act 1990 (see also Regulation 853/2004)"

      result = CitationExtractor.extract_citation(definition, "UK_uksi_2006_14", %{})
      assert result =~ "Food Safety Act 1990"
    end

    test "does not falsely match Regulation YYYY/NNN as named law" do
      # "Regulation 2017/625" should NOT be matched as "Regulation 2017"
      definition = "within the meaning of Regulation 2017/625"
      result = CitationExtractor.extract_citation(definition, "UK_uksi_2006_14", %{})
      assert result =~ "Regulation 2017/625"
      refute result =~ "Regulation 2017 "
    end
  end

  # ── extract_initials_citation/1 ──────────────────────────────
  # Resolves statute abbreviations like "TCPA 1990" via curated static map.

  describe "extract_initials_citation/1" do
    test "resolves TCPA 1990" do
      definition = "has the meaning given by section 336(1) of the TCPA 1990"

      assert CitationExtractor.extract_initials_citation(definition) ==
               "Town and Country Planning Act 1990 section 336(1)"
    end

    test "resolves EA 1989 without 'the' prefix" do
      definition = "as defined in EA 1989"
      assert CitationExtractor.extract_initials_citation(definition) == "Electricity Act 1989"
    end

    test "resolves CRA 2015" do
      definition = "within the meaning of section 2 of CRA 2015"

      assert CitationExtractor.extract_initials_citation(definition) ==
               "Consumer Rights Act 2015 section 2"
    end

    test "resolves MCAA 2009" do
      definition = "has the meaning given by MCAA 2009"

      assert CitationExtractor.extract_initials_citation(definition) ==
               "Marine and Coastal Access Act 2009"
    end

    test "returns nil for unknown abbreviation" do
      definition = "as defined in XYZ 2020"
      assert CitationExtractor.extract_initials_citation(definition) == nil
    end

    test "resolves FRS 2004 to Fire and Rescue Services Act" do
      definition = "within the meaning of FRS 2004"

      assert CitationExtractor.extract_initials_citation(definition) ==
               "Fire and Rescue Services Act 2004"
    end

    test "returns nil for text without abbreviation pattern" do
      definition = "means a building used for residential purposes"
      assert CitationExtractor.extract_initials_citation(definition) == nil
    end

    test "does not match single uppercase letter + year" do
      # "A 2020" should not match (minimum 2 uppercase letters)
      definition = "see paragraph A 2020"
      assert CitationExtractor.extract_initials_citation(definition) == nil
    end
  end

  # ── extract_citation/3 chain with initials ───────────────────

  describe "extract_citation/3 with statute abbreviations" do
    test "initials citation is extracted when named law and short name fail" do
      definition = "has the meaning given in section 57 of the TCPA 1990"

      assert CitationExtractor.extract_citation(definition, "UK_uksi_2020_1234", %{}) ==
               "Town and Country Planning Act 1990 section 57"
    end

    test "named law takes priority over initials" do
      # Contains both a full title and initials — full title wins
      definition =
        "has the meaning given in the Town and Country Planning Act 1990 (see TCPA 1990)"

      result = CitationExtractor.extract_citation(definition, "UK_uksi_2020_1234", %{})
      assert result =~ "Town and Country Planning Act 1990"
    end

    test "abbreviation in named law title is expanded — FRS Act 2004" do
      # "FRS Act 2004" is caught by extract_named_law, but must be expanded
      # so that downstream title_index lookup finds "Fire and Rescue Services Act 2004"
      definition = "within the meaning of section 21 of the FRS Act 2004"

      result = CitationExtractor.extract_citation(definition, "UK_uksi_2017_469", %{})
      assert result == "Fire and Rescue Services Act 2004 section 21"
    end
  end

  # ── extract_year_prefix_citation/1 ─────────────────────────
  # Year-prefix SI abbreviations: "the 2014 Acetylene Regulations"

  describe "extract_year_prefix_citation/1" do
    test "extracts year-prefix Regulations" do
      definition = "has the meaning given in the 2014 Acetylene Regulations"
      assert {:ok, citation} = CitationExtractor.extract_year_prefix_citation(definition)
      assert citation == "Acetylene Regulations 2014"
    end

    test "extracts year-prefix with section reference" do
      definition =
        "has the meaning given in regulation 2(1) of the 1996 Safety Case Regulations"

      assert {:ok, citation} = CitationExtractor.extract_year_prefix_citation(definition)
      assert citation =~ "Safety Case Regulations 1996"
      assert citation =~ "regulation 2(1)"
    end

    test "extracts year-prefix Order" do
      definition = "has the meaning given in the 1995 Offshore Installations Order"
      assert {:ok, citation} = CitationExtractor.extract_year_prefix_citation(definition)
      assert citation == "Offshore Installations Order 1995"
    end

    test "returns :no_match for standard title-year format" do
      definition = "has the meaning given in the Scotland Act 1998"
      assert :no_match = CitationExtractor.extract_year_prefix_citation(definition)
    end

    test "returns :no_match for text without year-prefix pattern" do
      definition = "means a building used for residential purposes"
      assert :no_match = CitationExtractor.extract_year_prefix_citation(definition)
    end
  end
end
