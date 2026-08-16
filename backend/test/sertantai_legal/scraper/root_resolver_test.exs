defmodule SertantaiLegal.Scraper.RootResolverTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.RootResolver

  # ── Pronoun reference resolution ─────────────────────────────
  # "that Act/Regulations/Order" references need sibling context.
  # e.g. article-22A-6 of Fire Safety Order:
  #   "accountable person" → "section 72 of the Building Safety Act 2022"
  #   "higher-risk building" → "section 65 of that Act"  ← pronoun
  # The resolver should inherit "Building Safety Act 2022" from the sibling.

  describe "resolve_pronoun_ref/3" do
    test "resolves 'that Act' from sibling citation in same section" do
      definition = "given by section 65 of that Act"

      sibling_index = %{
        {"UK_uksi_2005_1541", "article-22A-6"} => "Building Safety Act 2022 section 72"
      }

      assert RootResolver.resolve_pronoun_ref(
               definition,
               "UK_uksi_2005_1541",
               "article-22A-6",
               sibling_index
             ) == "Building Safety Act 2022 section 65"
    end

    test "resolves 'that Regulations' from sibling" do
      definition = "has the meaning given by regulation 3 of those Regulations"

      sibling_index = %{
        {"UK_uksi_2020_1265", "regulation-2-1"} =>
          "Greenhouse Gas Emissions Trading Scheme Regulations 2012 regulation 5"
      }

      assert RootResolver.resolve_pronoun_ref(
               definition,
               "UK_uksi_2020_1265",
               "regulation-2-1",
               sibling_index
             ) == "Greenhouse Gas Emissions Trading Scheme Regulations 2012 regulation 3"
    end

    test "resolves 'that Order' from sibling" do
      definition = "given by article 2 of that Order"

      sibling_index = %{
        {"UK_nisr_1995_2994", "regulation-2"} =>
          "Road Traffic (Northern Ireland) Order 1981 article 5"
      }

      assert RootResolver.resolve_pronoun_ref(
               definition,
               "UK_nisr_1995_2994",
               "regulation-2",
               sibling_index
             ) == "Road Traffic (Northern Ireland) Order 1981 article 2"
    end

    test "returns nil when no sibling citation exists" do
      definition = "given by section 65 of that Act"

      sibling_index = %{}

      assert RootResolver.resolve_pronoun_ref(
               definition,
               "UK_uksi_2005_1541",
               "article-22A-6",
               sibling_index
             ) == nil
    end

    test "returns nil when definition has no pronoun reference" do
      definition = "given by regulation 4"

      sibling_index = %{
        {"UK_uksi_2017_692", "regulation-3-1"} => "Some Act 2020 section 1"
      }

      assert RootResolver.resolve_pronoun_ref(
               definition,
               "UK_uksi_2017_692",
               "regulation-3-1",
               sibling_index
             ) == nil
    end

    test "returns nil when section_id is nil" do
      definition = "given by section 65 of that Act"

      sibling_index = %{
        {"UK_uksi_2005_1541", "article-22A-6"} => "Building Safety Act 2022 section 72"
      }

      assert RootResolver.resolve_pronoun_ref(
               definition,
               "UK_uksi_2005_1541",
               nil,
               sibling_index
             ) == nil
    end

    test "extracts section ref from definition, not from sibling" do
      # Sibling says "section 72", but our def says "section 115"
      # Result should use OUR section ref with the sibling's law name
      definition = "given by section 115 of that Act"

      sibling_index = %{
        {"UK_uksi_2005_1541", "article-22A-6"} => "Building Safety Act 2022 section 72"
      }

      assert RootResolver.resolve_pronoun_ref(
               definition,
               "UK_uksi_2005_1541",
               "article-22A-6",
               sibling_index
             ) == "Building Safety Act 2022 section 115"
    end
  end

  # ── EU directive name extraction ─────────────────────────────
  # EU directive citations like "Directive 2008/98/EC" need to be
  # converted to law_name format "UK_eudr_2008_98" for lookup.

  describe "extract_eu_law_name/1" do
    test "extracts law_name from 'Directive YYYY/NN/EC' format" do
      citation = "Directive 2008/98/EC of the European Parliament and of the Council on waste"
      assert RootResolver.extract_eu_law_name(citation) == "UK_eudr_2008_98"
    end

    test "extracts law_name from 'Directive (EU) YYYY/NNN' format" do
      citation = "Directive (EU) 2018/851"
      assert RootResolver.extract_eu_law_name(citation) == "UK_eudr_2018_851"
    end

    test "extracts law_name from 'Council Directive NN/NNN/EEC' format" do
      citation = "Council Directive 92/43/EEC on the conservation of natural habitats"
      assert RootResolver.extract_eu_law_name(citation) == "UK_eudr_1992_43"
    end

    test "extracts law_name from 'Regulation (EC) No NNN/YYYY' format" do
      citation = "Regulation (EC) No 178/2002 of the European Parliament"
      assert RootResolver.extract_eu_law_name(citation) == "UK_eur_2002_178"
    end

    test "returns nil for non-EU citations" do
      assert RootResolver.extract_eu_law_name("Housing Act 2004 section 261") == nil
    end

    test "returns nil for nil input" do
      assert RootResolver.extract_eu_law_name(nil) == nil
    end
  end
end
