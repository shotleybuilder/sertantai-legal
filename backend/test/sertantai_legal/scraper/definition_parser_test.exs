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

    test "all definitions have source :definition_list", %{defs: defs} do
      assert Enum.all?(defs, &(&1.source == :definition_list))
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

    test "extracts 55+ definitions from Definition lists plus body section terms", %{defs: defs} do
      assert length(defs) >= 55
    end

    test "definitions come from multiple sections", %{defs: defs} do
      section_ids = defs |> Enum.map(& &1.section_id) |> Enum.uniq() |> Enum.sort()
      assert length(section_ids) >= 2
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

    test "definitions have correct source provenance", %{defs: defs} do
      sources = defs |> Enum.map(& &1.source) |> Enum.uniq() |> Enum.sort()
      assert :definition_list in sources
      assert Enum.all?(defs, &(&1.source in [:definition_list, :section_term]))
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
      assert hd(defs).source == :inline_text
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
      assert Enum.all?(defs, &(&1.source == :inline_text))
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

  # ── Section-level definitions (Term in P2 text, no Definition list) ───
  # Some Acts define terms in substantive sections, not Interpretation sections.
  # e.g. NRSWA 1991 s.49: "In this Part "the street authority" means..."
  # The <Term> element appears inside running <Text> in a P2, with no
  # UnorderedList Class="Definition" wrapper.

  describe "parse/2 with section-level definitions (Term in P2 text)" do
    test "extracts definition from Term element in running P2 text" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="section-49">
            <Pnumber>49</Pnumber>
            <P1para>
              <P2 id="section-49-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In this Part \u201c<Term id="term-the-street-authority">the street authority</Term>\u201d in relation to a street means, subject to the following provisions\u2014</Text>
                  <P3 id="section-49-1-a">
                    <Pnumber>a</Pnumber>
                    <P3para><Text>if the street is a maintainable highway, the highway authority, and</Text></P3para>
                  </P3>
                  <P3 id="section-49-1-b">
                    <Pnumber>b</Pnumber>
                    <P3para><Text>if the street is not a maintainable highway, the street managers.</Text></P3para>
                  </P3>
                </P2para>
              </P2>
              <P2 id="section-49-4">
                <Pnumber>4</Pnumber>
                <P2para>
                  <Text>In this Part the expression \u201c<Term id="term-street-managers">street managers</Term>\u201d, used in relation to a street which is not a maintainable highway, means the authority, body or person liable to the public to maintain or repair the street.</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_ukpga_1991_22", type_code: "ukpga"})

      assert length(defs) == 2

      sa = Enum.find(defs, &(&1.term == "street authority"))
      assert sa != nil, "Expected 'street authority' to be extracted"
      assert sa.scope == :part
      assert String.contains?(sa.definition, "maintainable highway")

      sm = Enum.find(defs, &(&1.term == "street managers"))
      assert sm != nil, "Expected 'street managers' to be extracted"
      assert String.contains?(sm.definition, "liable to the public")

      assert Enum.all?(defs, &(&1.source == :section_term))
    end
  end

  # ── Section-level definitions: enumerated list (Term + means + P3 items) ───
  # Articles 3, 4, 25 of Fire Safety Order define terms as:
  #   "responsible person" means— (a)...; (b)...
  # The <Term> element sits in a P2, definition spans sibling P3 elements.

  describe "parse/2 with section-level Term + enumerated list definitions" do
    test "extracts definition from Term + means— with P3 sub-items" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="article-3">
            <Pnumber>3</Pnumber>
            <P1para>
              <Text>In this Order \u201c<Term id="term-responsible-person">responsible person</Term>\u201d means\u2014</Text>
              <P3 id="article-3-a">
                <Pnumber>a</Pnumber>
                <P3para>
                  <Text>in relation to a workplace, the employer, if the workplace is to any extent under his control;</Text>
                </P3para>
              </P3>
              <P3 id="article-3-b">
                <Pnumber>b</Pnumber>
                <P3para>
                  <Text>in relation to any premises not falling within paragraph (a)\u2014</Text>
                  <P4 id="article-3-b-i">
                    <Pnumber>i</Pnumber>
                    <P4para><Text>the person who has control of the premises in connection with the carrying on of a trade, business or other undertaking; or</Text></P4para>
                  </P4>
                  <P4 id="article-3-b-ii">
                    <Pnumber>ii</Pnumber>
                    <P4para><Text>the owner, where the person in control of the premises does not have control in connection with a trade.</Text></P4para>
                  </P4>
                </P3para>
              </P3>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2005_1541", type_code: "uksi"})

      rp = Enum.find(defs, &(&1.term == "responsible person"))
      assert rp != nil, "Expected 'responsible person' to be extracted"
      assert rp.section_id == "article-3"
      assert rp.scope == :law
      assert String.contains?(rp.definition, "employer")
      assert rp.references_other_law == false
      assert rp.source == :section_term
    end

    test "extracts definition from P2 with Term + means— and nested P3/P4" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="article-25">
            <Pnumber>25</Pnumber>
            <P1para>
              <P2 id="article-25-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>For the purposes of this Order, \u201c<Term id="term-enforcing-authority">enforcing authority</Term>\u201d means\u2014</Text>
                  <P3 id="article-25-1-a">
                    <Pnumber>a</Pnumber>
                    <P3para><Text>the fire and rescue authority for the area in which the premises are situated;</Text></P3para>
                  </P3>
                  <P3 id="article-25-1-b">
                    <Pnumber>b</Pnumber>
                    <P3para><Text>the Health and Safety Executive in relation to certain premises.</Text></P3para>
                  </P3>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2005_1541", type_code: "uksi"})

      ea = Enum.find(defs, &(&1.term == "enforcing authority"))
      assert ea != nil, "Expected 'enforcing authority' to be extracted"
      assert ea.section_id == "article-25-1"
      assert ea.scope == :law
      assert String.contains?(ea.definition, "fire and rescue authority")
    end
  end

  # ── Section-level definitions: parenthetical naming ──────────
  # Articles 29, 30, 31 of Fire Safety Order define terms as:
  #   ...a notice (in this Order referred to as "an alterations notice")
  # The <Term> appears inside parenthetical text, not in "means" pattern.

  describe "parse/2 with parenthetical Term definitions (referred to as)" do
    test "extracts term from 'referred to as <Term>' pattern" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="article-29">
            <Pnumber>29</Pnumber>
            <P1para>
              <P2 id="article-29-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>The enforcing authority may serve on the responsible person a notice (in this Order referred to as \u201c<Term id="term-an-alterations-notice">an alterations notice</Term>\u201d) if the authority is of the opinion that the premises constitute a serious risk to relevant persons.</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2005_1541", type_code: "uksi"})

      an = Enum.find(defs, &(&1.term == "alterations notice"))
      assert an != nil, "Expected 'alterations notice' to be extracted"
      assert an.section_id == "article-29-1"
      assert String.contains?(an.definition, "enforcing authority may serve")
      assert an.source == :section_term
    end

    test "extracts term from 'referred to as <Term>' at end of sentence" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="article-30">
            <Pnumber>30</Pnumber>
            <P1para>
              <P2 id="article-30-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>If the enforcing authority is of the opinion that the responsible person has failed to comply with any provision of this Order, the authority may serve on that person a notice (in this Order referred to as \u201c<Term id="term-an-enforcement-notice">an enforcement notice</Term>\u201d).</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2005_1541", type_code: "uksi"})

      en = Enum.find(defs, &(&1.term == "enforcement notice"))
      assert en != nil, "Expected 'enforcement notice' to be extracted"
      assert String.contains?(en.definition, "failed to comply")
    end

    test "extracts term from 'referred to as <Term>' — prohibition notice" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="article-31">
            <Pnumber>31</Pnumber>
            <P1para>
              <P2 id="article-31-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>If the enforcing authority is of the opinion that use of premises involves or will involve a risk to relevant persons so serious that use of the premises ought to be prohibited or restricted, the authority may serve on the responsible person a notice (in this Order referred to as \u201c<Term id="term-a-prohibition-notice">a prohibition notice</Term>\u201d).</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2005_1541", type_code: "uksi"})

      pn = Enum.find(defs, &(&1.term == "prohibition notice"))
      assert pn != nil, "Expected 'prohibition notice' to be extracted"
      assert String.contains?(pn.definition, "risk to relevant persons")
    end
  end

  # ── Section-level definitions: inline in sub-paragraph ───────
  # Article 42(3) of Fire Safety Order defines "licensing authority" in a P3:
  #   <P3><Text>"<Term>licensing authority</Term>" means...</Text></P3>
  # This is like a Definition list item but embedded in a P3 under a P2.

  describe "parse/2 with inline Term definition in sub-paragraph" do
    test "extracts definition from Term in P3 under P2" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="article-42">
            <Pnumber>42</Pnumber>
            <P1para>
              <P2 id="article-42-3">
                <Pnumber>3</Pnumber>
                <P2para>
                  <Text>In this article and article 43(1)(a)\u2014</Text>
                  <P3 id="article-42-3-a">
                    <Pnumber>a</Pnumber>
                    <P3para>
                      <Text>\u201c<Term id="term-licensing-authority">licensing authority</Term>\u201d means the authority responsible for issuing the licence; and</Text>
                    </P3para>
                  </P3>
                  <P3 id="article-42-3-b">
                    <Pnumber>b</Pnumber>
                    <P3para>
                      <Text>\u201c<Term id="term-relevant-licence">relevant licence</Term>\u201d means a licence under an enactment.</Text>
                    </P3para>
                  </P3>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2005_1541", type_code: "uksi"})

      la = Enum.find(defs, &(&1.term == "licensing authority"))
      assert la != nil, "Expected 'licensing authority' to be extracted"
      assert la.section_id == "article-42-3"
      assert String.contains?(la.definition, "authority responsible for issuing")
      assert la.source == :section_term

      rl = Enum.find(defs, &(&1.term == "relevant licence"))
      assert rl != nil, "Expected 'relevant licence' to be extracted"
      assert rl.source == :section_term
    end
  end

  # ── Same term in Definition list AND body section ─────────────
  # A Definition list may have a delegated def ("has the meaning given in
  # regulation 6") while regulation 6 has the actual definition via <Term>.
  # Both should be extracted — different section_ids.

  describe "parse/2 extracts both delegated and root definitions for same term" do
    test "extracts root definition from body section when delegated def exists in Definition list" do
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
                        <Text>\u201c<Term id="term-local-authority">local authority</Term>\u201d has the meaning given in regulation 6;</Text>
                      </Para>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
          <P1 id="regulation-6">
            <Pnumber>6</Pnumber>
            <P1para>
              <P2 id="regulation-6-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In these Regulations, \u201c<Term id="term-local-authority-2">local authority</Term>\u201d means\u2014</Text>
                  <P3 id="regulation-6-1-a">
                    <Pnumber>a</Pnumber>
                    <P3para><Text>a district council,</Text></P3para>
                  </P3>
                  <P3 id="regulation-6-1-b">
                    <Pnumber>b</Pnumber>
                    <P3para><Text>a county council.</Text></P3para>
                  </P3>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2016_1154", type_code: "uksi"})

      la_defs = Enum.filter(defs, &(&1.term == "local authority"))

      assert length(la_defs) == 2,
             "Expected 2 'local authority' definitions, got #{length(la_defs)}"

      sections = Enum.map(la_defs, & &1.section_id) |> Enum.sort()
      assert "regulation-2-1" in sections
      assert "regulation-6-1" in sections

      delegated = Enum.find(la_defs, &(&1.section_id == "regulation-2-1"))
      assert delegated.source == :definition_list

      root = Enum.find(la_defs, &(&1.section_id == "regulation-6-1"))
      assert String.contains?(root.definition, "district council")
      assert root.source == :section_term
    end
  end

  # ── Strategy 3 must not override Strategy 1 references_other_law ──
  # When Strategy 1 extracts "emission" from a Definition list with ref=false,
  # Strategy 3 must not add a duplicate with ref=true from the P2 full text.

  describe "parse/2 Strategy 3 does not override Strategy 1 for same {term, section_id}" do
    test "emission in Definition list keeps references_other_law=false even when sibling defs are cross-refs" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-67">
            <Pnumber>67</Pnumber>
            <P1para>
              <P2 id="regulation-67-4">
                <Pnumber>4</Pnumber>
                <P2para>
                  <Text>In this regulation\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem><Para><Text>\u201c<Term id="term-emission">emission</Term>\u201d means the direct or indirect release of any substance from individual or diffuse sources;</Text></Para></ListItem>
                    <ListItem><Para><Text>\u201c<Term id="term-emission-plan">emission plan</Term>\u201d has the meaning given in the LCP Regulations 2007;</Text></Para></ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        DefinitionParser.parse(xml, %{law_name: "UK_uksi_2016_1154", type_code: "uksi"})

      emission = Enum.find(defs, &(&1.term == "emission"))
      assert emission != nil

      assert emission.references_other_law == false,
             "emission should not be flagged as cross-ref"

      plan = Enum.find(defs, &(&1.term == "emission plan"))
      assert plan != nil
      assert plan.references_other_law == true

      assert Enum.all?(defs, &(&1.source == :definition_list))
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

  # ── Amendment markup wrapping Term/definition text ────────────
  # Some definitions have <Addition>/<Substitution> elements wrapping the
  # term and definition text (amendment tracked markup). The parser must
  # see through these wrappers to extract the term and definition.

  describe "parse/2 with <Addition> wrapped Term elements" do
    test "extracts term from <Term> containing <Addition> child" do
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
                        <Text> <Addition>\u201c</Addition><Term><Addition>the Waste Directive</Addition></Term><Addition>\u201d means Directive </Addition><Citation URI="http://example.com" id="c1" Class="EuropeanUnionDirective" Year="2008" Number="98"><Addition>2008/98/EC</Addition></Citation><Addition> of the European Parliament and of the Council on waste</Addition>;</Text>
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
        DefinitionParser.parse(xml, %{law_name: "UK_uksi_2013_3113", type_code: "uksi"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "waste directive"
      assert String.contains?(d.definition, "2008/98/EC")
    end
  end

  # ── Single-quoted definitions in OrderedList (EU directives) ──
  # EU directives on legislation.gov.uk use OrderedList with straight
  # single quotes: 'waste' means ...
  # No <Term> elements, no Class="Definition", no curly quotes.

  describe "parse/2 with single-quoted definitions in OrderedList (EU directive)" do
    test "extracts definitions from single-quoted terms in OrderedList" do
      # Real EU directive structure: OrderedList inside P1para, no P2 wrapper.
      # Multiple P1 articles — only article-3 has definitions.
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="article-2">
            <Pnumber>2</Pnumber>
            <P1para>
              <P2 id="article-2-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>This Directive applies to waste management operations.</Text>
                </P2para>
              </P2>
              <P2 id="article-2-2">
                <Pnumber>2</Pnumber>
                <P2para>
                  <Text>The following shall be excluded from the scope of this Directive.</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
          <P1 id="article-3">
            <Pnumber>3</Pnumber>
            <P1para>
              <Text>For the purposes of this Directive, the following definitions shall apply:</Text>
            </P1para>
            <P1para>
              <OrderedList Type="arabic" Decoration="period">
                <ListItem NumberOverride="1.">
                  <Para>
                    <Text>\u2018waste\u2019 means any substance or object which the holder discards or intends or is required to discard;</Text>
                  </Para>
                </ListItem>
                <ListItem NumberOverride="2.">
                  <Para>
                    <Text>\u2018hazardous waste\u2019 means waste which displays one or more of the hazardous properties listed in Annex III;</Text>
                  </Para>
                </ListItem>
                <ListItem NumberOverride="10.">
                  <Para>
                    <Text>\u2018collection\u2019 means the gathering of waste, including the preliminary sorting and preliminary storage of waste for the purposes of transport to a waste treatment facility;</Text>
                  </Para>
                </ListItem>
              </OrderedList>
            </P1para>
          </P1>
          <P1 id="article-4">
            <Pnumber>4</Pnumber>
            <P1para>
              <Text>The following waste hierarchy shall apply as a priority order in waste prevention and management legislation and policy.</Text>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        DefinitionParser.parse(xml, %{law_name: "UK_eudr_2008_98", type_code: "eudr"})

      assert length(defs) == 3

      waste = Enum.find(defs, &(&1.term == "waste"))
      assert waste != nil, "Expected 'waste' to be extracted"
      assert String.contains?(waste.definition, "substance or object")
      assert waste.references_other_law == false

      hw = Enum.find(defs, &(&1.term == "hazardous waste"))
      assert hw != nil, "Expected 'hazardous waste' to be extracted"
      assert String.contains?(hw.definition, "hazardous properties")

      coll = Enum.find(defs, &(&1.term == "collection"))
      assert coll != nil, "Expected 'collection' to be extracted"
      assert String.contains?(coll.definition, "gathering of waste")

      assert Enum.all?(defs, &(&1.source == :inline_text))
    end
  end

  # ── Law titles containing commas ──────────────────────────────
  # Some law titles contain commas (e.g. "Small Business, Enterprise and
  # Employment Act 2015"). The definition prefix stripper must not split
  # on internal commas in the law title.

  describe "parse/2 with comma in referenced law title" do
    test "preserves full law title with commas in cross-reference definition" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-80">
            <Pnumber>80</Pnumber>
            <P1para>
              <P2 id="regulation-80-6">
                <Pnumber>6</Pnumber>
                <P2para>
                  <Text>In this regulation, \u201c<Term id="term-regulatory-provisions">regulatory provisions</Term>\u201d has the meaning given in section 32(4) of the Small Business, Enterprise and Employment Act 2015.</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2016_1154", type_code: "uksi"})

      rp = Enum.find(defs, &(&1.term == "regulatory provisions"))
      assert rp != nil, "Expected 'regulatory provisions' to be extracted"
      assert String.contains?(rp.definition, "Small Business, Enterprise and Employment Act 2015")
      assert rp.references_other_law == true
      assert rp.source == :section_term
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
        assert d.source == :definition_list
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

  # ── TDD: section_id bug — fingerprint matches wrong P2 ────────
  # When the same term appears in Definition lists in two different sections,
  # the fingerprint-based find_section_id returns the FIRST P2 match for both,
  # giving the second list the wrong section_id. The inverted approach (walking
  # P2 elements top-down) assigns the correct section_id from the parent element.

  describe "parse/2 assigns correct section_id to Definition lists in different sections" do
    setup do
      # Two P2 sections each with their own Definition list.
      # "waste" appears in both — reg-2-1 (law-wide) and reg-67-4 (regulation-specific).
      # The fingerprint for reg-67-4's list is "waste", which also appears in reg-2-1's text.
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
                    <ListItem><Para><Text>\u201c<Term id="term-waste">waste</Term>\u201d means any substance or object which the holder discards;</Text></Para></ListItem>
                    <ListItem><Para><Text>\u201c<Term id="term-operator">operator</Term>\u201d means any natural or legal person who operates an installation;</Text></Para></ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
          <P1 id="regulation-67">
            <Pnumber>67</Pnumber>
            <P1para>
              <P2 id="regulation-67-4">
                <Pnumber>4</Pnumber>
                <P2para>
                  <Text>In this regulation\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem><Para><Text>\u201c<Term id="term-waste-2">waste</Term>\u201d means waste as classified under Commission Decision 2000/532/EC;</Text></Para></ListItem>
                    <ListItem><Para><Text>\u201c<Term id="term-emission">emission</Term>\u201d means the direct or indirect release of substances;</Text></Para></ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs =
        DefinitionParser.parse(xml, %{law_name: "UK_uksi_2016_1154", type_code: "uksi"})

      %{defs: defs}
    end

    test "regulation-2-1 definitions have correct section_id", %{defs: defs} do
      reg2_defs = Enum.filter(defs, &(&1.section_id == "regulation-2-1"))
      reg2_terms = Enum.map(reg2_defs, & &1.term) |> Enum.sort()
      assert "operator" in reg2_terms
      # "waste" at reg-2-1 should exist (law-wide definition)
      assert "waste" in reg2_terms
    end

    test "regulation-67-4 definitions have correct section_id", %{defs: defs} do
      reg67_defs = Enum.filter(defs, &(&1.section_id == "regulation-67-4"))
      reg67_terms = Enum.map(reg67_defs, & &1.term) |> Enum.sort()
      assert "emission" in reg67_terms
      # "waste" at reg-67-4 should exist (regulation-specific definition)
      assert "waste" in reg67_terms,
             "Expected 'waste' at regulation-67-4 but found it at: #{inspect(Enum.filter(defs, &(&1.term == "waste")) |> Enum.map(& &1.section_id))}"
    end

    test "both 'waste' definitions are preserved with different section_ids", %{defs: defs} do
      waste_defs = Enum.filter(defs, &(&1.term == "waste"))

      assert length(waste_defs) == 2,
             "Expected 2 'waste' definitions, got #{length(waste_defs)}: #{inspect(Enum.map(waste_defs, & &1.section_id))}"

      waste_sections = Enum.map(waste_defs, & &1.section_id) |> Enum.sort()
      assert waste_sections == ["regulation-2-1", "regulation-67-4"]
    end

    test "regulation-67-4 definitions have provision scope", %{defs: defs} do
      reg67_defs = Enum.filter(defs, &(&1.section_id == "regulation-67-4"))

      assert Enum.all?(reg67_defs, &(&1.scope == :provision)),
             "reg-67-4 preamble 'In this regulation' should give :provision scope"
    end

    test "total definition count is 4 (2 per section)", %{defs: defs} do
      assert length(defs) == 4
    end
  end

  # ── TDD: Definition list nested inside P3 under P2 ────────────
  # Some instruments nest Definition lists inside P3 elements under a P2.
  # The section_id should be the P2's id (the nearest ancestor with an @id).

  describe "parse/2 with Definition list nested in P3 under P2" do
    test "assigns P2 section_id to Definition list inside P3" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="regulation-5">
            <Pnumber>5</Pnumber>
            <P1para>
              <P2 id="regulation-5-2">
                <Pnumber>2</Pnumber>
                <P2para>
                  <Text>For the purposes of paragraph (1)\u2014</Text>
                  <P3 id="regulation-5-2-a">
                    <Pnumber>a</Pnumber>
                    <P3para>
                      <Text>the following definitions apply\u2014</Text>
                      <UnorderedList Decoration="none" Class="Definition">
                        <ListItem><Para><Text>\u201c<Term id="term-relevant-building">relevant building</Term>\u201d means a building to which this regulation applies;</Text></Para></ListItem>
                        <ListItem><Para><Text>\u201c<Term id="term-responsible-person-2">responsible person</Term>\u201d means the person having control of the building;</Text></Para></ListItem>
                      </UnorderedList>
                    </P3para>
                  </P3>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2022_1100", type_code: "uksi"})

      assert length(defs) == 2
      assert Enum.all?(defs, &(&1.section_id == "regulation-5-2"))
      assert Enum.all?(defs, &(&1.source == :definition_list))
    end
  end

  # ── Definition list item bleed (GH #148) ───────────────────────
  # When a ListItem contains a nested UnorderedList[@Class='Definition'],
  # the parent's .//Text picks up the nested items' text. The fix excludes
  # nested Definition list text from the parent, since those lists are
  # processed independently.

  describe "parse/2 with nested Definition lists (no bleed)" do
    test "parent ListItem definition does not include nested Definition list text" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="section-329">
            <Pnumber>329</Pnumber>
            <P1para>
              <P2 id="section-329-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In this Act\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201cact of 1965\u201d means the Compulsory Purchase Act 1965;</Text>
                      </Para>
                      <UnorderedList Decoration="none" Class="Definition">
                        <ListItem>
                          <Para>
                            <Text>\u201cadjoining\u201d includes abutting on;</Text>
                          </Para>
                        </ListItem>
                        <ListItem>
                          <Para>
                            <Text>\u201ccarriageway\u201d means a way for vehicles;</Text>
                          </Para>
                        </ListItem>
                      </UnorderedList>
                    </ListItem>
                    <ListItem>
                      <Para>
                        <Text>\u201cwild oat\u201d means plants of Avena fatua;</Text>
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

      defs = DefinitionParser.parse(xml, %{law_name: "UK_test_bleed", type_code: "ukpga"})

      assert length(defs) == 4

      act = Enum.find(defs, &(&1.term == "act of 1965"))
      assert act != nil
      assert act.definition == "the Compulsory Purchase Act 1965"
      refute String.contains?(act.definition, "adjoining")
      refute String.contains?(act.definition, "carriageway")

      adjoining = Enum.find(defs, &(&1.term == "adjoining"))
      assert adjoining != nil
      assert adjoining.definition == "abutting on"

      carriageway = Enum.find(defs, &(&1.term == "carriageway"))
      assert carriageway != nil
      assert carriageway.definition == "a way for vehicles"

      wild_oat = Enum.find(defs, &(&1.term == "wild oat"))
      assert wild_oat != nil
      assert wild_oat.definition == "plants of Avena fatua"
    end

    test "legitimate OrderedList sub-items are preserved in definition text" do
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
                        <Text>\u201cworkplace\u201d means any premises and includes\u2014</Text>
                        <OrderedList Type="alpha" Decoration="parens">
                          <ListItem>
                            <Para><Text>any place within the premises; and</Text></Para>
                          </ListItem>
                          <ListItem>
                            <Para><Text>any room, lobby, or corridor.</Text></Para>
                          </ListItem>
                        </OrderedList>
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

      defs = DefinitionParser.parse(xml, %{law_name: "UK_test_subitems", type_code: "uksi"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "workplace"
      assert String.contains?(d.definition, "any place within the premises")
      assert String.contains?(d.definition, "any room, lobby, or corridor")
    end

    test "OrderedList sub-items are separated by newlines in definition text" do
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
                        <Text>\u201c<Term id="term-importer">importer</Term>\u201d means a person who\u2014</Text>
                        <OrderedList Type="alpha" Decoration="parens">
                          <ListItem NumberOverride="a">
                            <Para><Text>is established in the United Kingdom; or</Text></Para>
                          </ListItem>
                          <ListItem NumberOverride="b">
                            <Para><Text>is established in Northern Ireland.</Text></Para>
                          </ListItem>
                        </OrderedList>
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

      defs = DefinitionParser.parse(xml, %{law_name: "UK_test_newlines", type_code: "uksi"})

      assert length(defs) == 1
      d = hd(defs)
      assert d.term == "importer"

      # List items must be on separate lines
      assert String.contains?(d.definition, "\n"),
             "Expected newlines between list items, got: #{inspect(d.definition)}"

      lines =
        d.definition
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      assert Enum.any?(lines, &String.contains?(&1, "established in the United Kingdom")),
             "Missing first list item"

      assert Enum.any?(lines, &String.contains?(&1, "established in Northern Ireland")),
             "Missing second list item"
    end

    test "nested Definition list text excluded but OrderedList newlines preserved" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="section-1">
            <Pnumber>1</Pnumber>
            <P1para>
              <P2 id="section-1-1">
                <Pnumber>1</Pnumber>
                <P2para>
                  <Text>In this Act\u2014</Text>
                  <UnorderedList Decoration="none" Class="Definition">
                    <ListItem>
                      <Para>
                        <Text>\u201c<Term id="term-authority">authority</Term>\u201d means\u2014</Text>
                        <OrderedList Type="alpha" Decoration="parens">
                          <ListItem NumberOverride="a">
                            <Para><Text>a county council; or</Text></Para>
                          </ListItem>
                          <ListItem NumberOverride="b">
                            <Para><Text>a district council.</Text></Para>
                          </ListItem>
                        </OrderedList>
                      </Para>
                      <UnorderedList Decoration="none" Class="Definition">
                        <ListItem>
                          <Para>
                            <Text>\u201c<Term id="term-officer">officer</Term>\u201d means an inspector;</Text>
                          </Para>
                        </ListItem>
                      </UnorderedList>
                    </ListItem>
                  </UnorderedList>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_test_combined", type_code: "ukpga"})

      authority = Enum.find(defs, &(&1.term == "authority"))
      assert authority != nil

      # OrderedList items have newlines
      assert String.contains?(authority.definition, "\n")
      assert String.contains?(authority.definition, "county council")
      assert String.contains?(authority.definition, "district council")

      # Nested Definition list text is excluded
      refute String.contains?(authority.definition, "officer")
      refute String.contains?(authority.definition, "inspector")

      # Nested definition extracted separately
      officer = Enum.find(defs, &(&1.term == "officer"))
      assert officer != nil
      assert officer.definition =~ "inspector"
    end
  end

  # ── TDD: Structural invariants ─────────────────────────────────
  # Every parsed definition must satisfy basic structural properties
  # regardless of the input XML. These catch bugs like empty-term
  # extraction from spurious S2 matches.

  describe "structural invariants" do
    test "all definitions from Workplace Regs satisfy invariants" do
      xml = read_fixture("body_uksi_1992_3004.xml")
      assert_definition_invariants(xml, "UK_uksi_1992_3004", "uksi")
    end

    test "all definitions from RIDDOR satisfy invariants" do
      xml = read_fixture("body_uksi_2013_1471.xml")
      assert_definition_invariants(xml, "UK_uksi_2013_1471", "uksi")
    end

    defp assert_definition_invariants(xml, law_name, type_code) do
      defs = DefinitionParser.parse(xml, %{law_name: law_name, type_code: type_code})

      for d <- defs do
        # Term must be non-nil, non-empty, non-whitespace
        assert d.term != nil, "term must not be nil"
        assert d.term != "", "term must not be empty"
        assert String.trim(d.term) != "", "term must not be whitespace"

        # law_name must match input
        assert d.law_name == law_name,
               "law_name '#{d.law_name}' must match input '#{law_name}'"

        # source must be one of the three strategy atoms
        assert d.source in [:definition_list, :inline_text, :section_term],
               "source #{inspect(d.source)} must be :definition_list, :inline_text, or :section_term"

        # section_id must be nil or a non-empty string
        assert is_nil(d.section_id) or (is_binary(d.section_id) and d.section_id != ""),
               "section_id must be nil or non-empty string, got #{inspect(d.section_id)}"

        # references_other_law must be boolean
        assert is_boolean(d.references_other_law),
               "references_other_law must be boolean, got #{inspect(d.references_other_law)}"

        # scope must be nil or one of the three atoms
        assert d.scope in [nil, :law, :part, :provision],
               "scope #{inspect(d.scope)} must be nil, :law, :part, or :provision"

        # term must be lowercase (normalise_term guarantees this)
        assert d.term == String.downcase(d.term),
               "term '#{d.term}' must be lowercase"
      end
    end
  end

  # ── TDD: Malformed XML edge cases ──────────────────────────────
  # Parser should return [] gracefully for malformed or empty input,
  # not crash.

  describe "parse/2 with malformed or minimal XML" do
    test "returns [] for XML with no Body element" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Metadata>
          <PrimaryMetadata/>
        </Metadata>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2024_1", type_code: "uksi"})
      assert defs == []
    end

    test "returns [] for empty Body element" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body/>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_uksi_2024_1", type_code: "uksi"})
      assert defs == []
    end

    test "returns [] for minimal valid XML with no definitions" do
      xml = """
      <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation">
        <Body>
          <P1 id="section-1">
            <Pnumber>1</Pnumber>
            <P1para>
              <Text>This Act may be cited as the Short Titles Act 2024.</Text>
            </P1para>
          </P1>
        </Body>
      </Legislation>
      """

      defs = DefinitionParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      assert defs == []
    end
  end

  # ── HSWA 1974 section 53 ─────────────────────────────────────
  # Blob parser bug: UnorderedList Decoration="none" with <Term> elements
  # inside <ListItem> — S1 skips (no Class="Definition"), S3 grabs full P2 text.
  # Each definition should be short (~50-200 chars), not 3000-6000 char blobs.

  describe "parse/2 with HSWA 1974 section 53 (Term-bearing non-Definition list)" do
    setup do
      xml = read_fixture("section_ukpga_1974_37_s53.xml")
      defs = DefinitionParser.parse(xml, %{law_name: "UK_ukpga_1974_37", type_code: "ukpga"})
      %{defs: defs}
    end

    test "extracts individual definitions, not blobs", %{defs: defs} do
      # Each definition should be under 600 chars (not 3000-6000 char blobs)
      # Some definitions with enumerated sub-items are legitimately ~500-600 chars
      blobs = Enum.filter(defs, fn d -> String.length(d.definition || "") > 600 end)

      assert blobs == [],
             "Found #{length(blobs)} blob definitions (>600 chars): #{Enum.map(blobs, & &1.term) |> Enum.join(", ")}"
    end

    test "extracts all definitions from fixture", %{defs: defs} do
      # Minimal fixture has 28 Term elements (stripped from full 38 for push protection)
      assert length(defs) >= 28,
             "Expected >= 28 definitions, got #{length(defs)}"
    end

    test "employee definition is concise", %{defs: defs} do
      employee = Enum.find(defs, &(&1.term == "employee"))
      assert employee != nil, "employee definition not found"

      assert String.length(employee.definition) < 300,
             "employee definition is a blob: #{String.length(employee.definition)} chars"

      assert employee.definition =~ "works under a contract of employment"
    end

    test "substance definition is concise", %{defs: defs} do
      sub = Enum.find(defs, &(&1.term == "substance"))
      assert sub != nil, "substance not found"
      assert String.length(sub.definition) < 300
    end

    test "definitions are from definition_list source, not section_term", %{defs: defs} do
      # S1 should handle these (higher priority than S3)
      sources = defs |> Enum.map(& &1.source) |> Enum.uniq()

      assert :definition_list in sources,
             "Expected definition_list source, got: #{inspect(sources)}"
    end
  end

  # ── EU Regulation Annex definitions ────────────────────────────
  # Terms defined in EU regulation annexes using 'Term' means ... pattern

  describe "parse_annex/2 with Reg 853/2004 Annex I" do
    setup do
      xml = read_fixture("annex_eur_2004_853.xml")
      defs = DefinitionParser.parse_annex(xml, %{law_name: "UK_eur_2004_853", type_code: "eur"})
      %{defs: defs}
    end

    test "extracts meat definition", %{defs: defs} do
      meat = Enum.find(defs, &(&1.term == "meat"))
      assert meat != nil, "meat not found"
      assert meat.definition =~ "edible parts"
    end

    test "extracts domestic ungulates", %{defs: defs} do
      du = Enum.find(defs, &(&1.term == "domestic ungulates"))
      assert du != nil, "domestic ungulates not found"
      assert du.definition =~ "bovine"
    end

    test "extracts poultry with spaces inside quotes", %{defs: defs} do
      p = Enum.find(defs, &(&1.term == "poultry"))
      assert p != nil, "poultry not found"
      assert p.definition =~ "farmed birds"
    end

    test "extracts mechanically separated meat", %{defs: defs} do
      msm = Enum.find(defs, &(&1.term == "mechanically separated meat"))
      assert msm != nil, "mechanically separated meat not found"
      assert msm.definition =~ "flesh-bearing bones"
    end

    test "extracts all 9 definitions from fixture", %{defs: defs} do
      assert length(defs) == 9
    end

    test "all definitions have annex source", %{defs: defs} do
      assert Enum.all?(defs, &(&1.source == :annex))
    end

    test "section_ids reference annex divisions", %{defs: defs} do
      meat = Enum.find(defs, &(&1.term == "meat"))
      assert meat.section_id =~ "annex-I"
    end
  end

  # ── "includes" as definition verb (S3 enhancement) ────────────
  # Terms defined with "includes" instead of "means" should be extracted

  describe "parse/2 with 'includes' definition verb" do
    setup do
      xml = read_fixture("section_includes_verb.xml")
      defs = DefinitionParser.parse(xml, %{law_name: "UK_ukpga_1964_29", type_code: "ukpga"})
      %{defs: defs}
    end

    test "extracts term defined with 'includes'", %{defs: defs} do
      installation = Enum.find(defs, &(&1.term == "installation"))
      assert installation != nil, "installation not found — 'includes' verb not supported"
      assert installation.definition =~ "floating structure"
    end

    test "still extracts standard 'means' term", %{defs: defs} do
      designated = Enum.find(defs, &(&1.term == "designated area"))
      assert designated != nil
      assert designated.definition =~ "designated by Order"
    end

    test "extracts all 3 definitions", %{defs: defs} do
      terms = Enum.map(defs, & &1.term) |> Enum.sort()
      assert "designated area" in terms
      assert "installation" in terms
      assert "relevant authority" in terms
    end

    test "all are section_term source", %{defs: defs} do
      assert Enum.all?(defs, &(&1.source == :section_term))
    end
  end
end
