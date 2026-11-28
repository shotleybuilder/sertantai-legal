defmodule SertantaiLegal.Scraper.Amendment.Reader.YieldFormsTest do
  @moduledoc """
  Amending provisions the reader read but gave no rule for (Amending-law
  reader: yield, 2026-11-27). Each case is the law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Doc}
  alias SertantaiLegal.Scraper.Amendment.Reader

  defp schedules(amending, schedules),
    do:
      Doc.new(amending, [
        ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
        ~s(<Legislation><Secondary><Schedules>#{schedules}</Schedules></Secondary></Legislation>)
      ])

  describe "a lead whose places another sub-paragraph lists" do
    @dpa Reader.law_ref("UK_ukpga_2018_12", "Data Protection Act", "s")

    # SI 2026/386 Sch.2 para.23
    @para23 ~S|<Schedule id="schedule-2"><ScheduleBody><P1 id="schedule-2-paragraph-23"><P1para><P2 id="schedule-2-paragraph-23-1"><P2para><Text>The Data Protection Act 2018 is amended as follows.</Text></P2para></P2><P2 id="schedule-2-paragraph-23-2"><P2para><Text>In each of the provisions listed in sub-paragraph (3)—</Text><P3 id="schedule-2-paragraph-23-2-a"><P3para><Text>for “Commissioner”, in each place it occurs including in the term “Information Commissioner”, substitute <InlineAmendment>“Commission”</InlineAmendment>;</Text></P3para></P3><P3 id="schedule-2-paragraph-23-2-b"><P3para><Text>for “Commissioner’s”, in each place it occurs, substitute <InlineAmendment>“Commission’s”</InlineAmendment>.</Text></P3para></P3></P2para></P2><P2 id="schedule-2-paragraph-23-3"><P2para><Text>The provisions are—</Text><P3 id="schedule-2-paragraph-23-3-a"><P3para><Text>section 1(6);</Text></P3para></P3><P3 id="schedule-2-paragraph-23-3-b"><P3para><Text>section 17(1)(a), (2) and (3);</Text></P3para></P3><P3 id="schedule-2-paragraph-23-3-c"><P3para><Text>section 26(2)(c)(i), (e)(i) and (ii), (g)(i) and (h)(i);</Text></P3para></P3><P3 id="schedule-2-paragraph-23-3-e"><P3para><Text>section 28(5);</Text></P3para></P3></P2para></P2></P1para></P1></ScheduleBody></Schedule>|

    test "\"In each of the provisions listed in sub-paragraph (3)—\" places each item at the provisions (3) lists (SI 2026/386 Sch.2 para.23(2)(a))" do
      rules =
        Reader.read(
          schedules("UK_uksi_2026_386", @para23),
          "schedule-2-paragraph-23-2-a",
          %{},
          [@dpa]
        )

      targets = Enum.flat_map(rules, & &1.targets)
      assert rules != []
      assert Enum.all?(rules, &(&1.amends == "UK_ukpga_2018_12"))

      for t <- ~w[s.1(6) s.17(1)(a) s.17(2) s.17(3) s.26(2)(c)(i) s.28(5)],
          do: assert(t in targets, "#{t} not in #{inspect(targets)}")

      # "sub-paragraph (3)" points to the list and names no place
      for t <- ~w[s.1(3) s.17(3)(a) s.26(3) s.28(3)], do: refute(t in targets)
    end

    @fpa Reader.law_ref("UK_ukpga_1971_40", "Fire Precautions Act", "s")

    # SSI 2005/383 Sch.1 para.3: the instruction itself points to the list
    @para3 ~S|<Schedule id="schedule-1"><ScheduleBody><P1 id="schedule-1-paragraph-3"><P1para><P2 id="schedule-1-paragraph-3-1"><P2para><Text>The Fire Precautions Act 1971 is amended as follows.</Text></P2para></P2><P2 id="schedule-1-paragraph-3-2"><P2para><Text>In the provisions mentioned in sub paragraph (3), for “fire authority” (in each place) substitute <InlineAmendment>“appropriate authority”</InlineAmendment>.</Text></P2para></P2><P2 id="schedule-1-paragraph-3-3"><P2para><Text>The provisions are–</Text><P3 id="schedule-1-paragraph-3-3-a"><P3para><Text>in section 1 (use of premises requiring fire certificate), subsections (1) and (3A);</Text></P3para></P3><P3 id="schedule-1-paragraph-3-3-b"><P3para><Text>in section 3 (power of fire authority to make fire certificates compulsory), subsections (3) to (5) and (7);</Text></P3para></P3><P3 id="schedule-1-paragraph-3-3-c"><P3para><Text>in section 4 (rights of appeal against and coming into force of section 3 notices), subsection (4);</Text></P3para></P3></P2para></P2></P1para></P1></ScheduleBody></Schedule>|

    test "\"In the provisions mentioned in sub paragraph (3), for … substitute …\" (SSI 2005/383 Sch.1 para.3(2))" do
      rules =
        Reader.read(
          schedules("UK_ssi_2005_383", @para3),
          "schedule-1-paragraph-3-2",
          %{},
          [@fpa]
        )

      targets = Enum.flat_map(rules, & &1.targets)

      for t <- ~w[s.1(1) s.1(3A) s.3(3) s.3(4) s.3(5) s.3(7) s.4(4)],
          do: assert(t in targets, "#{t} not in #{inspect(targets)}")

      for t <- ~w[s.1(3) s.1(4)], do: refute(t in targets)
    end
  end

  describe "a defined term mentioned again later" do
    # 2025 c.18 s.66 defines "the 2018 Act"; s.142(1)(a) later names "section
    # 66 (meaning of “the 2018 Act” …)", which had replaced the definition
    # with a term meaning no law, so 262 changes to the Data Protection Act
    # 2018 had no law
    @s66 ~S|<Legislation><Primary><Body><P1 id="section-66"><P1para><Text>In this Chapter—</Text><UnorderedList Class="Definition" Decoration="none"><ListItem><Para><Text>“<Term id="term-the-2018-act">the 2018 Act</Term>” means the Data Protection Act 2018;</Text></Para></ListItem></UnorderedList></P1para></P1><P1 id="section-142"><P1para><Text>The following come into force on the day on which this Act is passed—</Text><P3 id="section-142-1-a"><P3para><Text>section 66 (meaning of “<Term id="term-the-2018-act-2">the 2018 Act</Term>” and “the UK GDPR”);</Text></P3para></P3></P1para></P1></Body></Primary></Legislation>|

    test "keeps the definition naming a law (2025 c.18 s.66)" do
      assert %{"the 2018 act" => %{title: "Data Protection Act 2018"}} =
               DefinedTerms.of(Doc.new("UK_ukpga_2025_18", [@s66]))
    end
  end

  describe "a term defined with \"is\"" do
    # asp 2006/17 s.57(1): every amendment of the Town and Country Planning
    # (Scotland) Act 1997 says "the principal Act" (141 changes, no law)
    @s57 ~S|<Legislation><Primary><Body><P1 id="section-57"><P1para><P2 id="section-57-1"><P2para><Text>The “principal Act” is the Town and Country Planning (Scotland) Act 1997 (c. 8).</Text></P2para></P2></P1para></P1></Body></Primary></Legislation>|

    test "The “principal Act” is the … Act 1997 (asp 2006/17 s.57(1))" do
      assert %{"principal act" => %{title: "Town and Country Planning (Scotland) Act 1997"}} =
               DefinedTerms.of(Doc.new("UK_asp_2006_17", [@s57]))
    end
  end

  describe "an item that is only its places, under a lead with the verb" do
    @las Reader.law_ref(
           "UK_uksi_2004_1490",
           "Landfill Allowances Scheme (Wales) Regulations",
           "reg"
         )

    # WSI 2012/65 reg.7
    @reg7 ~S|<Legislation><Secondary><Body><P1 id="regulation-3"><P1para><Text>The Landfill Allowances Scheme (Wales) Regulations 2004 are amended in accordance with regulations 4 to 9.</Text></P1para></P1><P1 id="regulation-7"><P1para><Text>In the following places for “municipal waste” substitute <InlineAmendment>“collected municipal waste”</InlineAmendment>—</Text><P3 id="regulation-7-a"><P3para><Text>regulation 6(1)(b) and (c);</Text></P3para></P3><P3 id="regulation-7-c"><P3para><Text>regulation 14(2)(ii).</Text></P3para></P3></P1para></P1></Body></Secondary></Legislation>|

    test "\"In the following places for … substitute …— (a) regulation 6(1)(b) and (c);\" (WSI 2012/65 reg.7(a))" do
      d = Doc.new("UK_wsi_2012_65", [@reg7])

      assert [%{operation: :substituted, level: :words, targets: a}] =
               Reader.read(d, "regulation-7-a", %{}, [@las])

      assert "reg.6(1)(b)" in a and "reg.6(1)(c)" in a
      assert [%{targets: c}] = Reader.read(d, "regulation-7-c", %{}, [@las])
      assert "reg.14(2)(ii)" in c
    end
  end

  describe "a title with a colon in its bracket" do
    @msw Reader.law_ref(
           "UK_uksi_2003_3049",
           "Merchant Shipping (Working Time: Inland Waterways) Regulations",
           "reg"
         )

    # SI 2017/1149 regs 2 and 7: the title had been cut at its colon
    @regs ~S|<Legislation><Secondary><Body><P1 id="regulation-2"><P1para><Text>The Merchant Shipping (Working Time: Inland Waterways) Regulations 2003 are amended as follows.</Text></P1para></P1><P1 id="regulation-7"><P1para><P2 id="regulation-7-1"><P2para><Text>Omit regulation 5 (general).</Text></P2para></P2></P1para></P1></Body></Secondary></Legislation>|

    test "\"The Merchant Shipping (Working Time: Inland Waterways) Regulations 2003 are amended as follows.\" names the law (SI 2017/1149 reg.7(1))" do
      assert [%{operation: :repealed, targets: ["reg.5"]}] =
               Reader.read(Doc.new("UK_uksi_2017_1149", [@regs]), "regulation-7-1", %{}, [@msw])
    end
  end

  describe "an item that is only a quote, or only brackets, under its lead" do
    @epa Reader.law_ref("UK_ukpga_1990_43", "Environmental Protection Act", "s")

    # SI 2024/365 reg.2(b)
    @reg2 ~S|<Legislation><Secondary><Body><P1 id="regulation-2"><P1para><Text>The Environmental Protection Act 1990 is amended as follows—</Text><P3 id="regulation-2-b"><P3para><Text>in section 73A (use of fixed penalty receipts)—</Text><P4 id="regulation-2-b-iii"><P4para><Text>in subsection (2), omit—</Text><P5 id="regulation-2-b-iii-aa"><P5para><Text>“33ZA,”;</Text></P5para></P5><P5 id="regulation-2-b-iii-bb"><P5para><Text>“34ZA,”;</Text></P5para></P5></P4para></P4><P4 id="regulation-2-b-iv"><P4para><Text>in each of the following subsections, for “appropriate person” substitute <InlineAmendment>“Welsh Ministers”</InlineAmendment>—</Text><P5 id="regulation-2-b-iv-aa"><P5para><Text>(2)(b);</Text></P5para></P5><P5 id="regulation-2-b-iv-bb"><P5para><Text>(4);</Text></P5para></P5></P4para></P4></P3para></P3></P1para></P1></Body></Secondary></Legislation>|

    test "\"in subsection (2), omit— (aa) “33ZA,”;\" (SI 2024/365 reg.2(b)(iii)(aa))" do
      assert [%{operation: :repealed, level: :words, targets: ["s.73A(2)"]}] =
               Reader.read(Doc.new("UK_uksi_2024_365", [@reg2]), "regulation-2-b-iii-aa", %{}, [
                 @epa
               ])
    end

    test "\"in each of the following subsections, for … substitute …— (aa) (2)(b);\" (SI 2024/365 reg.2(b)(iv)(aa))" do
      assert [%{operation: :substituted, level: :words, targets: targets}] =
               Reader.read(Doc.new("UK_uksi_2024_365", [@reg2]), "regulation-2-b-iv-aa", %{}, [
                 @epa
               ])

      assert "s.73A(2)(b)" in targets
    end
  end

  describe "amendments tables" do
    @ccl Reader.law_ref("UK_uksi_2001_838", "Climate Change Levy (General) Regulations", "reg")

    # SI 2007/2903 Sch.1: "Item | Regulation, etc | Extent of amendment",
    # each place a bare number
    @sch1 ~S|<Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>Amendments to the Climate Change Levy (General) Regulations 2001 (<Citation URI="http://www.legislation.gov.uk/id/uksi/2001/838" id="c00001" Class="UnitedKingdomStatutoryInstrument" Year="2001" Number="0838">S.I. 2001/838</Citation>)</Title></TitleBlock><ScheduleBody><Tabular><table xmlns="http://www.w3.org/1999/xhtml" cols="3"><thead><tr><th>Item</th><th>Regulation, etc</th><th>Extent of amendment</th></tr></thead><tbody><tr><td><Strong xmlns="http://www.legislation.gov.uk/namespaces/legislation">1.</Strong></td><td>2(1)</td><td>Omit “, “half-rate part”” and “a half-rate supply or”.</td></tr><tr><td><Strong xmlns="http://www.legislation.gov.uk/namespaces/legislation">2.</Strong></td><td>5(1)(b)</td><td>For “, in Schedule 1, paragraphs 5(9G) and 8(1)(b)” substitute “Schedule 1 paragraph 8(1)(b)”.</td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|

    test "\"Item \| Regulation, etc \| Extent of amendment\" under a title naming the law (SI 2007/2903 Sch.1)" do
      rules = Reader.read(schedules("UK_uksi_2007_2903", @sch1), "schedule-1", %{}, [@ccl])
      got = Enum.map(rules, &{&1.operation, &1.targets})

      assert {:repealed, ["reg.2(1)"]} in got
      # (reg.5(1), reg.5(b) beside it are candidates, kept only where held)
      assert Enum.any?(got, fn {op, t} -> op == :substituted and "reg.5(1)(b)" in t end)
      assert length(rules) == 2
    end

    @msr Reader.law_ref(
           "UK_uksi_1995_1802",
           "Merchant Shipping and Fishing Vessels (Medical Stores) Regulations",
           "reg"
         )
    @msc Reader.law_ref(
           "UK_uksi_1997_529",
           "Merchant Shipping (Minimum Standards of Safety Communications) Regulations",
           "reg"
         )

    # SI 2026/260 Sch.1: "Column 1 | Column 2", each row a law and its amendments
    @sch1b ~S|<Schedule id="schedule-1"><Number>Schedule 1</Number><TitleBlock><Title>Amendments or revocations</Title></TitleBlock><ScheduleBody><P><Text>The statutory instruments set out under column 1 of the table below are amended or revoked to the extent specified under column 2 of that table.</Text></P><Tabular><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Column 1</th><th>Column 2</th></tr></thead><tbody><tr><td>The Merchant Shipping and Fishing Vessels (Medical Stores) Regulations 1995</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In regulation 1(3) (citation, commencement, revocation and interpretation), omit the definition of “Government ships”.</Text></Para><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In regulation 3 (application), omit “and Government ships,”.</Text></Para></td></tr><tr><td>The Merchant Shipping (Minimum Standards of Safety Communications) Regulations 1997</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In regulation 3(1) (application), omit sub-paragraph (ii).</Text></Para></td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|

    test "\"Column 1 \| Column 2\" whose first column names the laws (SI 2026/260 Sch.1)" do
      rules = Reader.read(schedules("UK_uksi_2026_260", @sch1b), "schedule-1", %{}, [@msr, @msc])
      got = Enum.map(rules, &{&1.amends, &1.targets})

      assert {"UK_uksi_1995_1802", ["reg.1(3)"]} in got
      assert {"UK_uksi_1995_1802", ["reg.3"]} in got
      assert Enum.any?(got, fn {law, t} -> law == "UK_uksi_1997_529" and "reg.3(1)(ii)" in t end)
    end
  end

  describe "a lead whose places a Schedule of the amending law lists" do
    @weee Reader.law_ref(
            "UK_uksi_2013_3113",
            "Waste Electrical and Electronic Equipment Regulations",
            "reg"
          )

    # SI 2014/1771 reg.3 and Schs.1 and 2
    @reg3 ~S|<Legislation><Secondary><Body><P1 id="regulation-3"><P1para><P2 id="regulation-3-1"><P2para><Text>The Waste Electrical and Electronic Equipment Regulations 2013 are amended as follows.</Text></P2para></P2><P2 id="regulation-3-2"><P2para><Text>In the regulations, schedule and part of a schedule set out in Schedule 1 to these Regulations for every use of the word ‘will’ substitute the word ‘must’.</Text></P2para></P2><P2 id="regulation-3-3"><P2para><Text>In the regulations set out in schedule 2 to these Regulations, substitute the word ‘will’ for ‘must;’ as set out in column 3 of that schedule.</Text></P2para></P2></P1para></P1></Body></Secondary></Legislation>|
    @schs ~S|<Legislation><Secondary><Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>Provisions in which the word ‘must’ replaces all use of the word ‘will’</Title></TitleBlock><ScheduleBody><Part id="schedule-1-part-1"><Number>PART 1</Number><Title>Regulations</Title><P1 id="schedule-1-paragraph-1"><Pnumber>1</Pnumber><P1para><Text>Regulation 13 (producers supplying EEE by means of distance communication)</Text></P1para></P1><P1 id="schedule-1-paragraph-2"><Pnumber>2</Pnumber><P1para><Text>Regulation 19 (declaration of Compliance)</Text></P1para></P1></Part></ScheduleBody></Schedule><Schedule id="schedule-2"><Number>SCHEDULE 2</Number><TitleBlock><Title>Provisions in which specific uses of the word ‘will’ are substituted by the word ‘must’ as set out in this schedule</Title></TitleBlock><ScheduleBody><Part id="schedule-2-part-1"><Number>PART 1</Number><Title>Regulations</Title><Tabular><table xmlns="http://www.w3.org/1999/xhtml" cols="3"><thead><tr><th>(1)</th><th>(2)</th><th>(3)</th></tr></thead><tbody><tr><td>Regulation</td><td>Provision</td><td>Use of the word ‘will’ to be substituted for ‘must’</td></tr><tr><td>11</td><td>(7)</td><td>The first time that it appears</td></tr><tr><td/><td>(8)</td><td>The third time that it appears</td></tr><tr><td/><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>(9)</Text></Para><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>(10)</Text></Para></td><td>Both times</td></tr><tr><td>14</td><td>(1)</td><td>The only time that it appears</td></tr></tbody></table></Tabular></Part></ScheduleBody></Schedule></Schedules></Secondary></Legislation>|

    test "\"In the regulations … set out in Schedule 1 to these Regulations …\" (SI 2014/1771 reg.3(2))" do
      d = Doc.new("UK_uksi_2014_1771", [@reg3, @schs])
      targets = d |> Reader.read("regulation-3-2", %{}, [@weee]) |> Enum.flat_map(& &1.targets)

      assert "reg.13" in targets and "reg.19" in targets
    end

    test "\"In the regulations set out in schedule 2 …\", its \"Regulation \\| Provision\" table (SI 2014/1771 reg.3(3))" do
      d = Doc.new("UK_uksi_2014_1771", [@reg3, @schs])
      rules = Reader.read(d, "regulation-3-3", %{}, [@weee])
      targets = Enum.flat_map(rules, & &1.targets)

      for t <- ~w[reg.11(7) reg.11(8) reg.11(9) reg.11(10) reg.14(1)],
          do: assert(t in targets, "#{t} not in #{inspect(targets)}")

      assert Enum.all?(rules, &(&1.operation == :substituted and &1.level == :words))
    end
  end

  describe "an EU Decision named by its date and words, not its number" do
    alias SertantaiLegal.Scraper.Amendment.Reader.LawNamed

    @crates Reader.law_ref(
              "UK_eudn_2009_292",
              "Commission Decision of 24 March 2009 establishing the conditions for a derogation for plastic crates and plastic pallets in relation to the heavy metal concentration levels established in Directive 94/62/EC of the European Parliament and of the Council on packaging and packaging waste (notified under document number C(2009) 1959) (Text with EEA relevance) (2009/292/EC)",
              "art"
            )
    @landfill Reader.law_ref(
                "UK_eudn_2003_33",
                "Council Decision of 19 December 2002 establishing criteria and procedures for the acceptance of waste at landfills pursuant to Article 16 of and Annex II to Directive 1999/31/EC (2003/33/EC)",
                "art"
              )

    # SI 2025/82 Sch.15 para.81
    @sch15 ~S|<Legislation><Secondary><Schedules><Schedule id="schedule-15"><Number>Schedule 15</Number><ScheduleBody><P1 id="schedule-15-paragraph-81"><Pnumber>81</Pnumber><P1para><Text>In Article 1A(6)(b) of Commission Decision of 24 March 2009 establishing the conditions for a derogation for plastic crates and plastic pallets in relation to the heavy metal concentration levels established in Directive 94/62/EC of the European Parliament and of the Council on packaging and packaging waste for “retained direct EU” substitute “assimilated direct”.</Text></P1para></P1></ScheduleBody></Schedule></Schedules></Secondary></Legislation>|

    test "\"In Article 1A(6)(b) of Commission Decision of 24 March 2009 establishing …\" (SI 2025/82 Sch.15 para.81)" do
      rules =
        Reader.read(schedules("UK_uksi_2025_82", @sch15), "schedule-15-paragraph-81", %{}, [
          @crates,
          @landfill
        ])

      assert [%{amends: "UK_eudn_2009_292", operation: :substituted, targets: targets}] = rules
      assert "art.Article 1A(6)(b)" in targets
    end

    test "\"Council Decision of 19 December 2002 … is amended as follows\" names it, its Annex II written 2 (SI 2025/82 Sch.15 para.63(1))" do
      text =
        "Council Decision of 19 December 2002 establishing criteria and procedures for the acceptance of waste at landfills pursuant to Article 16 of and Annex 2 to Directive 1999/31/EC is amended as follows."

      assert Enum.any?(LawNamed.named([text], %{}), &LawNamed.law_named?(&1, @landfill))
    end

    test "a Decision of the same date with other words is not named" do
      other = %{
        @crates
        | law_name: "UK_eudn_2009_293",
          title: "Commission Decision of 24 March 2009 on the allocation of quotas (2009/293/EC)",
          number: "293"
      }

      assert [] =
               Reader.read(
                 schedules("UK_uksi_2025_82", @sch15),
                 "schedule-15-paragraph-81",
                 %{},
                 [other]
               )
    end
  end

  describe "a list whose every item names its own law" do
    @cargo Reader.law_ref(
             "UK_uksi_1997_1509",
             "Merchant Shipping (Cargo Ship Construction) Regulations",
             "reg"
           )
    @small Reader.law_ref(
             "UK_uksi_1998_1011",
             "Merchant Shipping (Fire Protection: Small Ships) Regulations",
             "reg"
           )
    @radio Reader.law_ref(
             "UK_uksi_1998_2070",
             "Merchant Shipping (Radio Installations) Regulations",
             "reg"
           )
    @lsa Reader.law_ref(
           "UK_uksi_1999_2721",
           "Merchant Shipping (Life-Saving Appliances for Ships Other than Ships of Classes III to VI(A)) Regulations",
           "reg"
         )

    # SI 2018/1221 reg.3
    @reg3 ~S|<Legislation><Secondary><Body><P1 id="regulation-3"><P1para><P2 id="regulation-3-1"><P2para><Text>In each of the regulations specified in paragraph (2), omit the definition of “EEA Agreement” and for the definition of “EEA State” substitute—</Text><BlockAmendment><P><Text>“EEA State” has the meaning given by Schedule 1 to the Interpretation Act 1978.</Text></P></BlockAmendment><Text>.</Text></P2para></P2><P2 id="regulation-3-2"><P2para><Text>The regulations specified for the purpose of paragraph (1) are—</Text><P3 id="regulation-3-2-a"><P3para><Text>regulation 2(1) of the Merchant Shipping (Cargo Ship Construction) Regulations 1997,</Text></P3para></P3><P3 id="regulation-3-2-b"><P3para><Text>regulation 1(2) of the Merchant Shipping (Fire Protection: Small Ships) Regulations 1998,</Text></P3para></P3><P3 id="regulation-3-2-c"><P3para><Text>. . . . . . . .</Text></P3para></P3><P3 id="regulation-3-2-d"><P3para><Text>regulation 2 of the Merchant Shipping (Radio Installations) Regulations 1998,</Text></P3para></P3><P3 id="regulation-3-2-g"><P3para><Text>regulation 2(2) of the Merchant Shipping (Life-Saving Appliances for Ships Other than Ships of Classes III to VI(A)) Regulations 1999 ( S.I. 1999/2721 ) (interpretation), and</Text></P3para></P3></P2para></P2></P1para></P1></Body></Secondary></Legislation>|

    test "\"In each of the regulations specified in paragraph (2), omit …\", each item a law's (SI 2018/1221 reg.3(1))" do
      rules =
        Reader.read(Doc.new("UK_uksi_2018_1221", [@reg3]), "regulation-3-1", %{}, [
          @cargo,
          @small,
          @radio,
          @lsa
        ])

      got = rules |> Enum.map(&{&1.amends, &1.operation, &1.targets}) |> Enum.uniq()

      for {law, place} <- [
            {"UK_uksi_1997_1509", "reg.2(1)"},
            {"UK_uksi_1998_1011", "reg.1(2)"},
            {"UK_uksi_1998_2070", "reg.2"},
            {"UK_uksi_1999_2721", "reg.2(2)"}
          ],
          op <- [:repealed, :substituted],
          do: assert({law, op, [place]} in got, "#{law} #{op} #{place} not in #{inspect(got)}")
    end
  end

  describe "a revocations table of instruments" do
    @special Reader.law_ref("UK_uksi_1996_972", "Special Waste Regulations", "reg")
    @batteries Reader.law_ref("UK_ssi_2009_247", "Waste Batteries (Scotland) Regulations", "reg")
    @extractive Reader.law_ref(
                  "UK_ssi_2010_60",
                  "Management of Extractive Waste (Scotland) Regulations",
                  "reg"
                )

    # SSI 2025/165 Sch.21 para.2
    @sch21 ~S|<Legislation><Secondary><Schedules><Schedule id="schedule-21"><Number>SCHEDULE 21</Number><TitleBlock><Title>Revocations</Title></TitleBlock><ScheduleBody><P1 id="schedule-21-paragraph-2"><Pnumber>2</Pnumber><P1para><Text>The enactments listed in column 1 of the Table are revoked to the extent specified in column 3.</Text><Tabular><table xmlns="http://www.w3.org/1999/xhtml" cols="3"><thead><tr><th>Legislation</th><th>Reference</th><th>Extent of Revocation</th></tr></thead><tbody><tr><td>Special Waste Regulations 1996</td><td>S.I. 1996/972</td><td>Regulations 15(6) and (6A), 17, 17A, 20, 20A and 22.</td></tr><tr><td>Waste Batteries (Scotland) Regulations 2009</td><td>S.S.I. 2009/247</td><td>Regulations 5 to 9.</td></tr><tr><td>Management of Extractive Waste (Scotland) Regulations 2010</td><td>S.S.I. 2010/60</td><td>Regulation 3(2) and (4).</td></tr></tbody></table></Tabular></P1para></P1></ScheduleBody></Schedule></Schedules></Secondary></Legislation>|

    test "\"Legislation \\| Reference \\| Extent of Revocation\" naming instruments (SSI 2025/165 Sch.21 para.2)" do
      rules =
        Reader.read(schedules("UK_ssi_2025_165", @sch21), "schedule-21-paragraph-2", %{}, [
          @special,
          @batteries,
          @extractive
        ])

      got = for r <- rules, t <- r.targets, do: {r.amends, r.operation, t}

      for {law, t} <- [
            {"UK_uksi_1996_972", "reg.15(6)"},
            {"UK_uksi_1996_972", "reg.15(6A)"},
            {"UK_uksi_1996_972", "reg.17A"},
            {"UK_uksi_1996_972", "reg.22"},
            {"UK_ssi_2009_247", "reg.5..reg.9"},
            {"UK_ssi_2010_60", "reg.3(2)"},
            {"UK_ssi_2010_60", "reg.3(4)"}
          ],
          do: assert({law, :repealed, t} in got, "#{law} #{t} not in #{inspect(got)}")

      refute Enum.any?(got, fn {_, _, t} -> String.starts_with?(t, "s.") end)
    end

    @tips Reader.law_ref(
            "UK_uksi_1974_2013",
            "Mines and Quarries Acts 1954 to 1971 (Repeals and Modifications) Regulations",
            "reg"
          )

    # SI 2014/3248 Sch.4 Pt.1
    @sch4 ~S|<Legislation><Secondary><Schedules><Schedule id="schedule-4"><Number>SCHEDULE 4</Number><TitleBlock><Title>Revocations</Title></TitleBlock><ScheduleBody><Part id="schedule-4-part-1"><Number>PART 1</Number><Tabular><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Title</th><th>Extent of revocation</th></tr></thead><tbody><tr><td>The Mines and Quarries Acts 1954 to 1971 (Repeals and Modifications) Regulations 1974</td><td>Regulations 2(1)(a), (2) and (3), 3, 4 and 7, Schedule 1 and paragraphs 1, 2, 4 to 11, 12(b), 16 and 19 to 23 of Schedule 2</td></tr></tbody></table></Tabular></Part></ScheduleBody></Schedule></Schedules></Secondary></Legislation>|

    test "a row of regulations then a Schedule's paragraphs (SI 2014/3248 Sch.4 Pt.1)" do
      rules =
        Reader.read(schedules("UK_uksi_2014_3248", @sch4), "schedule-4-part-1", %{}, [@tips])

      got = for r <- rules, t <- r.targets, do: t

      for t <- ~w[reg.2(1)(a) reg.2(2) reg.2(3) reg.3 reg.4 reg.7],
          do: assert(t in got, "#{t} not in #{inspect(got)}")

      refute "reg.2(1)(b)" in got
      refute "reg.2(2)(b)" in got
    end

    @rows [
      {"Regulations 9(7)(b), 13 and 14 and the entry relating to the Shipbuilding Regulations 1971 in Schedule 3",
       ~w[reg.9(7)(b) reg.13 reg.14]},
      {"Regulations 12 and 22(2) and (4), and Schedule 1", ~w[reg.12 reg.22(2) reg.22(4)]},
      {"Regulation 12(3); regulation 18(5), (6) and (8); and regulation 24",
       ~w[reg.12(3) reg.18(5) reg.18(6) reg.18(8) reg.24]},
      # a bare bracket a sibling at its own level (2007 c.11 Sch.27, SSI 2025/165)
      {"Regulation 109(3)(b), (4)(b), (7)(b) and (9)(b)",
       ~w[reg.109(3)(b) reg.109(4)(b) reg.109(7)(b) reg.109(9)(b)]},
      {"Regulation 29(9)(f), (g) and (h)", ~w[reg.29(9)(f) reg.29(9)(g) reg.29(9)(h)]},
      {"Regulation 12(3)(b)(i), (4) and (5)", ~w[reg.12(3)(b)(i) reg.12(4) reg.12(5)]}
    ]

    test "a row listing several regulations (NISR 2015/223, SI 2024/636, NISR 2016/406)" do
      for {extent, want} <- @rows do
        xml =
          String.replace(
            @sch4,
            "Regulations 2(1)(a), (2) and (3), 3, 4 and 7, Schedule 1 and paragraphs 1, 2, 4 to 11, 12(b), 16 and 19 to 23 of Schedule 2",
            extent
          )

        rules =
          Reader.read(schedules("UK_uksi_2014_3248", xml), "schedule-4-part-1", %{}, [@tips])

        got = for r <- rules, t <- r.targets, do: t
        for t <- want, do: assert(t in got, "#{extent}: #{t} not in #{inspect(got)}")
        base = &(&1 |> String.split("(") |> hd())

        assert MapSet.subset?(MapSet.new(got, base), MapSet.new(want, base)),
               "#{extent}: #{inspect(got)}"

        # (no rule wider than a listed place: "reg.109(3)" whole is not "reg.109(3)(b)")
        rules_targets = for r <- rules, do: r.targets

        for ts <- rules_targets,
            do:
              assert(
                Enum.any?(ts, &(&1 in want)),
                "#{extent}: a rule with none listed: #{inspect(ts)}"
              )
      end
    end
  end

  describe "a defined term for a Northern Ireland Order" do
    alias SertantaiLegal.Scraper.AmendingLaw.DefinedTerms

    # NIA 2011/5 s.13
    @s13 ~S|<Legislation><Primary><Body><P1 id="section-13"><P1para><Text>In this Act—</Text><UnorderedList Class="Definition"><ListItem><Para><Text>“<Term id="term-the-1997-order">the 1997 Order</Term>” means the Waste and Contaminated Land (Northern Ireland) Order 1997 (NI 19);</Text></Para></ListItem></UnorderedList></P1para></P1></Body></Primary></Legislation>|

    test "\"“the 1997 Order” means the … Order 1997 (NI 19);\" (NIA 2011/5 s.13)" do
      assert %{
               "the 1997 order" => %{
                 title: "Waste and Contaminated Land (Northern Ireland) Order 1997"
               }
             } =
               DefinedTerms.of(Doc.new("UK_nia_2011_5", [@s13]))
    end
  end

  describe "a list of other laws' provisions, each with its citation" do
    @foia Reader.law_ref("UK_ukpga_2000_36", "Freedom of Information Act", "s")
    @eir Reader.law_ref("UK_uksi_2004_3391", "Environmental Information Regulations", "reg")
    @eirs Reader.law_ref(
            "UK_ssi_2004_520",
            "Environmental Information (Scotland) Regulations",
            "reg"
          )

    # 2025 c.18 s.88(11), (12)
    @s88 ~S|<Legislation><Primary><Body><P1 id="section-88"><P1para><P2 id="section-88-11"><P2para><Text>In the provisions listed in subsection (12), for “subsection (4) of that section” substitute <InlineAmendment>“section 45(4) or 78A of that Act”</InlineAmendment>.</Text></P2para></P2><P2 id="section-88-12"><P2para><Text>The provisions are—</Text><P3 id="section-88-12-a"><P3para><Text>section 40(4A)(b) and (5B)(d) of the Freedom of Information Act 2000 (personal data which is exempt information);</Text></P3para></P3><P3 id="section-88-12-c"><P3para><Text>regulation 13(3A)(b) and (5B)(d) of the Environmental Information Regulations 2004 (<Citation URI="http://www.legislation.gov.uk/id/uksi/2004/3391" id="c1">S.I. 2004/3391</Citation>) (restriction on disclosure of personal data);</Text></P3para></P3><P3 id="section-88-12-d"><P3para><Text>regulation 11(4A)(b) of the Environmental Information (Scotland) Regulations 2004 (<Citation URI="http://www.legislation.gov.uk/id/ssi/2004/520" id="c2">S.S.I. 2004/520</Citation>) (restriction on disclosure of personal data).</Text></P3para></P3></P2para></P2></P1para></P1></Body></Primary></Legislation>|

    test "\"In the provisions listed in subsection (12), for … substitute …\" (2025 c.18 s.88(11))" do
      rules =
        Reader.read(Doc.new("UK_ukpga_2025_18", [@s88]), "section-88-11", %{}, [
          @foia,
          @eir,
          @eirs
        ])

      got = for r <- rules, t <- r.targets, do: {r.amends, t}

      for want <- [
            {"UK_ukpga_2000_36", "s.40(4A)(b)"},
            {"UK_ukpga_2000_36", "s.40(5B)(d)"},
            {"UK_uksi_2004_3391", "reg.13(3A)(b)"},
            {"UK_uksi_2004_3391", "reg.13(5B)(d)"},
            {"UK_ssi_2004_520", "reg.11(4A)(b)"}
          ],
          do: assert(want in got, "#{inspect(want)} not in #{inspect(got)}")
    end
  end

  describe "quoted definitions under a lead's verb" do
    @epsr Reader.law_ref(
            "UK_nisr_2017_90",
            "Equipment and Protective Systems Intended for Use in Potentially Explosive Atmospheres Regulations (Northern Ireland)",
            "reg"
          )

    # SI 2023/861 reg.3(1)(d)
    @reg3 ~S|<Legislation><Secondary><Body><P1 id="regulation-3"><P1para><Text>The Equipment and Protective Systems Intended for Use in Potentially Explosive Atmospheres Regulations (Northern Ireland) 2017 are amended as follows.</Text><P2 id="regulation-3-1"><P2para><Text>In regulation 2(1)—</Text><P3 id="regulation-3-1-d"><P3para><Text>in the following definitions, for “EU” substitute <InlineAmendment>“relevant”</InlineAmendment>—</Text><P4 id="regulation-3-1-d-i"><P4para><Text>“make available on the market”;</Text></P4para></P4><P4 id="regulation-3-1-d-ii"><P4para><Text>“place on the market”;</Text></P4para></P4></P3para></P3></P2para></P2></P1para></P1></Body></Secondary></Legislation>|

    test "\"in the following definitions, for “EU” substitute “relevant”— (i) “make available on the market”;\" (SI 2023/861 reg.3(1)(d)(i))" do
      assert [%{operation: :substituted, level: :words, targets: ["reg.2(1)"]}] =
               Reader.read(Doc.new("UK_uksi_2023_861", [@reg3]), "regulation-3-1-d-i", %{}, [
                 @epsr
               ])
    end
  end

  describe "a term in a caption is no definition" do
    alias SertantaiLegal.Scraper.AmendingLaw.DefinedTerms

    # 1994 c.19 Sch.16 para.103, then para.107
    @mentions ~S|<Legislation><Primary><Schedules><Schedule id="schedule-16"><ScheduleBody><P1 id="schedule-16-paragraph-103"><P1para><Text>In section 1(9) of the Local Government (Overseas Assistance) Act 1993 (definition of “<Term id="t1">local authority</Term>”), in paragraph (a), for “and” substitute “, the council of a county or county borough in”.</Text></P1para></P1><P1 id="schedule-16-paragraph-3"><P1para><Text>In section 1 of the Firearms Act 1968 (in this Act referred to as “<Term id="t2">the principal Act</Term>”), for “a” substitute “b”.</Text></P1para></P1></ScheduleBody></Schedule></Schedules></Primary></Legislation>|

    test "\"(definition of “local authority”)\" defines nothing; \"(in this Act referred to as “the principal Act”)\" does (1994 c.19 Sch.16 para.103)" do
      terms = DefinedTerms.of(Doc.new("UK_ukpga_1994_19", [@mentions]))

      refute Map.has_key?(terms, "local authority")
      assert %{title: "Firearms Act 1968"} = terms["the principal act"]
    end
  end

  describe "a defined term inside a caption names no law" do
    alias SertantaiLegal.Scraper.Amendment.Reader.LawNamed

    test "\"Section 411 (company insolvency rules) is amended\" is not the term \"Insolvency Rules\" (2020 c.12 Sch.3 para.22)" do
      terms = %{
        "insolvency rules" => %{law: nil, title: "Insolvency (England and Wales) Rules 2016"}
      }

      assert LawNamed.named(
               ["Section 411 (company insolvency rules) is amended as follows."],
               terms
             ) == []

      assert [%{title: "Insolvency (England and Wales) Rules 2016"}] =
               LawNamed.named(["In rule 3 of the Insolvency Rules, omit “x”."], terms)
    end
  end

  describe "a definition in the text made is the amended law's" do
    alias SertantaiLegal.Scraper.AmendingLaw.DefinedTerms

    # SI 2016/248 reg.4(10)
    @made ~S|<Legislation><Secondary><Body><P1 id="regulation-4"><P2 id="regulation-4-10"><P2para><Text>In subsection (7) for the definition of “the Community Recording Equipment Regulation” substitute—</Text><BlockAmendment><P><Text>“<Term id="t1">the EU Tachographs Regulation</Term>” means Regulation (EU) No. 165/2014 of the European Parliament and of the Council on tachographs in road transport as read with the Community Drivers’ Hours and Recording Equipment Regulations 2007 (<Citation URI="http://www.legislation.gov.uk/id/uksi/2007/1819" id="c1">S.I. 2007/1819</Citation>).</Text></P><P><Text>“the EU Regulation” means the Community Drivers’ Hours and Recording Equipment Regulations 2007 (S.I. 2007/1819).</Text></P></BlockAmendment></P2para></P2></P1></Body></Secondary></Legislation>|

    test "no term defined inside a BlockAmendment is the amending law's (SI 2016/248 reg.4(10))" do
      assert DefinedTerms.of(Doc.new("UK_uksi_2016_248", [@made])) == %{}
    end
  end

  describe "a term defined by a provision of a law is no law" do
    alias SertantaiLegal.Scraper.AmendingLaw.DefinedTerms

    # SI 2011/2937 art.3(2)'s definitions
    @under ~S|<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>“Obligated supplier” is defined in article 2(1) of the Renewable Transport Fuel Obligations Order 2007.</Text></P1para></P1><P1 id="article-2"><P1para><Text>“Transport fuel supplier” is defined in section 132(1) of the Energy Act 2004.</Text></P1para></P1></Body></Secondary></Legislation>|

    test "\"defined in article 2(1) of the … Order 2007\" names no law (SI 2011/2937)" do
      assert DefinedTerms.of(Doc.new("UK_uksi_2011_2937", [@under])) == %{}
    end
  end

  describe "a listed lead whose verbs are in its paragraphs" do
    alias SertantaiLegal.Scraper.AmendingLaw.Text

    # 2025 c.18 s.70(8), (9)
    @lead ~S|<Legislation><Primary><Body><P1 id="section-70"><P2 id="section-70-8"><P2para><Text>In the provisions listed in subsection (9)—</Text><P3 id="section-70-8-a"><P3para><Text>for “gateway” substitute “gateways”, and</Text></P3para></P3><P3 id="section-70-8-b"><P3para><Text>for “were omitted” substitute “disapplied only the gateway”.</Text></P3para></P3></P2para></P2><P2 id="section-70-9"><P2para><Text>The provisions are—</Text><P3 id="section-70-9-a"><P3para><Text>section 40(8) of the Freedom of Information Act 2000 (personal data which is exempt information);</Text></P3para></P3><P3 id="section-70-9-d"><P3para><Text>regulation 11(7) of the Environmental Information (Scotland) Regulations 2004 (S.S.I. 2004/520) (restriction on disclosure of personal data);</Text></P3para></P3></P2para></P2></P1></Body></Primary></Legislation>|

    test "each paragraph is read once per item, its own verb at each place (2025 c.18 s.70(8)(b))" do
      doc = Doc.new("UK_ukpga_2025_18", [@lead])

      assert Text.of(doc, "section-70-8-b").instruction =~
               ~r/^for “were omitted” substitute[^;]*, in section 40\(8\) of the Freedom of Information Act 2000; for “were omitted” substitute[^;]*, in regulation 11\(7\) of the Environmental Information \(Scotland\) Regulations 2004$/u

      refute Text.of(doc, "section-70-8").instruction =~ "listed below"
    end
  end

  describe "a title never starts inside a provision's number" do
    alias SertantaiLegal.Scraper.Amendment.Reader.LawNamed

    test "\"regulation 45(1E) of the Civil Contingencies Act 2004 (Contingency Planning) Regulations 2005\" names the Regulations (2025 c.18 s.70(9)(e))" do
      assert [%{title: "Civil Contingencies Act 2004 (Contingency Planning) Regulations 2005"}] =
               LawNamed.named(
                 [
                   "in regulation 45(1E) of the Civil Contingencies Act 2004 (Contingency Planning) Regulations 2005"
                 ],
                 %{}
               )

      assert [%{title: "Water Industry Act 1991"}] =
               LawNamed.named(["in section 3(1A) of the Water Industry Act 1991"], %{})
    end
  end

  describe "a list of laws, each its title then its places" do
    alias SertantaiLegal.Scraper.AmendingLaw.Text

    # 2013 c.22 Sch.9 para.52
    @titled ~S|<Legislation><Primary><Schedules><Schedule id="schedule-9"><ScheduleBody><P1 id="schedule-9-paragraph-52"><P2 id="schedule-9-paragraph-52-1"><P2para><Text>In the provisions listed in sub-paragraph (2) (but subject to any specific amendments made by or under this Act)—</Text><P3 id="schedule-9-paragraph-52-1-a"><P3para><Text>for “A county court”, in each place, substitute “The county court”, and</Text></P3para></P3></P2para></P2><P2 id="schedule-9-paragraph-52-2"><P2para><Text>The provisions are—</Text><UnorderedList><ListItem><Para><Text>Access to Health Records Act 1990: section 8(5),</Text></Para></ListItem><ListItem><Para><Text>Companies Act 2006: section 1183,</Text></Para></ListItem><ListItem><Para><Text>Tribunals, Courts and Enforcement Act 2007: sections 27(1)(a) and 78(3), section 92(1) (in the inserted section 15D(3)),</Text></Para></ListItem><ListItem><Para><Text>Insolvency Act 1986: paragraph 56(1) of Schedule 1, with a view to the inserted references to the county court including a county court in Northern Ireland,</Text></Para></ListItem><ListItem><Para><Text>Housing Act 1988: sections 6A(2) and 40(1) and (3), and section 40(4) until its repeal by the Courts and Legal Services Act 1990 is fully in force,</Text></Para></ListItem><ListItem><Para><Text>Housing Act 1996: sections 95, 138(1) and 203(5),</Text></Para></ListItem><ListItem><Para><Text>Financial Services and Markets Act 2000: paragraphs 16(a) and 16D(a) of Schedule 17,</Text></Para></ListItem><ListItem><Para><Text>Contempt of Court Act 1981: section 14 (but not in its application to Northern Ireland as set out in Schedule 4 to that Act),</Text></Para></ListItem></UnorderedList></P2para></P2></P1></ScheduleBody></Schedule></Schedules></Primary></Legislation>|

    test "the list itself is no instruction (\"until its repeal\" is no verb)" do
      doc = Doc.new("UK_ukpga_2013_22", [@titled])

      for {law, title} <- [
            {"UK_ukpga_1988_50", "Housing Act"},
            {"UK_ukpga_2006_46", "Companies Act"}
          ] do
        assert [] =
                 Reader.read(doc, "schedule-9-paragraph-52-2", %{}, [
                   Reader.law_ref(law, title, "s")
                 ])
      end
    end

    test "each law's places are its own (2013 c.22 Sch.9 para.52(1)(a))" do
      doc = Doc.new("UK_ukpga_2013_22", [@titled])
      i = Text.of(doc, "schedule-9-paragraph-52-1-a").instruction

      assert i =~
               ~r/, in section 8\(5\) of the Access to Health Records Act 1990; .*, in section 1183 of the Companies Act 2006; .*, in section 14 of the Contempt of Court Act 1981$/u

      # one place a part, so no clause cut at "and" joins two laws' places
      for place <- ~w[6A(2) 40(1) 40(3) 40(4)],
          do: assert(i =~ ", in section #{place} of the Housing Act 1988;")

      for place <- ~w[95 138(1) 203(5)],
          do: assert(i =~ ", in section #{place} of the Housing Act 1996;")

      refute i =~ "Financial Services"
      refute i =~ "listed below"
    end
  end

  describe "an \"and\" inside a law's title is no clause break" do
    alias SertantaiLegal.Scraper.Amendment.Reader.Clauses
    alias SertantaiLegal.Scraper.AmendingLaw.Text

    test "\"Mines and Quarries (Tips) Act 1969\" stays whole (2013 c.22 Sch.9 para.52)" do
      i =
        "for “A”, in each place, substitute, in section 107(1) of the Commonhold and Leasehold Reform Act 2002; " <>
          "for “A”, in each place, substitute, in section 28 of the Mines and Quarries (Tips) Act 1969"

      cs = Clauses.clauses(%Text{id: "x", instruction: i, context: [], parents: []})
      assert length(cs) == 2

      assert Enum.any?(
               cs,
               &(&1.instruction =~ "in section 28 of the Mines and Quarries (Tips) Act 1969")
             )

      assert Enum.any?(cs, &(&1.instruction =~ "of the Commonhold and Leasehold Reform Act 2002"))
    end

    test "an \"and\" between two operations still cuts" do
      cs =
        Clauses.clauses(%Text{
          id: "x",
          instruction: "omit “a” and for “b” substitute “c”",
          context: [],
          parents: []
        })

      assert length(cs) == 2
    end
  end

  describe "items naming their law by a term or as \"that Act\"" do
    alias SertantaiLegal.Scraper.AmendingLaw.Text

    # 2004 c.20 s.179(2), (3)
    @that ~S|<Legislation><Primary><Body><P1 id="section-179"><P2 id="section-179-2"><P2para><Text>In each of the provisions specified in subsection (3) (which all refer to electricity conveyed by distribution systems), after “distribution systems” insert “or transmission systems”.</Text></P2para></P2><P2 id="section-179-3"><P2para><Text>Those provisions are—</Text><P3 id="section-179-3-a"><P3para><Text>section 3A(1), (5)(a) and (7) of the 1989 Act (principal objectives and general duties applying to electricity regulation);</Text></P3para></P3><P3 id="section-179-3-b"><P3para><Text>. . . . .</Text></P3para></P3><P3 id="section-179-3-c"><P3para><Text>section 48(1) of that Act (publication of information and advice);</Text></P3para></P3><P3 id="section-179-3-d"><P3para><Text>section 4AA(4)(a) of the Gas Act 1986 (principal objectives and general duties applying to gas regulation); and</Text></P3para></P3></P2para></P2></P1></Body></Primary></Legislation>|

    test "\"of the 1989 Act\" and \"of that Act\" items each their law (2004 c.20 s.179(2))" do
      i = Text.of(Doc.new("UK_ukpga_2004_20", [@that]), "section-179-2").instruction

      for p <- [
            "section 3A(1) of the 1989 Act",
            "section 3A(5)(a) of the 1989 Act",
            "section 3A(7) of the 1989 Act",
            "section 48(1) of the 1989 Act",
            "section 4AA(4)(a) of the Gas Act 1986"
          ],
          do: assert(i =~ ", in #{p}", "#{p} not in #{i}")

      refute i =~ "subsection (3)"
    end
  end

  describe "a list mixing body places and Schedule places of named laws" do
    alias SertantaiLegal.Scraper.AmendingLaw.Text

    # 2001 c.16 Sch.2 para.13
    @mixed ~S|<Legislation><Primary><Schedules><Schedule id="schedule-2"><ScheduleBody><P1 id="schedule-2-paragraph-13"><P2 id="schedule-2-paragraph-13-1"><P2para><Text>In each of the provisions mentioned in sub-paragraph (2) (which confer powers)—</Text><P3 id="schedule-2-paragraph-13-1-a"><P3para><Text>for “contained in a computer” there shall be substituted “stored in any electronic form”; and</Text></P3para></P3></P2para></P2><P2 id="schedule-2-paragraph-13-2"><P2para><Text>Those provisions are—</Text><P3 id="schedule-2-paragraph-13-2-b"><P3para><Text>Articles 21(4) and 22(1) of the Police and Criminal Evidence (Northern Ireland) Order 1989 (S.I. 1989 1341 (N.I. 12));</Text></P3para></P3><P3 id="schedule-2-paragraph-13-2-c"><P3para><Text>section 43(5)(aa) of the Gaming Act 1968 (c. 65);</Text></P3para></P3><P3 id="schedule-2-paragraph-13-2-e"><P3para><Text>section 118D(4) of the Customs and Excise Management Act 1979 (c. 2);</Text></P3para></P3><P3 id="schedule-2-paragraph-13-2-f"><P3para><Text>paragraph 11(4) of Schedule 11 to the Value Added Tax Act 1994 (c. 23);</Text></P3para></P3></P2para></P2></P1></ScheduleBody></Schedule></Schedules></Primary></Legislation>|

    test "each body place its law; a Schedule place none (2001 c.16 Sch.2 para.13(1)(a))" do
      i =
        Text.of(Doc.new("UK_ukpga_2001_16", [@mixed]), "schedule-2-paragraph-13-1-a").instruction

      assert i =~ ", in section 118D(4) of the Customs and Excise Management Act 1979"

      assert i =~
               ", in article 21(4) of the Police and Criminal Evidence (Northern Ireland) Order 1989"

      assert i =~
               ", in article 22(1) of the Police and Criminal Evidence (Northern Ireland) Order 1989"

      refute i =~ "Value Added Tax"
    end

    test "one sentence naming many laws is not told apart (1979 c.2 Sch.4 para.12)" do
      xml =
        ~S|<Legislation><Primary><Body><P1 id="section-1"><P1para><Text>In section 47 of the Naval Prize Act 1864, section 40(9)(e) of the Explosives Act 1875 and section 23 of the Stamp Duties Management Act 1891, for “the Customs” there shall be substituted “customs or excise”.</Text></P1para></P1></Body></Primary></Legislation>|

      d = Doc.new("UK_ukpga_1979_2", [xml])

      assert [] =
               Reader.read(d, "section-1", %{}, [
                 Reader.law_ref("UK_ukpga_1875_17", "Explosives Act", "s")
               ])
    end

    test "laws named in a caption are not counted by the many-laws guard (2008 c.27 s.88(1), 2015 c.20 Sch.23)" do
      xml =
        ~S|<Legislation><Primary><Body><P1 id="section-88"><P2 id="section-88-1"><P2para><Text>In section 105(2) of the Clean Neighbourhoods and Environment Act 2005 (c. 16) (which postpones the increase by subsection (1)(b) in maximum fines under regulations under the Pollution Prevention and Control Act 1999 (c. 24) pending the commencement of section 154(1) of the Criminal Justice Act 2003 (c. 44)), for “Subsection (1)” substitute “Subsection (1)(b)”.</Text></P2para></P2></P1><P1 id="section-89"><P1para><Text>Omit section 1175 of, and Schedule 9 to, the Companies Act 2006 (which make amendments of Part 7 of the Companies Act 1985 and Part 8 of the Companies (Northern Ireland) Order 1986).</Text></P1para></P1></Body></Primary></Legislation>|

      d = Doc.new("UK_ukpga_2008_27", [xml])
      cnea = Reader.law_ref("UK_ukpga_2005_16", "Clean Neighbourhoods and Environment Act", "s")
      ca = Reader.law_ref("UK_ukpga_2006_46", "Companies Act", "s")

      assert [%{targets: ["s.105(2)"]}] = Reader.read(d, "section-88-1", %{}, [cnea])
      assert [%{targets: ["s.1175"]} | _] = Reader.read(d, "section-89", %{}, [ca])
    end

    test "an old-style verb tells each part apart (\"there shall be substituted\")" do
      d = Doc.new("UK_ukpga_2001_16", [@mixed])
      cema = Reader.law_ref("UK_ukpga_1979_2", "Customs and Excise Management Act", "s")

      pace =
        Reader.law_ref(
          "UK_nisi_1989_1341",
          "Police and Criminal Evidence (Northern Ireland) Order",
          "art"
        )

      assert [%{targets: ["s.118D(4)"]}] =
               Reader.read(d, "schedule-2-paragraph-13-1-a", %{}, [cema])

      assert [_ | _] = Reader.read(d, "schedule-2-paragraph-13-1-a", %{}, [pace])
    end
  end

  describe "a heading naming its subject's laws, not the law amended" do
    # SI 2023/247 regs 2, 6
    @fees ~S|<Legislation><Secondary><Body><P1group><Title>Amendment of the Health and Safety and Nuclear (Fees) Regulations 2022</Title><P1 id="regulation-2"><P1para><Text>The Health and Safety and Nuclear (Fees) Regulations 2022 are amended in accordance with regulations 3 to 6.</Text></P1para></P1></P1group><P1group><Title>Fees payable in connection with the Ionising Radiations Regulations 2017</Title><P1 id="regulation-5"><P1para><Text>In Schedule 6 (fees payable in connection with the Ionising Radiations Regulations 2017 etc.), in Table 1, in the entry relating to regulation 16 of the Explosives Regulations 2014, for “x” substitute “y”.</Text></P1para></P1></P1group><P1group><Title>Fees payable in relation to the Explosives Regulations 2014 and the Acetylene Safety (England and Wales and Scotland) Regulations 2014: proposed variation</Title><P1 id="regulation-6"><P2 id="regulation-6-1"><P2para><Text>Regulation 9 (fees payable in relation to the Explosives Regulations 2014 and the Acetylene Safety (England and Wales and Scotland) Regulations 2014) is amended as follows.</Text></P2para></P2><P2 id="regulation-6-4"><P2para><Text>Omit paragraph (3).</Text></P2para></P2></P1></P1group></Body></Secondary></Legislation>|

    test "\"Fees payable in relation to the Explosives Regulations 2014\" leaves the 2022 Regulations (SI 2023/247 reg.6(4))" do
      d = Doc.new("UK_uksi_2023_247", [@fees])

      fees =
        Reader.law_ref(
          "UK_uksi_2022_1378",
          "Health and Safety and Nuclear (Fees) Regulations",
          "reg"
        )

      explosives = Reader.law_ref("UK_uksi_2014_1638", "Explosives Regulations", "reg")

      assert [%{targets: ["reg.9(3)"]}] = Reader.read(d, "regulation-6-4", %{}, [fees])
      assert [] = Reader.read(d, "regulation-6-4", %{}, [explosives])
      # (a table entry's subject names no law amended)
      assert [] = Reader.read(d, "regulation-5", %{}, [explosives])
    end
  end

  describe "a table entry's provision is never the place, in the context too" do
    # 2015 c.20 Sch.11 para.14
    @rtsa ~S|<Legislation><Primary><Schedules><Schedule id="schedule-11"><ScheduleBody><P1 id="schedule-11-paragraph-14"><P2 id="schedule-11-paragraph-14-1"><P2para><Text>In Part 4 of the Railways and Transport Safety Act 2003 (shipping: alcohol and drugs), section 83 (specimens, etc) is amended as follows.</Text></P2para></P2><P2 id="schedule-11-paragraph-14-2"><P2para><Text>The table is amended as follows.</Text></P2para></P2><P2 id="schedule-11-paragraph-14-7"><P2para><Text>In the entry for section 10 of the Road Traffic Act 1988, in the third column—</Text><P3 id="schedule-11-paragraph-14-7-a"><P3para><Text>in paragraph (b), for “or 5” substitute “, 5 or 5A”;</Text></P3para></P3></P2para></P2></P1></ScheduleBody></Schedule></Schedules></Primary></Legislation>|

    test "\"In the entry for section 10 of the Road Traffic Act 1988\" in s.83's table is s.83 (2015 c.20 Sch.11 para.14(7)(a))" do
      d = Doc.new("UK_ukpga_2015_20", [@rtsa])
      rtsa = Reader.law_ref("UK_ukpga_2003_20", "Railways and Transport Safety Act", "s")

      assert [%{targets: targets}] = Reader.read(d, "schedule-11-paragraph-14-7-a", %{}, [rtsa])
      assert Enum.all?(targets, &String.starts_with?(&1, "s.83")), inspect(targets)
    end
  end

  describe "an applied text is the applying law's" do
    # SI 2012/2301 reg.20
    @llp ~S|<Legislation><Secondary><Body><P1 id="regulation-1"><P1para><Text>In these Regulations “the 2006 Act” means the Companies Act 2006; “the 2008 Regulations” means the Limited Liability Partnerships (Accounts and Audit) (Application of the Companies Act 2006) Regulations 2008.</Text></P1para></P1><P1 id="regulation-20"><P2 id="regulation-20-1"><P2para><Text>The 2008 Regulations are amended as follows.</Text></P2para></P2><P2 id="regulation-20-5"><P2para><Text>In regulation 9 (individual accounts)—</Text><P3 id="regulation-20-5-a"><P3para><Text>in the text of section 394 of the 2006 Act as applied to LLPs (duty to prepare individual accounts), after “financial years”, insert “unless the LLP is exempt”, and</Text></P3para></P3></P2para></P2></P1></Body></Secondary></Legislation>|

    test "\"in the text of section 394 of the 2006 Act as applied to LLPs\" is in the 2008 Regulations' reg.9 (SI 2012/2301 reg.20(5)(a))" do
      d = Doc.new("UK_uksi_2012_2301", [@llp])
      terms = SertantaiLegal.Scraper.AmendingLaw.DefinedTerms.of(d)

      llp =
        Reader.law_ref(
          "UK_uksi_2008_1911",
          "Limited Liability Partnerships (Accounts and Audit) (Application of Companies Act 2006) Regulations",
          "reg"
        )

      assert [%{targets: targets}] = Reader.read(d, "regulation-20-5-a", terms, [llp])
      assert Enum.all?(targets, &String.starts_with?(&1, "reg.9")), inspect(targets)
    end
  end
end
