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

  # ── Inline definitions (fallback text scan) ────────────────────

  describe "parse/2 with inline definitions (no Class='Definition' list)" do
    test "extracts definitions from inline text in P2 elements" do
      # Minimal XML with an inline definition (no UnorderedList Class="Definition")
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these Regulations \u201ccoarse fish\u201d means fish of the following species.</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        SertantaiLegal.Scraper.DefinitionParser.parse(xml, %{
          law_name: "UK_nisr_2009_378",
          type_code: "nisr"
        })

      assert length(defs) == 1
      assert hd(defs).term == "coarse fish"
      assert hd(defs).scope == :law
      assert hd(defs).section_id == "regulation-2-1"
    end

    test "extracts multiple inline definitions from one P2" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-6">
            <Pnumber>6</Pnumber>
            <P1para>
              <P2 id="regulation-6-4">
                <Pnumber>4</Pnumber>
                <P2para>
                  <Text>In this regulation \u201cvehicle\u201d means a motor car; \u201cwagon\u201d means a goods vehicle.</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        SertantaiLegal.Scraper.DefinitionParser.parse(xml, %{
          law_name: "UK_test_2024_1",
          type_code: "uksi"
        })

      assert length(defs) == 2
      terms = Enum.map(defs, & &1.term) |> Enum.sort()
      assert terms == ["vehicle", "wagon"]
      assert Enum.all?(defs, &(&1.scope == :provision))
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

  # ── Abbreviation element handling ─────────────────────────────
  # legislation.gov.uk wraps abbreviated law titles in <Abbreviation> elements:
  #   \u201cthe <Abbreviation Expansion="...">2004 Act</Abbreviation>\u201d means ...
  # The parser must extract the full quoted term, not produce an empty term.

  describe "parse/2 with <Abbreviation> elements" do
    test "extracts term from curly-quoted text wrapping an Abbreviation element" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these Regulations\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201cthe <Abbreviation Expansion="Housing Act 2004 c. 34">2004 Act</Abbreviation>\u201d means the Housing Act 2004;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2007_1667", type_code: "uksi"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "2004 act"
      assert String.contains?(d.definition, "Housing Act 2004")
      assert d.references_other_law == true
    end

    test "extracts term when Abbreviation has long expansion attribute" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these Regulations\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201cthe <Abbreviation Expansion="Health and Safety at Work (Northern Ireland) Order 1978 (S.I. 1978/1039 (N.I. 9))">1978 Order</Abbreviation>\u201d means the Health and Safety at Work (Northern Ireland) Order 1978;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_nisr_1994_1", type_code: "nisr"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "1978 order"
      assert String.contains?(d.definition, "Health and Safety at Work")
    end

    test "handles mix of Abbreviation and plain definitions in same list" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these Regulations\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201cthe <Abbreviation Expansion="Housing Act 2004 c. 34">2004 Act</Abbreviation>\u201d means the Housing Act 2004;</Text>
                      </Para>
                    </ListItem>
                    <ListItem>
                      <Para>
                        <Text>\u201cresidential property\u201d means a building used wholly for residential purposes;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_test_abbrev_1", type_code: "uksi"})

      assert length(defs) == 2
      terms = Enum.map(defs, & &1.term) |> Enum.sort()
      assert terms == ["2004 act", "residential property"]
    end

    test "no definition has an empty or nil term" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In this Order\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201cthe <Abbreviation Expansion="Merchant Shipping Act 1995 c. 21">1995 Act</Abbreviation>\u201d means the Merchant Shipping Act 1995;</Text>
                      </Para>
                    </ListItem>
                    <ListItem>
                      <Para>
                        <Text>\u201cthe <Abbreviation Expansion="Corporation of Trinity House of Deptford Strond">Trinity House</Abbreviation>\u201d means the Corporation of Trinity House of Deptford Strond;</Text>
                      </Para>
                    </ListItem>
                    <ListItem>
                      <Para>
                        <Text>\u201cvessel\u201d means a ship or boat;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_1998_683", type_code: "uksi"})

      assert length(defs) == 3

      for d <- defs do
        assert d.term != nil, "term should not be nil for #{inspect(d.definition)}"
        assert d.term != "", "term should not be empty for #{inspect(d.definition)}"

        assert String.trim(d.term) != "",
               "term should not be whitespace for #{inspect(d.definition)}"
      end
    end

    test "handles EU regulation Abbreviation with number prefix" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these Regulations\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201c<Abbreviation Expansion="Council Directive 92/43/EEC on the conservation of natural habitats and of wild fauna and flora">the Habitats Directive</Abbreviation>\u201d means Council Directive 92/43/EEC on the conservation of natural habitats and of wild fauna and flora;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_nisr_2001_435", type_code: "nisr"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "habitats directive"
      assert String.contains?(d.definition, "Council Directive 92/43/EEC")
    end
  end

  # ── Curly quotes in <Term> text ───────────────────────────────
  # Some older XML has curly quotes inside the <Term> element:
  #   <Text>"<Term>"approved place"</Term>" means ...</Text>
  # The parser must strip quotes from the term.

  describe "parse/2 with curly quotes inside <Term> elements" do
    test "strips curly quotes from term text" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these regulations\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201c<Term id="term-approved-place">\u201capproved place\u201d</Term>\u201d means a place approved by the Secretary of State;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_1979_628", type_code: "uksi"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "approved place"
      refute String.contains?(d.term, "\u201c")
      refute String.contains?(d.term, "\u201d")
    end

    test "handles multiple <Term> elements in one ListItem (paired terms)" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these regulations\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201c<Term id="term-employer">\u201cemployer\u201d</Term>\u201d means, in relation to any person, the employer of that person and \u201c<Term id="term-employers">\u201cemployers\u201d</Term>\u201d shall be construed accordingly;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_1979_628", type_code: "uksi"})

      assert length(defs) == 2
      terms = Enum.map(defs, & &1.term) |> Enum.sort()
      assert terms == ["employer", "employers"]
    end
  end

  # ── Child elements inside <Term> ──────────────────────────────
  # Some <Term> elements contain child elements like <Acronym>:
  #   <Term><Acronym>CEN</Acronym>/TS 15359:2006</Term>
  # The parser must reconstruct the full term text in document order.

  describe "parse/2 with child elements inside <Term>" do
    test "reconstructs term from <Acronym> child element in correct order" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these Regulations\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201c<Term id="term-cents-15359"><Acronym>CEN</Acronym>/TS 15359:2006</Term>\u201d means the document identified by Standard Number DD CEN/TS 15359;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        DefinitionParser.parse(xml, %{law_name: "UK_ssi_2009_140", type_code: "ssi"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "cen/ts 15359:2006"
    end
  end

  # ── Delegated definitions ─────────────────────────────────────
  # Some definition lists delegate meaning to another law:
  #   "the following words have the meanings given by Article 2 of Regulation 996/2010—"
  #   <ListItem>"accident";</ListItem>
  #   <ListItem>"incident";</ListItem>
  # The parser must use the preamble text as the definition, not leave it empty.

  describe "parse/2 with delegated definitions" do
    test "uses preamble text as definition for delegated meaning lists" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-2">
                <Pnumber>2</Pnumber>
                <P2para>
                  <Text>In these Regulations the following words and expressions have the meanings given by Article 2 of Regulation 996/2010\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem><Para><Text>\u201caccident\u201d;</Text></Para></ListItem>
                    <ListItem><Para><Text>\u201cincident\u201d;</Text></Para></ListItem>
                    <ListItem><Para><Text>\u201cserious incident\u201d.</Text></Para></ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        DefinitionParser.parse(xml, %{law_name: "UK_uksi_2018_321", type_code: "uksi"})

      assert length(defs) == 3
      terms = Enum.map(defs, & &1.term) |> Enum.sort()
      assert terms == ["accident", "incident", "serious incident"]

      for d <- defs do
        assert d.definition != nil
        assert d.definition != ""
        assert String.contains?(d.definition, "Regulation 996/2010")
        assert d.references_other_law == true
      end
    end

    test "uses preamble for 'same meaning as in' delegated lists" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="regulation-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In this Order the following expressions have the same meaning as in the Factories Act 1961\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem><Para><Text>\u201cfactory\u201d;</Text></Para></ListItem>
                    <ListItem><Para><Text>\u201cworkplace\u201d.</Text></Para></ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        DefinitionParser.parse(xml, %{law_name: "UK_uksi_1981_569", type_code: "uksi"})

      assert length(defs) == 2

      for d <- defs do
        assert String.contains?(d.definition, "Factories Act 1961")
        assert d.references_other_law == true
      end
    end
  end
end
