defmodule SertantaiLegal.Scraper.RootResolver.DiagnosticTest do
  # Not async: summarise/1 calls lookup_family which hits the DB
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Scraper.RootResolver.Diagnostic
  alias SertantaiLegal.Scraper.RootResolver.Diagnostic.Finding

  # ── Hand-built indexes ─────────────────────────────────────
  # Simulate what Indexes/DB would build. All classify tests use
  # these directly — no DB needed.

  @title_index %{
    {"health and safety at work etc act", 1974} => "UK_ukpga_1974_37",
    "health and safety at work etc act" => "UK_ukpga_1974_37",
    {"fire precautions act", 1971} => "UK_ukpga_1971_40",
    "fire precautions act" => "UK_ukpga_1971_40",
    {"roads northern ireland order", 1993} => "UK_nisi_1993_3160",
    "roads northern ireland order" => "UK_nisi_1993_3160",
    {"building safety act", 2022} => "UK_ukpga_2022_30",
    "building safety act" => "UK_ukpga_2022_30",
    {"scotland act", 1998} => "UK_ukpga_1998_46",
    "scotland act" => "UK_ukpga_1998_46"
  }

  # Abbreviation index: {law_name, abbreviation} => full citation
  @citation_index %{
    {"UK_uksi_2020_100", "1974 act"} => "Health and Safety at Work etc. Act 1974"
  }

  @enacted_by_index %{
    "UK_uksi_2020_100" => ["ukpga/1974/37"]
  }

  # Laws that have definitions_parsed_at set
  @parse_status %{
    "UK_ukpga_1974_37" => true,
    "UK_ukpga_1971_40" => true,
    "UK_nisi_1993_3160" => true,
    "UK_ukpga_2022_30" => true,
    "UK_ukpga_1998_46" => true
  }

  # Live status for each law
  @live_status %{
    "UK_ukpga_1974_37" => "✔ In force",
    "UK_ukpga_1971_40" => "❌ Revoked / Repealed / Abolished",
    "UK_nisi_1993_3160" => "⭕ Part Revocation / Repeal",
    "UK_ukpga_2022_30" => "✔ In force",
    "UK_ukpga_1998_46" => "✔ In force"
  }

  # Terms available in each parent law
  @parent_terms %{
    "UK_ukpga_1974_37" => MapSet.new(["employee", "employer", "premises", "work"]),
    "UK_nisi_1993_3160" => MapSet.new(["road", "street", "highway"]),
    "UK_ukpga_2022_30" => MapSet.new(["higher-risk building", "accountable person"]),
    "UK_ukpga_1998_46" => MapSet.new(["scotland", "scottish ministers"])
  }

  defp classify(d) do
    Diagnostic.test_classify(
      d,
      @title_index,
      @citation_index,
      @enacted_by_index,
      @parse_status,
      @live_status,
      @parent_terms
    )
  end

  # ── classify: no_citation ──────────────────────────────────

  describe "classify — no_citation" do
    test "returns :no_citation when definition has no extractable citation" do
      d = %{
        id: "def-1",
        law_name: "UK_uksi_2020_100",
        term: "widget",
        definition: "a device used for testing purposes",
        referenced_law_citation: nil
      }

      finding = classify(d)

      assert %Finding{category: :no_citation} = finding
      assert finding.definition_id == "def-1"
      assert finding.term == "widget"
      assert finding.citation == nil
    end

    test "returns :no_citation when definition is nil" do
      d = %{
        id: "def-2",
        law_name: "UK_uksi_2020_100",
        term: "widget",
        definition: nil,
        referenced_law_citation: nil
      }

      assert %Finding{category: :no_citation} = classify(d)
    end

    test "returns :no_citation when definition is empty" do
      d = %{
        id: "def-3",
        law_name: "UK_uksi_2020_100",
        term: "widget",
        definition: "",
        referenced_law_citation: nil
      }

      assert %Finding{category: :no_citation} = classify(d)
    end
  end

  # ── classify: international_convention ──────────────────────

  describe "classify — international_convention" do
    test "returns :international_convention for SOLAS reference" do
      d = %{
        id: "def-conv-1",
        law_name: "UK_uksi_2014_1616",
        term: "ibc code",
        definition:
          "the International Bulk Chemical Code as defined in regulation 8.1 of Chapter VII in the Annex to SOLAS",
        referenced_law_citation: nil
      }

      assert %Finding{category: :international_convention} = classify(d)
    end

    test "returns :international_convention for Chicago Convention reference" do
      d = %{
        id: "def-conv-2",
        law_name: "UK_uksi_2016_765",
        term: "commercial air transport operation",
        definition: "have the meanings given in Chapter 1 of Annex 6 to the Chicago Convention",
        referenced_law_citation: nil
      }

      assert %Finding{category: :international_convention} = classify(d)
    end

    test "does not classify 'Convention Act' as international convention" do
      d = %{
        id: "def-conv-3",
        law_name: "UK_uksi_2020_100",
        term: "widget",
        definition: "has the meaning given by section 1 of the Safety Convention Act 2005",
        referenced_law_citation: nil
      }

      # This has "Convention" but also "Act YYYY" — should be parent_not_in_lrt
      finding = classify(d)
      refute finding.category == :international_convention
    end
  end

  # ── classify: parent_not_in_lrt ────────────────────────────

  describe "classify — parent_not_in_lrt" do
    test "returns :parent_not_in_lrt when cited law is not in title_index" do
      d = %{
        id: "def-4",
        law_name: "UK_uksi_2020_100",
        term: "coal-mining purpose",
        definition: "has the meaning given by section 44(1) of the Coal Act 1938",
        referenced_law_citation: nil
      }

      finding = classify(d)

      assert %Finding{category: :parent_not_in_lrt} = finding
      assert finding.citation =~ "Coal Act 1938"
    end
  end

  # ── classify: parent_revoked ───────────────────────────────

  describe "classify — parent_revoked" do
    test "returns :parent_revoked when parent law is fully revoked" do
      d = %{
        id: "def-5",
        law_name: "UK_uksi_2020_100",
        term: "fire certificate",
        definition: "has the meaning given by section 1 of the Fire Precautions Act 1971",
        referenced_law_citation: nil
      }

      finding = classify(d)

      assert %Finding{category: :parent_revoked} = finding
      assert finding.target_law == "UK_ukpga_1971_40"
      assert finding.detail =~ "revoked"
    end

    test "parent_revoked takes priority over parent_unparsed" do
      # Use a revoked parent that is NOT in parse_status
      parse_status_without_fire = Map.delete(@parse_status, "UK_ukpga_1971_40")

      d = %{
        id: "def-6",
        law_name: "UK_uksi_2020_100",
        term: "fire certificate",
        definition: "has the meaning given by section 1 of the Fire Precautions Act 1971",
        referenced_law_citation: nil
      }

      finding =
        Diagnostic.test_classify(
          d,
          @title_index,
          @citation_index,
          @enacted_by_index,
          parse_status_without_fire,
          @live_status,
          @parent_terms
        )

      # Should be parent_revoked, NOT parent_unparsed
      assert %Finding{category: :parent_revoked} = finding
    end

    test "parent_revoked takes priority over term_not_found" do
      # Fire Precautions Act is revoked AND parsed but has no terms in @parent_terms
      # (no entry for UK_ukpga_1971_40 in @parent_terms)
      d = %{
        id: "def-7",
        law_name: "UK_uksi_2020_100",
        term: "some term",
        definition: "has the meaning given by the Fire Precautions Act 1971",
        referenced_law_citation: nil
      }

      assert %Finding{category: :parent_revoked} = classify(d)
    end
  end

  # ── classify: parent_unparsed ──────────────────────────────

  describe "classify — parent_unparsed" do
    test "returns :parent_unparsed when parent is in LRT, not revoked, but not parsed" do
      # Add a law to title_index that is NOT in parse_status and NOT revoked
      title_index =
        Map.merge(@title_index, %{
          {"consumer safety act", 1978} => "UK_ukpga_1978_38",
          "consumer safety act" => "UK_ukpga_1978_38"
        })

      live_status = Map.put(@live_status, "UK_ukpga_1978_38", "✔ In force")

      d = %{
        id: "def-8",
        law_name: "UK_uksi_2020_100",
        term: "article for use at work",
        definition: "has the meaning given by the Consumer Safety Act 1978",
        referenced_law_citation: nil
      }

      finding =
        Diagnostic.test_classify(
          d,
          title_index,
          @citation_index,
          @enacted_by_index,
          @parse_status,
          live_status,
          @parent_terms
        )

      assert %Finding{category: :parent_unparsed} = finding
      assert finding.target_law == "UK_ukpga_1978_38"
    end

    test "partly revoked parent that is unparsed remains :parent_unparsed" do
      # Roads NI Order 1993 is partly revoked — remove from parse_status
      parse_status = Map.delete(@parse_status, "UK_nisi_1993_3160")

      d = %{
        id: "def-9",
        law_name: "UK_uksi_2020_100",
        term: "road",
        definition: "has the meaning given by the Roads (Northern Ireland) Order 1993",
        referenced_law_citation: nil
      }

      finding =
        Diagnostic.test_classify(
          d,
          @title_index,
          @citation_index,
          @enacted_by_index,
          parse_status,
          @live_status,
          @parent_terms
        )

      # Partly revoked but not fully — should still be parent_unparsed (actionable)
      assert %Finding{category: :parent_unparsed} = finding
    end
  end

  # ── classify: term_not_found ───────────────────────────────

  describe "classify — term_not_found" do
    test "returns :term_not_found when parent is parsed but term absent" do
      d = %{
        id: "def-10",
        law_name: "UK_uksi_2020_100",
        term: "inspector",
        definition:
          "has the meaning given by section 19 of the Health and Safety at Work etc. Act 1974",
        referenced_law_citation: nil
      }

      finding = classify(d)

      assert %Finding{category: :term_not_found} = finding
      assert finding.target_law == "UK_ukpga_1974_37"
      assert finding.detail =~ "4 definitions"
    end
  end

  # ── classify: term_normalisation ───────────────────────────

  describe "classify — term_normalisation" do
    test "returns :term_normalisation when fuzzy match finds similar term" do
      d = %{
        id: "def-11",
        law_name: "UK_uksi_2020_100",
        term: "higher risk building",
        definition: "has the meaning given by the Building Safety Act 2022",
        referenced_law_citation: nil
      }

      finding = classify(d)

      assert %Finding{category: :term_normalisation} = finding
      assert finding.nearest_term == "higher-risk building"
      assert finding.detail =~ "higher risk building"
      assert finding.detail =~ "higher-risk building"
    end
  end

  # ── classify: citation_ambiguous ───────────────────────────

  describe "classify — citation_ambiguous" do
    test "returns :citation_ambiguous when term exists in parent but unlinked" do
      d = %{
        id: "def-12",
        law_name: "UK_uksi_2020_100",
        term: "employee",
        definition: "has the meaning given by the Health and Safety at Work etc. Act 1974",
        referenced_law_citation: nil
      }

      finding = classify(d)

      assert %Finding{category: :citation_ambiguous} = finding
      assert finding.target_law == "UK_ukpga_1974_37"
      assert finding.detail =~ "multi-law ambiguity"
    end
  end

  # ── classify: referenced_law_citation ──────────────────────

  describe "classify — referenced_law_citation precedence" do
    test "uses referenced_law_citation when present instead of extracting" do
      d = %{
        id: "def-13",
        law_name: "UK_uksi_2020_100",
        term: "scotland",
        definition: "some definition text with no citation at all",
        referenced_law_citation: "Scotland Act 1998 section 126(1)"
      }

      finding = classify(d)

      # Should resolve via the cached citation, not extract from text
      assert finding.target_law == "UK_ukpga_1998_46"
      assert finding.citation =~ "Scotland Act 1998"
    end

    test "strips leading 'means' from referenced_law_citation" do
      d = %{
        id: "def-14",
        law_name: "UK_uksi_2020_100",
        term: "scotland",
        definition: "no citation here",
        referenced_law_citation: "means Scotland Act 1998"
      }

      finding = classify(d)
      assert finding.target_law == "UK_ukpga_1998_46"
    end
  end

  # ── resolve_law_name ───────────────────────────────────────

  describe "resolve_law_name" do
    test "resolves by {title, year} tuple" do
      assert Diagnostic.test_resolve_law_name("Scotland Act 1998 section 126", @title_index) ==
               "UK_ukpga_1998_46"
    end

    test "resolves by full normalised title" do
      assert Diagnostic.test_resolve_law_name("Scotland Act 1998", @title_index) ==
               "UK_ukpga_1998_46"
    end

    test "resolves by title without year" do
      assert Diagnostic.test_resolve_law_name("Scotland Act", @title_index) ==
               "UK_ukpga_1998_46"
    end

    test "strips section/regulation references before resolving" do
      assert Diagnostic.test_resolve_law_name(
               "Health and Safety at Work etc. Act 1974 section 53",
               @title_index
             ) == "UK_ukpga_1974_37"
    end

    test "returns nil for unknown law" do
      assert Diagnostic.test_resolve_law_name("Imaginary Act 2099", @title_index) == nil
    end
  end

  # ── find_nearest_term ──────────────────────────────────────

  describe "find_nearest_term" do
    test "finds term with high word overlap" do
      terms = MapSet.new(["higher-risk building", "accountable person", "building control"])

      assert Diagnostic.test_find_nearest_term("higher risk building", terms) ==
               "higher-risk building"
    end

    test "returns nil for single-word terms (too ambiguous)" do
      terms = MapSet.new(["employee", "employer", "premises"])
      assert Diagnostic.test_find_nearest_term("person", terms) == nil
    end

    test "returns nil when no close match exists" do
      terms = MapSet.new(["employee", "employer", "premises"])
      assert Diagnostic.test_find_nearest_term("building control officer", terms) == nil
    end

    test "finds subset match (child words all in parent)" do
      terms = MapSet.new(["local housing authority", "housing association"])

      assert Diagnostic.test_find_nearest_term("housing authority", terms) ==
               "local housing authority"
    end
  end

  # ── summarise ──────────────────────────────────────────────

  describe "summarise" do
    setup do
      findings = [
        %Finding{
          definition_id: "d1",
          law_name: "UK_uksi_2020_100",
          term: "term1",
          category: :term_not_found,
          target_law: "UK_ukpga_1974_37"
        },
        %Finding{
          definition_id: "d2",
          law_name: "UK_uksi_2020_100",
          term: "term2",
          category: :term_not_found,
          target_law: "UK_ukpga_1974_37"
        },
        %Finding{
          definition_id: "d3",
          law_name: "UK_uksi_2020_100",
          term: "term3",
          category: :no_citation
        },
        %Finding{
          definition_id: "d4",
          law_name: "UK_uksi_2020_100",
          term: "term4",
          category: :parent_revoked,
          target_law: "UK_ukpga_1971_40"
        },
        %Finding{
          definition_id: "d5",
          law_name: "UK_uksi_2020_100",
          term: "term5",
          category: :parent_not_in_lrt,
          target_law: nil
        }
      ]

      %{findings: findings}
    end

    test "counts total findings", %{findings: findings} do
      summary = Diagnostic.summarise(findings)
      assert summary.total == 5
    end

    test "splits citation-resolved vs genuinely unresolved", %{findings: findings} do
      summary = Diagnostic.summarise(findings)
      # d1, d2 (term_not_found) and d4 (parent_revoked) have target_law set via citation
      # d3 (no_citation) and d5 (parent_not_in_lrt with nil target) have no citation
      assert summary.citation_resolved + summary.genuinely_unresolved == summary.total
    end

    test "groups by category", %{findings: findings} do
      summary = Diagnostic.summarise(findings)

      assert summary.by_category[:term_not_found] == 2
      assert summary.by_category[:no_citation] == 1
      assert summary.by_category[:parent_revoked] == 1
      assert summary.by_category[:parent_not_in_lrt] == 1
    end

    test "top_parents excludes ceiling categories", %{findings: findings} do
      summary = Diagnostic.summarise(findings)

      parent_laws = Enum.map(summary.top_parents, &elem(&1, 0))

      # UK_ukpga_1974_37 (term_not_found) should be included
      assert "UK_ukpga_1974_37" in parent_laws

      # UK_ukpga_1971_40 (parent_revoked) should be excluded
      refute "UK_ukpga_1971_40" in parent_laws
    end
  end

  # ── print_summary ──────────────────────────────────────────

  describe "print_summary" do
    test "separates actionable from ceiling categories" do
      summary = %{
        total: 10,
        citation_resolved: 7,
        genuinely_unresolved: 3,
        by_category: %{
          term_not_found: 4,
          no_citation: 3,
          parent_revoked: 2,
          parent_not_in_lrt: 1
        },
        by_family: %{},
        top_parents: [{"UK_ukpga_1974_37", 4}]
      }

      output = ExUnit.CaptureIO.capture_io(fn -> Diagnostic.print_summary(summary) end)

      assert output =~ "10 (7 actionable, 3 ceiling)"
      assert output =~ "Citation-resolved: 7"
      assert output =~ "Genuinely unresolved: 3"
      assert output =~ "Actionable:"
      assert output =~ "term_not_found"
      assert output =~ "no_citation"
      assert output =~ "Ceiling (not actionable):"
      assert output =~ "parent_revoked"
      assert output =~ "parent_not_in_lrt"
    end

    test "omits ceiling section when no ceiling findings" do
      summary = %{
        total: 5,
        citation_resolved: 3,
        genuinely_unresolved: 2,
        by_category: %{term_not_found: 3, no_citation: 2},
        by_family: %{},
        top_parents: []
      }

      output = ExUnit.CaptureIO.capture_io(fn -> Diagnostic.print_summary(summary) end)

      assert output =~ "5 (5 actionable, 0 ceiling)"
      refute output =~ "Ceiling"
    end
  end

  # ── ceiling_categories ─────────────────────────────────────

  describe "ceiling_categories" do
    test "includes parent_revoked and parent_not_in_lrt" do
      cats = Diagnostic.ceiling_categories()
      assert :parent_revoked in cats
      assert :parent_not_in_lrt in cats
    end

    test "does not include actionable categories" do
      cats = Diagnostic.ceiling_categories()
      refute :term_not_found in cats
      refute :no_citation in cats
      refute :parent_unparsed in cats
      refute :term_normalisation in cats
      refute :citation_ambiguous in cats
    end
  end
end
