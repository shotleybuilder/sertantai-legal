defmodule SertantaiLegal.Scraper.DefinitionParserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.DefinitionParser

  @fixtures_path Path.join([__DIR__, "..", "..", "fixtures", "legislation_gov_uk"])

  defp read_fixture(name) do
    @fixtures_path |> Path.join(name) |> File.read!()
  end

  # ── Workplace (Health, Safety and Welfare) Regulations 1992 ────
  # Legacy XML pattern: no <Term> elements, curly-quoted terms in plain text
  # 7 definitions in regulation 2(1), all law-scoped

  describe "parse/2 with Workplace Regs (legacy XML, no <Term> elements)" do
    setup do
      xml = read_fixture("body_uksi_1992_3004.xml")
      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_1992_3004", type_code: "uksi"})
      %{defs: defs}
    end

    test "extracts all 7 definitions", %{defs: defs} do
      assert length(defs) == 7
    end

    test "all definitions have correct law_name", %{defs: defs} do
      assert Enum.all?(defs, &(&1.law_name == "UK_uksi_1992_3004"))
    end

    test "all definitions have section_id regulation-2-1", %{defs: defs} do
      assert Enum.all?(defs, &(&1.section_id == "regulation-2-1"))
    end

    test "all definitions have law scope", %{defs: defs} do
      assert Enum.all?(defs, &(&1.scope == :law))
    end

    test "extracts 'workplace' term correctly", %{defs: defs} do
      workplace = Enum.find(defs, &(&1.term == "workplace"))
      assert workplace != nil
      assert String.contains?(workplace.definition, "premises or part of premises")
    end

    test "extracts 'mine' term with cross-reference", %{defs: defs} do
      mine = Enum.find(defs, &(&1.term == "mine"))
      assert mine != nil
      assert String.contains?(mine.definition, "Mines and Quarries Act 1954")
      assert mine.references_other_law == true
    end

    test "extracts 'traffic route' as standalone definition", %{defs: defs} do
      route = Enum.find(defs, &(&1.term == "traffic route"))
      assert route != nil
      assert String.contains?(route.definition, "pedestrian traffic")
      assert route.references_other_law == false
    end

    test "strips leading articles from terms", %{defs: defs} do
      terms = Enum.map(defs, & &1.term)
      # No term should start with "the " or "a "
      assert Enum.all?(terms, fn t -> not String.starts_with?(t, "the ") end)
    end

    test "all definitions have non-empty definition text", %{defs: defs} do
      assert Enum.all?(defs, fn d -> d.definition != nil and d.definition != "" end)
    end
  end

  # ── RIDDOR 2013 ────────────────────────────────────────────────
  # Modern XML pattern: <Term> elements with id attributes
  # 52 definitions across 2 Definition lists (reg 2 and reg 11)

  describe "parse/2 with RIDDOR (modern XML, <Term> elements)" do
    setup do
      xml = read_fixture("body_uksi_2013_1471.xml")
      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2013_1471", type_code: "uksi"})
      %{defs: defs}
    end

    test "extracts 55 definitions from 2 Definition lists (including paired terms)", %{defs: defs} do
      assert length(defs) == 55
    end

    test "definitions come from two different sections", %{defs: defs} do
      section_ids = defs |> Enum.map(& &1.section_id) |> Enum.uniq() |> Enum.sort()
      assert length(section_ids) == 2
      assert "regulation-2-1" in section_ids
    end

    test "extracts '1954 act' as cross-reference", %{defs: defs} do
      act = Enum.find(defs, &(&1.term == "1954 act"))
      assert act != nil
      assert String.contains?(act.definition, "Mines and Quarries Act 1954")
      assert act.references_other_law == true
    end

    test "extracts 'accident' as standalone definition", %{defs: defs} do
      accident = Enum.find(defs, &(&1.term == "accident"))
      assert accident != nil
      assert String.contains?(accident.definition, "non-consensual physical violence")
      assert accident.references_other_law == false
    end

    test "extracts 'working day' with full definition", %{defs: defs} do
      wd = Enum.find(defs, &(&1.term == "working day"))
      assert wd != nil
      assert String.contains?(wd.definition, "Saturday")
      assert String.contains?(wd.definition, "bank holiday")
    end

    test "detects multiple cross-references", %{defs: defs} do
      refs = Enum.filter(defs, & &1.references_other_law)
      # At least 15 definitions reference other Acts/Regulations
      assert length(refs) >= 15
    end

    test "extracts paired terms from double-quoted definitions", %{defs: defs} do
      # "diving contractor" and "diving project" share one definition
      dc = Enum.find(defs, &(&1.term == "diving contractor"))
      dp = Enum.find(defs, &(&1.term == "diving project"))
      assert dc != nil, "Expected 'diving contractor' from paired term"
      assert dp != nil, "Expected 'diving project' from paired term"
      assert dc.definition == dp.definition
    end

    test "extracts both terms from 'pipeline' and 'pipeline works'", %{defs: defs} do
      p = Enum.find(defs, &(&1.term == "pipeline"))
      pw = Enum.find(defs, &(&1.term == "pipeline works"))
      assert p != nil
      assert pw != nil
      assert p.definition == pw.definition
    end

    test "all definitions have correct law_name", %{defs: defs} do
      assert Enum.all?(defs, &(&1.law_name == "UK_uksi_2013_1471"))
    end
  end

  # ── Edge cases ─────────────────────────────────────────────────

  describe "parse/2 edge cases" do
    test "returns empty list for XML with no Definition lists" do
      xml = read_fixture("body_uksi_2016_680.xml")
      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2016_680", type_code: "uksi"})
      assert defs == []
    end

    test "normalises terms to lowercase" do
      xml = read_fixture("body_uksi_2013_1471.xml")
      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2013_1471", type_code: "uksi"})

      for d <- defs do
        assert d.term == String.downcase(d.term),
               "Term '#{d.term}' should be lowercase"
      end
    end

    test "strips trailing punctuation from definitions" do
      xml = read_fixture("body_uksi_1992_3004.xml")
      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_1992_3004", type_code: "uksi"})

      for d <- defs do
        refute String.ends_with?(d.definition, ";"),
               "Definition for '#{d.term}' should not end with semicolon"
      end
    end
  end
end
