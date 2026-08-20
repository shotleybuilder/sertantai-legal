defmodule SertantaiLegal.Scraper.RootResolver.MatcherTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.RootResolver.{Matcher, Resolution}

  # ── Hand-built indexes for testing ──────────────────────────
  # These simulate what Indexes module would build from the DB.

  @title_index %{
    {"scotland act", 1998} => "UK_ukpga_1998_46",
    "scotland act" => "UK_ukpga_1998_46",
    {"building safety act", 2022} => "UK_ukpga_2022_30",
    "building safety act" => "UK_ukpga_2022_30",
    {"housing act", 2004} => "UK_ukpga_2004_34",
    "housing act" => "UK_ukpga_2004_34",
    {"environmental permitting england and wales regulations", 2016} => "UK_uksi_2016_1154",
    "environmental permitting england and wales regulations" => "UK_uksi_2016_1154"
  }

  @def_index %{
    {"UK_ukpga_1998_46", "Scotland"} => ["def-scotland-1"],
    {"UK_ukpga_2022_30", "higher-risk building"} => ["def-hrb-1", "def-hrb-2"],
    {"UK_ukpga_2004_34", "local housing authority"} => ["def-lha-1"],
    {"UK_uksi_2005_1541", "accountable person"} => ["def-ap-self", "def-ap-other"]
  }

  @citation_index %{
    {"UK_uksi_2020_1265", "2016 regulations"} =>
      "Environmental Permitting (England and Wales) Regulations 2016"
  }

  @sibling_index %{
    {"UK_uksi_2005_1541", "article-22A-6"} => "Building Safety Act 2022 section 72"
  }

  # ── resolve_one/5 ───────────────────────────────────────────
  # Main dispatch: pronoun → internal → citation → unresolved.

  describe "resolve_one/5" do
    test "resolves named law citation to root definitions" do
      def_row = %{
        id: "child-1",
        law_name: "UK_uksi_2005_1541",
        term: "Scotland",
        definition: "has the meaning given by section 126(1) of the Scotland Act 1998",
        section_id: "regulation-2-1"
      }

      assert {:resolved, %Resolution{} = res} =
               Matcher.resolve_one(
                 def_row,
                 @title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index
               )

      assert res.id == "child-1"
      assert res.citation =~ "Scotland Act 1998"
      assert res.root_ids == ["def-scotland-1"]
    end

    test "resolves pronoun reference via sibling index" do
      def_row = %{
        id: "child-2",
        law_name: "UK_uksi_2005_1541",
        term: "higher-risk building",
        definition: "given by section 65 of that Act",
        section_id: "article-22A-6"
      }

      assert {:resolved, %Resolution{} = res} =
               Matcher.resolve_one(
                 def_row,
                 @title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index
               )

      assert res.id == "child-2"
      assert res.citation =~ "Building Safety Act 2022"
      assert res.citation =~ "section 65"
      assert res.root_ids == ["def-hrb-1", "def-hrb-2"]
    end

    test "handles internal reference (same-law, different section)" do
      def_row = %{
        id: "def-ap-self",
        law_name: "UK_uksi_2005_1541",
        term: "accountable person",
        definition: "given by regulation 3 above",
        section_id: "regulation-5-1"
      }

      assert {:internal, %Resolution{} = res} =
               Matcher.resolve_one(
                 def_row,
                 @title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index
               )

      assert res.id == "def-ap-self"
      # Should find the other definition (not self)
      assert res.root_ids == ["def-ap-other"]
    end

    test "internal ref with no other definitions in same law" do
      def_row = %{
        id: "lonely-1",
        law_name: "UK_uksi_2099_1",
        term: "widget",
        definition: "given by regulation 5 above",
        section_id: "regulation-2-1"
      }

      assert {:internal, %Resolution{id: "lonely-1", root_ids: []}} =
               Matcher.resolve_one(
                 def_row,
                 @title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index
               )
    end

    test "citation_only when law found but term not in its definitions" do
      def_row = %{
        id: "child-3",
        law_name: "UK_uksi_2020_1265",
        term: "missing term",
        definition: "has the meaning given by section 5 of the Housing Act 2004",
        section_id: "regulation-2-1"
      }

      assert {:citation_only, %Resolution{} = res} =
               Matcher.resolve_one(
                 def_row,
                 @title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index
               )

      assert res.id == "child-3"
      assert res.citation =~ "Housing Act 2004"
      assert res.target_law == "UK_ukpga_2004_34"
      assert res.root_ids == []
    end

    test "unresolved when citation cannot be extracted at all" do
      def_row = %{
        id: "child-4",
        law_name: "UK_uksi_2020_1265",
        term: "mystery",
        definition: "means something we cannot figure out",
        section_id: "regulation-2-1"
      }

      assert {:unresolved, %Resolution{} = res} =
               Matcher.resolve_one(
                 def_row,
                 @title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index
               )

      assert res.id == "child-4"
      assert res.term == "mystery"
      assert res.law_name == "UK_uksi_2020_1265"
    end

    test "citation_only when law not found in title index" do
      def_row = %{
        id: "child-5",
        law_name: "UK_uksi_2020_1265",
        term: "obscure term",
        definition: "has the meaning given by the Obscure Act 1847",
        section_id: "regulation-2-1"
      }

      assert {:citation_only, %Resolution{} = res} =
               Matcher.resolve_one(
                 def_row,
                 @title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index
               )

      assert res.id == "child-5"
      assert res.citation =~ "Obscure Act 1847"
      assert res.target_law == nil
      assert res.root_ids == []
    end
  end

  @enacted_by_index %{
    "UK_ssi_2009_140" => "Electricity Act 1989",
    "UK_uksi_2017_1012" => "Town and Country Planning Act 1990"
  }

  # ── resolve_bare_act_ref/3 ─────────────────────────────────
  # Resolves bare "the Act" in SIs via enacted_by parent.

  describe "resolve_bare_act_ref/3" do
    test "resolves 'of the Act' when enacted_by parent exists" do
      assert Matcher.resolve_bare_act_ref(
               "given by section 32(4) of the Act",
               "UK_ssi_2009_140",
               @enacted_by_index
             ) == "Electricity Act 1989 section 32(4)"
    end

    test "resolves 'under the Act' without section" do
      assert Matcher.resolve_bare_act_ref(
               "as provided under the Act",
               "UK_ssi_2009_140",
               @enacted_by_index
             ) == "Electricity Act 1989"
    end

    test "returns nil when no enacted_by parent" do
      assert Matcher.resolve_bare_act_ref(
               "given by section 5 of the Act",
               "UK_uksi_2020_unknown",
               @enacted_by_index
             ) == nil
    end

    test "returns nil when definition has no bare Act pattern" do
      assert Matcher.resolve_bare_act_ref(
               "given by regulation 4",
               "UK_ssi_2009_140",
               @enacted_by_index
             ) == nil
    end
  end

  # ── resolve_one with enacted_by ────────────────────────────

  describe "resolve_one/6 with enacted_by_index" do
    test "bare 'the Act' resolves via enacted_by parent" do
      title_index =
        Map.merge(@title_index, %{
          {"electricity act", 1989} => "UK_ukpga_1989_29",
          "electricity act" => "UK_ukpga_1989_29"
        })

      def_row = %{
        id: "bare-act-1",
        law_name: "UK_ssi_2009_140",
        term: "renewables obligation",
        definition: "is to be construed in accordance with section 32(4) of the Act",
        section_id: "regulation-2-1"
      }

      assert {:citation_only, %Resolution{citation: citation}} =
               Matcher.resolve_one(
                 def_row,
                 title_index,
                 @citation_index,
                 @def_index,
                 @sibling_index,
                 @enacted_by_index
               )

      assert citation =~ "Electricity Act 1989"
      assert citation =~ "section 32(4)"
    end
  end

  # ── resolve_to_root/4 ───────────────────────────────────────
  # Given a citation string, find the root law and its definitions.

  describe "resolve_to_root/4" do
    test "resolves citation to root definition IDs" do
      assert {:ok, ["def-scotland-1"], "UK_ukpga_1998_46"} =
               Matcher.resolve_to_root(
                 "Scotland Act 1998 section 126(1)",
                 "Scotland",
                 @title_index,
                 @def_index
               )
    end

    test "returns :law_found when law exists but term doesn't" do
      assert {:law_found, "UK_ukpga_1998_46"} =
               Matcher.resolve_to_root(
                 "Scotland Act 1998 section 1",
                 "nonexistent term",
                 @title_index,
                 @def_index
               )
    end

    test "returns :not_found when law not in title index" do
      assert :not_found =
               Matcher.resolve_to_root(
                 "Imaginary Act 2099",
                 "some term",
                 @title_index,
                 @def_index
               )
    end

    test "resolves EU directive via extract_eu_law_name fallback" do
      eu_def_index =
        Map.put(@def_index, {"UK_eudr_2008_98", "waste"}, ["def-eu-waste-1"])

      assert {:ok, ["def-eu-waste-1"], "UK_eudr_2008_98"} =
               Matcher.resolve_to_root(
                 "Directive 2008/98/EC",
                 "waste",
                 @title_index,
                 eu_def_index
               )
    end
  end

  # ── resolve_pronoun_ref/4 (moved from root_resolver_test) ───
  # Existing tests re-homed to the new module.

  describe "resolve_pronoun_ref/5" do
    test "resolves 'that Act' from sibling citation in same section" do
      assert Matcher.resolve_pronoun_ref(
               "given by section 65 of that Act",
               "UK_uksi_2005_1541",
               "article-22A-6",
               @sibling_index
             ) == "Building Safety Act 2022 section 65"
    end

    test "returns nil when no sibling citation exists and no enacted_by" do
      assert Matcher.resolve_pronoun_ref(
               "given by section 65 of that Act",
               "UK_uksi_2005_1541",
               "article-22A-6",
               %{},
               %{}
             ) == nil
    end

    test "falls back to enacted_by when sibling_index miss" do
      assert Matcher.resolve_pronoun_ref(
               "given by section 32(4) of that Act",
               "UK_ssi_2009_140",
               "regulation-2-1",
               %{},
               @enacted_by_index
             ) == "Electricity Act 1989 section 32(4)"
    end

    test "falls back to enacted_by for 'those Regulations' pronoun" do
      enacted_by = %{"UK_uksi_2020_100" => "Environmental Permitting Regulations 2016"}

      assert Matcher.resolve_pronoun_ref(
               "as defined in regulation 3 of those Regulations",
               "UK_uksi_2020_100",
               "regulation-5-1",
               %{},
               enacted_by
             ) == "Environmental Permitting Regulations 2016 regulation 3"
    end

    test "sibling_index takes priority over enacted_by fallback" do
      assert Matcher.resolve_pronoun_ref(
               "given by section 65 of that Act",
               "UK_uksi_2005_1541",
               "article-22A-6",
               @sibling_index,
               @enacted_by_index
             ) == "Building Safety Act 2022 section 65"
    end

    test "returns nil when section_id is nil" do
      assert Matcher.resolve_pronoun_ref(
               "given by section 65 of that Act",
               "UK_uksi_2005_1541",
               nil,
               @sibling_index
             ) == nil
    end

    test "returns nil when definition has no pronoun reference" do
      assert Matcher.resolve_pronoun_ref(
               "given by regulation 4",
               "UK_uksi_2005_1541",
               "article-22A-6",
               @sibling_index
             ) == nil
    end
  end
end
