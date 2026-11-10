defmodule SertantaiLegal.Scraper.Amendment.Reader.EnvironmentalProtectionFormsTest do
  @moduledoc """
  Amending wordings read for Environmental Protection: Amending-law reader
  (2026-11-10, Decision 1), each on its law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Evaluator, Reader}

  defp doc(amending, body),
    do:
      Doc.new(amending, [~s(<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>)])

  defp targets(rules), do: rules |> Enum.flat_map(& &1.targets) |> Enum.uniq() |> Enum.sort()

  defp reached(rules, law, sid),
    do: for(r <- rules, {:ok, t} <- [Evaluator.reach(r, "#{law}:" <> sid)], uniq: true, do: t)

  describe "an Order's articles under LAT's reg. prefix (F1)" do
    @nrw Reader.law_ref(
           "UK_wsi_2012_1903",
           "Natural Resources Body for Wales (Establishment) Order",
           "reg",
           articles: true
         )

    test "\"In article 11, for paragraphs (2) to (4) substitute— (2) … (9)\": the quote is article 11's (WSI 2013/755 Sch.1 para.12)" do
      d =
        doc(
          "UK_wsi_2013_755",
          ~S|<P1 id="schedule-1-paragraph-1"><P1para><Text>The Natural Resources Body for Wales (Establishment) Order 2012 is amended as follows.</Text></P1para></P1>| <>
            ~S|<P1 id="schedule-1-paragraph-12"><P1para><Text>In article 11, for paragraphs (2) to (4) substitute—</Text><BlockAmendment><P2><Pnumber>2</Pnumber><P2para><Text>new 2</Text><P3><Pnumber>a</Pnumber><P3para><Text>new 2a</Text></P3para></P3></P2para></P2><P2><Pnumber>3</Pnumber><P2para><Text>new 3</Text></P2para></P2><P2><Pnumber>4</Pnumber><P2para><Text>new 4</Text></P2para></P2><P2><Pnumber>5</Pnumber><P2para><Text>new 5</Text></P2para></P2></BlockAmendment></P1para></P1>|
        )

      rules = Reader.instruction(d, "schedule-1-paragraph-12", %{}, [@nrw])
      ts = targets(rules)

      assert "reg.11(2)" in ts and "reg.11(5)" in ts
      refute Enum.any?(ts, &(&1 in ["reg.2", "reg.3", "reg.5"]))
    end

    test "\"Article 2 (interpretation) is amended as follows. … After paragraph (6) insert— (7)\": article 2's paragraph (SI 2017/1234 on the Renewables Obligation Order 2015)" do
      ro =
        Reader.law_ref("UK_uksi_2015_1947", "Renewables Obligation Order", "reg", articles: true)

      d =
        doc(
          "UK_uksi_2017_1234",
          ~S|<P1 id="regulation-3"><P1para><P2 id="regulation-3-1"><P2para><Text>Article 2 (interpretation) of the Renewables Obligation Order 2015 is amended as follows.</Text></P2para></P2><P2 id="regulation-3-3"><P2para><Text>After paragraph (6) insert—</Text><BlockAmendment><P2><Pnumber>7</Pnumber><P2para><Text>A reference in this Order to residue …</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|
        )

      rules = Reader.instruction(d, "regulation-3-3", %{}, [ro])
      assert targets(rules) == ["reg.2(7)"]
    end

    test "an Order's \"regulation\" is no provision of it, and a Regulations' \"article\" none of its" do
      regs = Reader.law_ref("UK_uksi_2005_1806", "Hazardous Waste (Wales) Regulations", "reg")
      assert regs.kind == :regulation
      assert @nrw.kind == :order
    end
  end

  test "reached on the amended law's rows" do
    nrw =
      Reader.law_ref(
        "UK_wsi_2012_1903",
        "Natural Resources Body for Wales (Establishment) Order",
        "reg",
        articles: true
      )

    d =
      doc(
        "UK_wsi_2020_1215",
        ~S|<P1 id="regulation-2"><P1para><P2 id="regulation-2-1"><P2para><Text>The Natural Resources Body for Wales (Establishment) Order 2012 is amended as follows.</Text></P2para></P2><P2 id="regulation-2-2"><P2para><Text>For article 11(3), substitute—</Text><BlockAmendment><P2><Pnumber>3</Pnumber><P2para><Text>new 3</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|
      )

    rules = Reader.instruction(d, "regulation-2-2", %{}, [nrw])
    assert "UK_wsi_2012_1903:reg.11(3)" in reached(rules, "UK_wsi_2012_1903", "reg.11(3)")
    assert reached(rules, "UK_wsi_2012_1903", "reg.3") == []
  end

  describe "a Schedule's paragraphs are never the amended law's provisions (F2)" do
    @ea95 Reader.law_ref("UK_ukpga_1995_25", "Environment Act", "s")
    @forestry Reader.law_ref(
                "UK_uksi_1999_2228",
                "Environmental Impact Assessment (Forestry) (England and Wales) Regulations",
                "reg"
              )

    test "\"Amend Schedule 7 to the Environment Act 1995 … as follows. In paragraph 1, for sub-paragraphs (2) to (6) substitute—\" (2006 c.16 s.61)" do
      d =
        doc(
          "UK_ukpga_2006_16",
          ~S|<P1 id="section-61"><P1para><P2 id="section-61-1"><P2para><Text>Amend Schedule 7 to the Environment Act 1995 (c. 25) (National Park authorities) as follows.</Text></P2para></P2><P2 id="section-61-2"><P2para><Text>In paragraph 1, for sub-paragraphs (2) to (6) (constitution of National Park authorities) substitute—</Text><BlockAmendment><P3><Pnumber>2</Pnumber><P3para><Text>new 2</Text></P3para></P3><P3><Pnumber>3</Pnumber><P3para><Text>new 3</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|
        )

      assert Reader.instruction(d, "section-61-2", %{}, [@ea95]) == []
    end

    test "\"Schedule 2 is amended in accordance with paragraphs (7) to (10)\", a later sibling's lead-in: \"For paragraph 2(1) substitute—\" is Schedule 2's (SI 2018/942 reg.8)" do
      d =
        doc(
          "UK_uksi_2018_942",
          ~S|<P1 id="regulation-8"><P1para><P2 id="regulation-8-1"><P2para><Text>The Environmental Impact Assessment (Forestry) (England and Wales) Regulations 1999 are amended as follows.</Text></P2para></P2><P2 id="regulation-8-2"><P2para><Text>In regulation 2(1) omit the definition of “EEA State”.</Text></P2para></P2><P2 id="regulation-8-5"><P2para><Text>In regulation 6, after paragraph (1A) insert—</Text><BlockAmendment><P3><Pnumber>1B</Pnumber><P3para><Text>new 1B</Text></P3para></P3></BlockAmendment></P2para></P2><P2 id="regulation-8-6"><P2para><Text>Schedule 2 is amended in accordance with paragraphs (7) to (10).</Text></P2para></P2><P2 id="regulation-8-10"><P2para><Text>For paragraph 2(1) substitute—</Text><BlockAmendment><P3><Pnumber>1</Pnumber><P3para><Text>new 1</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|
        )

      assert Reader.instruction(d, "regulation-8-10", %{}, [@forestry]) == []
      # the regulation before the lead-in is still read
      assert targets(Reader.instruction(d, "regulation-8-5", %{}, [@forestry])) == ["reg.6(1B)"]
    end

    test "a bare \"paragraph 8\" is a Schedule's: \"Paragraph 8 becomes paragraph 8(1) and after that sub-paragraph insert—\" (WSI 2020/1628 reg.17(5))" do
      plants =
        Reader.law_ref(
          "UK_uksi_2020_206",
          "Plant Health (Amendment etc.) (EU Exit) Regulations",
          "reg"
        )

      d =
        doc(
          "UK_wsi_2020_1628",
          ~S|<P1 id="regulation-17"><P1para><P2 id="regulation-17-1"><P2para><Text>Part 4 is amended as follows.</Text></P2para></P2><P2 id="regulation-17-5"><P2para><Text>Paragraph 8 becomes paragraph 8(1) and after that sub-paragraph insert—</Text><BlockAmendment><P3><Pnumber>2</Pnumber><P3para><Text>new 2</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|
        )

      assert Reader.instruction(d, "regulation-17-5", %{}, [plants]) == []
    end
  end

  test "a commencement naming provisions \"to be inserted\" changes nothing (SSI 2025/165 reg.1(4)) (F3)" do
    epa =
      Reader.law_ref(
        "UK_ssi_2018_219",
        "Environmental Authorisations (Scotland) Regulations",
        "reg"
      )

    d =
      doc(
        "UK_ssi_2025_165",
        ~S|<P1 id="regulation-1"><P1para><P2 id="regulation-1-4"><P2para><Text>Subject to paragraph (5), the following regulations come into force on 1 June 2025—</Text><P3 id="regulation-1-4-b"><P3para><Text>regulation 6, insofar as new regulation 3(1)(a) and (c), and (2B) to be inserted into the 2018 Regulations,</Text></P3para></P3></P2para></P2></P1para></P1>|
      )

    terms = %{
      "the 2018 regulations" => %{
        law: "UK_ssi_2018_219",
        title: "Environmental Authorisations (Scotland) Regulations 2018"
      }
    }

    assert Reader.instruction(d, "regulation-1-4-b", terms, [epa]) == []
  end

  describe "a modification in the instruction's own words changes no text (RULES modification-is-not-a-change, Forms)" do
    @msa Reader.law_ref("UK_ukpga_1995_21", "Merchant Shipping Act", "s")

    defp modifying(words) do
      d =
        doc(
          "UK_uksi_1995_3128",
          ~s|<P1 id="regulation-10"><P1para><P2 id="regulation-10-3"><P2para><Text>#{words}</Text><BlockAmendment><P2><Pnumber>1</Pnumber><P2para><Text>new 1</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|
        )

      Reader.instruction(d, "regulation-10-3", %{}, [@msa])
    end

    test "\"shall apply … as if\", \"applies … as if\", \"has effect as if\"" do
      assert modifying(
               "Section 97 of the Merchant Shipping Act 1995 shall apply in relation to a ship to which this Part of these Regulations applies as if, for subsection (1) there were substituted:"
             ) == []

      assert modifying(
               "Section 97 of the Merchant Shipping Act 1995 applies as if for subsection (1) there were substituted—"
             ) == []

      assert modifying(
               "Section 97 of the Merchant Shipping Act 1995 has effect as if for subsection (1) there were substituted—"
             ) == []
    end

    test "a plain substitution is still read" do
      assert modifying(
               "In section 97 of the Merchant Shipping Act 1995, for subsection (1) substitute—"
             ) != []
    end
  end

  test "an \"(i)\" under a parent's letter is its sub-paragraph: \"In paragraph (2)(e)— in paragraph (i)\" (SI 2006/771 on SI 1995/2644) (F4)" do
    appeals =
      Reader.law_ref("UK_uksi_1995_2644", "Statutory Nuisance (Appeals) Regulations", "reg")

    d =
      doc(
        "UK_uksi_2006_771",
        ~S|<P1 id="regulation-2"><P1para><P2 id="regulation-2-1"><P2para><Text>Regulation 2 (appeals under section 80(3) of the 1990 Act) of the Statutory Nuisance (Appeals) Regulations 1995 is amended as follows.</Text></P2para></P2><P2 id="regulation-2-2"><P2para><Text>In paragraph (2)(e)—</Text><P3 id="regulation-2-2-a"><P3para><Text>in paragraph (i), after “(f)” insert “, (fa)”;</Text></P3para></P3></P2para></P2></P1para></P1>|
      )

    ts = targets(Reader.instruction(d, "regulation-2-2-a", %{}, [appeals]))
    # (a rule lists every bracket combination; the deepest held is the change)
    assert "reg.2(2)(e)(i)" in ts
  end

  describe "a table's entry named by the provision it lists is words in the table's provision (F5)" do
    @epa Reader.law_ref("UK_ukpga_1990_43", "Environmental Protection Act", "s")

    test "\"In section 160A, after the entry relating to section 45AA(10) insert—\" (asp 2024/13 s.15(3))" do
      d =
        doc(
          "UK_asp_2024_13",
          ~S|<P1 id="section-15"><P1para><P2 id="section-15-1"><P2para><Text>The Environmental Protection Act 1990 is modified as follows.</Text></P2para></P2><P2 id="section-15-3"><P2para><Text>In section 160A, after the entry relating to section 45AA(10) insert—</Text><BlockAmendment><Para><Text>46ZC(1) any regulations under that subsection.</Text></Para></BlockAmendment></P2para></P2></P1para></P1>|
        )

      ts = targets(Reader.instruction(d, "section-15-3", %{}, [@epa]))
      assert ts != [] and Enum.all?(ts, &String.starts_with?(&1, "s.160A"))
    end

    test "\"in the second column of the entry for section 34CA, in paragraph (e) omit …\" (2023 c.28 Sch.3 para 1(a))" do
      d =
        doc(
          "UK_ukpga_2023_28",
          ~S|<P1 id="section-1"><P1para><P2 id="section-1-1"><P2para><Text>In section 160A(2) of the Environmental Protection Act 1990 (regulations and orders subject to affirmative procedure), in the Table—</Text><P3 id="section-1-1-a"><P3para><Text>in the second column of the entry for section 34CA, in paragraph (e) omit “or retained direct principal EU legislation”;</Text></P3para></P3></P2para></P2></P1para></P1>|
        )

      ts = targets(Reader.instruction(d, "section-1-1-a", %{}, [@epa]))
      assert "s.160A(2)" in ts and Enum.all?(ts, &String.starts_with?(&1, "s.160A"))
    end

    test "an entry in a Schedule's table gives no rule, never the section it lists; one in a section's table is words in that section (2026 c.20 on the Modern Slavery Act 2015)" do
      msa = Reader.law_ref("UK_ukpga_2015_30", "Modern Slavery Act", "s")

      d =
        doc(
          "UK_ukpga_2026_20",
          ~S|<P1 id="section-134"><P1para><P2 id="section-134-2"><P2para><Text>In Schedule 4 to the Modern Slavery Act 2015 (offences to which defence in section 45 does not apply), in paragraph 36D—</Text><P3 id="section-134-2-a"><P3para><Text>omit the entry for section 22;</Text></P3para></P3><P3 id="section-134-2-b"><P3para><Text>omit the entry for sections 319ZA to 319ZD;</Text></P3para></P3></P2para></P2><P2 id="section-134-3"><P2para><Text>In section 26 of the Modern Slavery Act 2015, in the table—</Text><P3 id="section-134-3-a"><P3para><Text>omit the entry for section 22;</Text></P3para></P3></P2para></P2></P1para></P1>|
        )

      assert Reader.instruction(d, "section-134-2-a", %{}, [msa]) == []
      assert Reader.instruction(d, "section-134-2-b", %{}, [msa]) == []
      assert targets(Reader.instruction(d, "section-134-3-a", %{}, [msa])) == ["s.26"]
    end
  end

  test "a repeals table's \"In section 48— (a) in subsection (4), the words …; (c) subsection (7).\" is its items, never the whole section (2005 c.16 Sch.5 Pt.4 on EPA 1990)" do
    alias SertantaiLegal.Scraper.Amendment.Reader.RepealTable

    d =
      Doc.new("UK_ukpga_2005_16", [
        ~S"""
        <Legislation><Primary><Schedules><Schedule id="schedule-5"><Tabular><table><tbody>
        <tr><th>Short title and chapter</th><th>Extent of repeal</th></tr>
        <tr><td>Environmental Protection Act 1990 (c. 43)</td><td><P><BlockText><Para><Text>Section 32.</Text></Para></BlockText></P><P><BlockText><Para><Text>In section 48—</Text></Para><OrderedList Type="alpha" Decoration="parens"><ListItem NumberOverride="a"><Para><Text>in subsection (4), the words “with a waste disposal contractor” and “for the contractor”;</Text></Para></ListItem><ListItem NumberOverride="b"><Para><Text>in subsection (6), the words “, subject to subsection (7) below,”;</Text></Para></ListItem><ListItem NumberOverride="c"><Para><Text>subsection (7).</Text></Para></ListItem></OrderedList></BlockText></P><P><BlockText><Para><Text>In section 51—</Text></Para><OrderedList Type="alpha" Decoration="parens"><ListItem NumberOverride="a"><Para><Text>in subsection (1), the words from “in either case” to the end;</Text></Para></ListItem><ListItem NumberOverride="b"><Para><Text>subsection (4)(b) to (d);</Text></Para></ListItem></OrderedList></BlockText></P><P><BlockText><Para><Text>In section 96(3)—</Text></Para><Para><Text>(a) in the words before paragraph (a), the words “163”; and</Text></Para><Para><Text>(b) paragraph (c) and the word “or” immediately preceding it.</Text></Para></BlockText></P></td></tr>
        </tbody></table></Tabular></Schedule></Schedules></Primary></Legislation>
        """
      ])

    epa = Reader.law_ref("UK_ukpga_1990_43", "Environmental Protection Act", "s")
    rules = RepealTable.repeal_table(d, "schedule-5", [epa])
    level = fn target -> for r <- rules, target in r.targets, uniq: true, do: r.level end

    assert level.("s.32") == [:provision]
    assert level.("s.48") == []
    assert level.("s.51") == []
    assert level.("s.48(4)") == [:words]
    assert level.("s.48(6)") == [:words]
    assert level.("s.48(7)") == [:provision]
    assert level.("s.51(1)") == [:words]
    # items carrying their own labels (2002 c.30 Sch.8 on 1984 c.27 s.96(3))
    assert :words in level.("s.96(3)")
    assert level.("s.96(3)(c)") == [:provision]
  end

  describe "levels found in the catalogue (Decision 2)" do
    @sepa Reader.law_ref(
            "UK_ssi_2018_219",
            "Environmental Authorisations (Scotland) Regulations",
            "reg"
          )
    @hw Reader.law_ref("UK_uksi_2005_1806", "Hazardous Waste (Wales) Regulations", "reg")
    @epa90 Reader.law_ref("UK_ukpga_1990_43", "Environmental Protection Act", "s")

    defp levels(amending, id, body, law) do
      d = doc(amending, body)
      for r <- Reader.instruction(d, id, %{}, [law]), uniq: true, do: {r.operation, r.level}
    end

    test "\"in the appropriate place insert— <definition>\" is words (WSI 2013/755)" do
      body =
        ~S|<P1 id="regulation-2"><P1para><P2 id="regulation-2-1"><P2para><Text>The Hazardous Waste (Wales) Regulations 2005 are amended as follows.</Text></P2para></P2><P2 id="regulation-2-2"><P2para><Text>In regulation 5(1), in the appropriate place insert—</Text><BlockAmendment><Para><Text>“the Body” means the Natural Resources Body for Wales;</Text></Para></BlockAmendment></P2para></P2></P1para></P1>|

      assert levels("UK_wsi_2013_755", "regulation-2-2", body, @hw) == [{:inserted, :words}]
    end

    test "quotes marked as inline amendments: \"omit <quote>,\", \"after <quote> insert <quote>.\" are words (SSI 2026/55)" do
      omit =
        ~S|<P1 id="regulation-3"><P1para><P2 id="regulation-3-1"><P2para><Text>The Environmental Authorisations (Scotland) Regulations 2018 are amended as follows.</Text></P2para></P2><P2 id="regulation-3-2"><P2para><Text>In regulation 63(6) (accelerated applications), omit <InlineAmendment>“, or cause offence to any human sense,”</InlineAmendment>,</Text></P2para></P2><P2 id="regulation-3-3"><P2para><Text>In regulation 63(6) (accelerated applications), after <InlineAmendment>“quality”</InlineAmendment> insert <InlineAmendment>“or offence”</InlineAmendment>.</Text></P2para></P2></P1para></P1>|

      assert levels("UK_ssi_2026_55", "regulation-3-2", omit, @sepa) == [{:repealed, :words}]
      assert levels("UK_ssi_2026_55", "regulation-3-3", omit, @sepa) == [{:inserted, :words}]
    end

    test "an inline quote beside a provision named stays whole: \"omit sub-paragraph (d) and the <quote> preceding it\"" do
      body =
        ~S|<P1 id="regulation-3"><P1para><P2 id="regulation-3-1"><P2para><Text>The Environmental Authorisations (Scotland) Regulations 2018 are amended as follows.</Text></P2para></P2><P2 id="regulation-3-2"><P2para><Text>In regulation 63(6), omit sub-paragraph (d) and the <InlineAmendment>“or”</InlineAmendment> preceding it.</Text></P2para></P2></P1para></P1>|

      assert levels("UK_ssi_2026_55", "regulation-3-2", body, @sepa) == [{:repealed, :provision}]
    end

    test "\"For the amount of £25 specified … in section 88(6) … there shall be substituted the amount of £50\" is words (SSI 2003/268)" do
      body =
        ~S|<P1 id="article-2"><P1para><Text>For the amount of £25 specified as the amount of the fixed penalty in section 88(6) of the Environmental Protection Act 1990 there shall be substituted the amount of £50.</Text></P1para></P1>|

      assert levels("UK_ssi_2003_268", "article-2", body, @epa90) == [{:substituted, :words}]
    end
  end

  describe "a quote numbered in its title, its own number empty" do
    test "\"After article 4 insert— 4A Policy making … (1) … (2)\" is article 4A's (asc 2026/4 s.4(2))" do
      nrw =
        Reader.law_ref(
          "UK_wsi_2012_1903",
          "Natural Resources Body for Wales (Establishment) Order",
          "reg",
          articles: true
        )

      d =
        doc(
          "UK_asc_2026_4",
          ~S|<P1 id="section-4"><P1para><P2 id="section-4-1"><P2para><Text>The Natural Resources Body for Wales (Establishment) Order 2012 is amended as follows.</Text></P2para></P2><P2 id="section-4-2"><P2para><Text>After article 4 insert—</Text><BlockAmendment><P1group><Title>4A Policy making: environmental principles</Title><P1><Pnumber PuncAfter=""/><P1para><P2><Pnumber>1</Pnumber><P2para><Text>The Body must—</Text><P3><Pnumber>a</Pnumber><P3para><Text>have regard</Text></P3para></P3></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text>In complying …</Text></P2para></P2></P1para></P1></P1group></BlockAmendment></P2para></P2></P1para></P1>|
        )

      ts = targets(Reader.instruction(d, "section-4-2", %{}, [nrw]))
      assert "reg.4A" in ts and "reg.4A(1)(a)" in ts
      refute "reg.1" in ts
    end

    test "\"After section 45B insert— 45C Separate collection … (1) … (2)\" is section 45C's (SSI 2012/148 reg.2(5))" do
      epa = Reader.law_ref("UK_ukpga_1990_43", "Environmental Protection Act", "s")

      d =
        doc(
          "UK_ssi_2012_148",
          ~S|<P1 id="regulation-2"><P1para><P2 id="regulation-2-1"><P2para><Text>The Environmental Protection Act 1990 is amended as follows.</Text></P2para></P2><P2 id="regulation-2-5"><P2para><Text>After section 45B insert—</Text><BlockAmendment><P2group><Title><Emphasis><Strong>45C Separate collection of dry recyclable waste</Strong></Emphasis></Title><P2><Pnumber>1</Pnumber><P2para><Text>This section applies …</Text></P2para></P2></P2group><P2><Pnumber>2</Pnumber><P2para><Text>An authority must …</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|
        )

      ts = targets(Reader.instruction(d, "regulation-2-5", %{}, [epa]))
      assert "s.45C" in ts and "s.45C(2)" in ts
      refute "s.1" in ts or "s.2" in ts
    end
  end
end
