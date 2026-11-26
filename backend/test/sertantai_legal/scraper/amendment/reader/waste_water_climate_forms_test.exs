defmodule SertantaiLegal.Scraper.Amendment.Reader.WasteWaterClimateFormsTest do
  @moduledoc """
  Amending wordings read for Waste, Water and Climate: Amending-law reader
  (2026-11-26, Decision 1; review: data/reports/amending-reader/wwc/review-1.md),
  each on its law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.Reader

  @wia Reader.law_ref("UK_ukpga_1991_56", "Water Industry Act", "s")
  @ccl Reader.law_ref("UK_uksi_2001_838", "Climate Change Levy (General) Regulations", "reg")

  defp doc(amending, body, part \\ "Primary"),
    do:
      Doc.new(amending, [~s(<Legislation><#{part}><Body>#{body}</Body></#{part}></Legislation>)])

  defp targets(rules), do: rules |> Enum.flat_map(& &1.targets) |> Enum.uniq() |> Enum.sort()

  # a place's brackets give its readings (`Brackets.combos`: (1), (a),
  # (1)(a); the rows held decide); each item listed is read, and every
  # target is a reading of an item listed, never another item's brackets
  defp assert_places(targets, items) do
    for i <- items, do: assert(i in targets, "#{i} not read")

    for t <- targets do
      assert Enum.any?(items, &reading?(t, &1)), "#{t} is no reading of the items listed"
    end
  end

  defp reading?(t, item) do
    {n, bs} = split(t)
    {m, cs} = split(item)
    n == m and bs -- cs == []
  end

  defp split(ref) do
    [_, n, bs] = Regex.run(~r/^[a-z]+\.([0-9A-Z]+)(.*)$/, ref)
    {n, Regex.scan(~r/\(([^)]+)\)/, bs, capture: :all_but_first) |> List.flatten()}
  end

  describe "a list of places, each item its own place" do
    test "bracket ranges inside a list are each item's: \"sections 12(3) to (5), 14(1) to (3), (5) and (6) …\" (SI 1999/506 art.30(b))" do
      d =
        doc(
          "UK_uksi_1999_506",
          ~S|<P1 id="article-30"><P1para><Text>In the Water Industry Act 1991–</Text><P3 id="article-30-a"><P3para><Text>in section 12(2)(b) (determinations under conditions of appointment) for “Monopolies and Mergers Commission (in this Act referred to as “the Monopolies Commission”)” substitute “Competition Commission”;</Text></P3para></P3><P3 id="article-30-b"><P3para><Text>in sections 12(3) to (5), 14(1) to (3), (5) and (6) (modification references to the Monopolies Commission), 15(1) to (4) (reports on modification references), 16(1) (modification following report), 31(7) (functions of the Director with respect to competition), 32(1) (duty to refer merger of water or sewerage undertakings), 34(2)(a), (3) and (4) (references with respect to water enterprise mergers), 193(1)(b) (reports by the Director), 195(2)(b) (the Director’s register) and 206(3)(a) and (4)(a) (restrictions on disclosure of information) and Part I of Schedule 15 (persons in respect of whose functions disclosure may be made) for “Monopolies Commission” in each place where it occurs substitute “Competition Commission”; and</Text></P3para></P3></P1para></P1>|,
          "Secondary"
        )

      assert_places(
        targets(Reader.instruction(d, "article-30-b", %{}, [@wia])),
        ~w[s.12(3) s.12(4) s.12(5) s.14(1) s.14(2) s.14(3) s.14(5) s.14(6)
                 s.15(1) s.15(2) s.15(3) s.15(4) s.16(1) s.31(7) s.32(1) s.34(2)(a) s.34(3)
                 s.34(4) s.193(1)(b) s.195(2)(b) s.206(3)(a) s.206(4)(a)]
      )
    end

    test "items written one per list item, \";\" between them (SI 1998/1856 reg.8(1))" do
      pwss =
        Reader.law_ref("UK_uksi_1992_575", "Private Water Supplies (Scotland) Regulations", "reg")

      d =
        doc(
          "UK_uksi_1998_1856",
          ~S|<P1 id="regulation-8"><P1para><Text>The Private Water Supplies (Scotland) Regulations 1992 shall be amended as follows.</Text></P1para><P2 id="regulation-8-1"><P2para><Text>In the following provisions, for the words “an islands or district council” in each place where they occur there shall be substituted the words “a council”:–</Text><UnorderedList Decoration="none"><ListItem><Para><Text>regulation 2(2);</Text></Para></ListItem><ListItem><Para><Text>regulation 8;</Text></Para></ListItem><ListItem><Para><Text>regulation 15(1);</Text></Para></ListItem><ListItem><Para><Text>regulation 16(1)(a);regulation 17(1);</Text></Para></ListItem><ListItem><Para><Text>regulation 18; and</Text></Para></ListItem><ListItem><Para><Text>regulation 22.</Text></Para></ListItem></UnorderedList></P2para></P2></P1>|,
          "Secondary"
        )

      assert_places(
        targets(Reader.instruction(d, "regulation-8-1", %{}, [pwss])),
        ~w[reg.2(2) reg.8 reg.15(1) reg.16(1)(a) reg.17(1) reg.18 reg.22]
      )
    end

    test "the list under \"In each of the following provisions …—\", a Schedule's paragraphs aside (asp 2005/3 Sch.5 para.7(1))" do
      wisa = Reader.law_ref("UK_asp_2002_3", "Water Industry (Scotland) Act", "s")

      d =
        doc(
          "UK_asp_2005_3",
          ~S|<Schedule id="schedule-5"><ScheduleBody><P1 id="schedule-5-paragraph-7"><P1para><Text>The Water Industry (Scotland) Act 2002 (asp 3) is amended as follows.</Text></P1para><P2 id="schedule-5-paragraph-7-1"><P2para><Text>In each of the following provisions of the 2002 Act, for the words “Commissioner” and “Commissioner's” wherever occurring there is substituted <InlineAmendment>“ Commission ”</InlineAmendment> and <InlineAmendment>“ Commission's ”</InlineAmendment> respectively—</Text></P2para></P2><UnorderedList Decoration="none"><ListItem><Para><Text>section 3;</Text></Para></ListItem><ListItem><Para><Text>section 4(1);</Text></Para></ListItem><ListItem><Para><Text>section 5(1) to (3);</Text></Para></ListItem><ListItem><Para><Text>section 11(1)(a);</Text></Para></ListItem><ListItem><Para><Text>section 26(1) to (4) and (7);</Text></Para></ListItem><ListItem><Para><Text>section 57(6)(a); and</Text></Para></ListItem><ListItem><Para><Text>in schedule 1, paragraphs 6(4), 7 and 8.</Text></Para></ListItem></UnorderedList></P1></ScheduleBody></Schedule>|
        )

      assert_places(
        targets(Reader.instruction(d, "schedule-5-paragraph-7-1", %{}, [wisa])),
        ~w[s.3 s.4(1) s.5(1) s.5(2) s.5(3) s.11(1)(a) s.26(1) s.26(2) s.26(3)
                 s.26(4) s.26(7) s.57(6)(a)]
      )
    end

    test "an Order's articles listed (SI 2011/493 art.7(9))" do
      rtfo =
        Reader.law_ref("UK_uksi_2007_3072", "Renewable Transport Fuel Obligations Order", "reg",
          articles: true
        )

      d =
        doc(
          "UK_uksi_2011_493",
          ~S|<P1 id="article-7"><P1para><Text>The Renewable Transport Fuel Obligations Order 2007 is amended as follows.</Text></P1para><P2 id="article-7-9"><P2para><Text>In article 20(5)(b)(ii), (6), (7)(a), (8) and (9), for “the Chief Executive” substitute “the Administrator”.</Text></P2para></P2></P1>|,
          "Secondary"
        )

      assert_places(
        targets(Reader.instruction(d, "article-7-9", %{}, [rtfo])),
        ~w[reg.20(5)(b)(ii) reg.20(6) reg.20(7)(a) reg.20(8) reg.20(9)]
      )
    end

    test "another place's brackets are its own, never the list's (SI 2008/1482 reg.6(1); SI 2010/643 reg.3)" do
      d =
        doc(
          "UK_uksi_2008_1482",
          ~S|<P1 id="regulation-6"><P1para><Text>The Climate Change Levy (General) Regulations 2001 are amended as follows.</Text></P1para><P2 id="regulation-6-1"><P2para><Text>In regulations 14(2)(b), 17(3)(b) and 28(4) of, and Schedule 1 paragraph 8(2)(b) to, the Climate Change Levy (General) Regulations 2001 (the CCL Regulations), for each “£2,000” substitute “£50,000”.</Text></P2para></P2></P1>|,
          "Secondary"
        )

      assert_places(
        targets(Reader.instruction(d, "regulation-6-1", %{}, [@ccl])),
        ~w[reg.14(2)(b) reg.17(3)(b) reg.28(4)]
      )

      d =
        doc(
          "UK_uksi_2010_643",
          ~S|<P1 id="regulation-2"><P1para><Text>The Climate Change Levy (General) Regulations 2001 are amended as follows.</Text></P1para></P1><P1 id="regulation-3"><P1para><Text>In regulations 14(5) and 15(6), and in paragraph 8(5) of Schedule 1, for “three year time limit” substitute “4 year time limit”.</Text></P1para></P1>|,
          "Secondary"
        )

      assert_places(
        targets(Reader.instruction(d, "regulation-3", %{}, [@ccl])),
        ~w[reg.14(5) reg.15(6)]
      )
    end
  end

  describe "a quote's numbers are placed under the place named, never at the top" do
    test "a section named in a link (<ExternalLink id=…>section 25</ExternalLink>) is words (2025 c.5 s.16(c))" do
      d =
        doc(
          "UK_ukpga_2025_5",
          ~S|<P1 id="section-16"><P1para><Text>In <ExternalLink Title="Water Industry Act 1991, section 25" URI="https://www.legislation.gov.uk/ukpga/1991/56/section/25" id="i00064">section 25</ExternalLink> of the <Citation URI="https://www.legislation.gov.uk/ukpga/1991/56" id="c00035" Class="UnitedKingdomPublicGeneralAct" Year="1991" Number="56">Water Industry Act 1991</Citation> (power to make special administration order on winding-up petition)—</Text><P3 id="section-16-a"><P3para><Text>the existing text becomes subsection (1);</Text></P3para></P3><P3 id="section-16-c"><P3para><Text>after that subsection insert—</Text><BlockAmendment><P2><Pnumber>2</Pnumber><P2para><Text>But the court may not exercise its powers on the petition unless—</Text><P3><Pnumber>a</Pnumber><P3para><Text>notice of the petition has been served on the relevant persons, and</Text></P3para></P3></P2para></P2><P2><Pnumber>3</Pnumber><P2para><Text>The relevant persons are entitled to be heard.</Text></P2para></P2></BlockAmendment></P3para></P3></P1para></P1>|
        )

      t = targets(Reader.instruction(d, "section-16-c", %{}, [@wia]))
      assert "s.25(2)" in t and "s.25(3)" in t
      refute Enum.any?(t, &(&1 in ~w[s.2 s.3]))
    end

    test "an Order's articles, though legislation.gov.uk ids its rows \"regulation-\" (SI 2025/678 art.3(3))" do
      vets =
        Reader.law_ref(
          "UK_uksi_2024_1130",
          "Vehicle Emissions Trading Schemes (Amendment) Order",
          "reg"
        )

      assert vets.kind == :order

      d =
        doc(
          "UK_uksi_2025_678",
          ~S|<P1 id="article-3"><P1para><P2 id="article-3-1"><P2para><Text>The Vehicle Emissions Trading Schemes (Amendment) Order 2024 is amended as follows.</Text></P2para></P2><P2 id="article-3-3"><P2para><Text>After article 25(3) insert—</Text><BlockAmendment><P2><Pnumber>4</Pnumber><P2para><Text>For the purposes of paragraphs (2) and (3)—</Text><P3><Pnumber>a</Pnumber><P3para><Text>in points 1 and 2 of Part A, x;</Text></P3para></P3></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|,
          "Secondary"
        )

      t = targets(Reader.instruction(d, "article-3-3", %{}, [vets]))
      assert "reg.25(4)" in t
      refute "reg.4" in t
    end

    test "the regulation named only in the heading (\"Amendment of Regulation 18: …\") holds the quote (NISR 2006/280 reg.12(4))" do
      wml =
        Reader.law_ref(
          "UK_nisr_2003_493",
          "Waste Management Licensing Regulations (Northern Ireland)",
          "reg"
        )

      d =
        doc(
          "UK_nisr_2006_280",
          ~S|<P1group><Title>Amendment of the Waste Management Licensing Regulations (Northern Ireland) 2003</Title><P1 id="regulation-2"><P1para><Text>The Waste Management Licensing Regulations (Northern Ireland) 2003 shall be amended in accordance with regulations 3 to 22.</Text></P1para></P1></P1group><P1group><Title>Amendment of Regulation 18: Registration in connection with exempt activities</Title><P1 id="regulation-12"><P1para><P2 id="regulation-12-1"><P2para><Text>In paragraph (3) for “paragraphs (4) and (5)” substitute “paragraphs (4), (4A), (5) and 5(A)”.</Text></P2para></P2><P2 id="regulation-12-4"><P2para><Text>For paragraph (5) substitute—</Text><BlockAmendment><P2><Pnumber>5</Pnumber><P2para><Text>In the case of exempt activities, x.</Text></P2para></P2><P2><Pnumber>5A</Pnumber><P2para><Text>In the case of other exempt activities, y.</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1></P1group>|,
          "Secondary"
        )

      t = targets(Reader.instruction(d, "regulation-12-4", %{}, [wml]))
      assert "reg.18(5)" in t and "reg.18(5A)" in t
      refute Enum.any?(t, &(&1 in ~w[reg.5 reg.5A]))
    end

    test "a sub-paragraph of a Schedule paragraph the heading names is no regulation (NISR 2006/280 reg.22(3))" do
      wml =
        Reader.law_ref(
          "UK_nisr_2003_493",
          "Waste Management Licensing Regulations (Northern Ireland)",
          "reg"
        )

      d =
        doc(
          "UK_nisr_2006_280",
          ~S|<P1group><Title>Amendment of the Waste Management Licensing Regulations (Northern Ireland) 2003</Title><P1 id="regulation-2"><P1para><Text>The Waste Management Licensing Regulations (Northern Ireland) 2003 shall be amended in accordance with regulations 3 to 22.</Text></P1para></P1></P1group><P1group><Title>Amendment of paragraph 30 of Part I of Schedule 2: Burning waste in the open</Title><P1 id="regulation-22"><P1para><P2 id="regulation-22-3"><P2para><Text>After sub-paragraph (3), insert—</Text><BlockAmendment><P2><Pnumber>4</Pnumber><P2para><Text>The incorporation into soil of ash, x.</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1></P1group>|,
          "Secondary"
        )

      refute "reg.4" in targets(Reader.instruction(d, "regulation-22-3", %{}, [wml]))
    end

    test "an inserted Schedule's paragraphs are never the law's articles (SI 2011/2937 art.23)" do
      rtfo =
        Reader.law_ref("UK_uksi_2007_3072", "Renewable Transport Fuel Obligations Order", "reg")

      d =
        doc(
          "UK_uksi_2011_2937",
          ~S|<P1 id="article-1"><P1para><Text>The Renewable Transport Fuel Obligations Order 2007 is amended as follows.</Text></P1para></P1><P1group><Title>Sustainability criteria</Title><P1 id="article-23"><P1para><Text>After the signature block, insert—</Text><BlockAmendment Context="schedule"><Schedule><Number>SCHEDULE</Number><TitleBlock><Title>SUSTAINABILITY CRITERIA</Title></TitleBlock><ScheduleBody><P1><Pnumber>1</Pnumber><P1para><Text>In this Schedule, x.</Text></P1para></P1><P1><Pnumber>2</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>Y.</Text></P2para></P2></P1para></P1></ScheduleBody></Schedule></BlockAmendment></P1para></P1></P1group>|,
          "Secondary"
        )

      t = targets(Reader.instruction(d, "article-23", %{}, [rtfo]))
      refute Enum.any?(t, &(&1 in ~w[reg.1 reg.2 reg.2(1)]))
    end
  end

  describe "a Part is its own place, never the provision a sibling names" do
    @cdm Reader.law_ref(
           "UK_uksi_2005_2903",
           "Greenhouse Gas Emissions Trading Scheme Regulations",
           "reg"
         )

    defp part_doc(amending, siblings, id, instruction, quote \\ "") do
      p2s =
        siblings
        |> Enum.with_index(1)
        |> Enum.map_join(fn {t, i} ->
          ~s(<P2 id="regulation-2-#{i}"><P2para><Text>#{t}</Text></P2para></P2>)
        end)

      doc(
        amending,
        ~s(<P1 id="regulation-2"><P1para>#{p2s}<P2 id="#{id}"><P2para><Text>#{instruction}</Text>#{quote}</P2para></P2></P1para></P1>),
        "Secondary"
      )
    end

    test "\"Omit Part 5 (offences)\" after \"In regulation 2(1) …\" is Part 5 (SI 2014/3075 reg.2(4))" do
      d =
        part_doc(
          "UK_uksi_2014_3075",
          [
            "The Greenhouse Gas Emissions Trading Scheme Regulations 2005 are amended as follows.",
            "In regulation 2(1) (interpretation), omit the definition of “the 2005 Regulations”."
          ],
          "regulation-2-4",
          "Omit Part 5 (offences)."
        )

      assert [%{targets: ["pt.5"], operation: :repealed, level: :provision}] =
               Reader.instruction(d, "regulation-2-4", %{}, [@cdm])
    end

    test "\"For Part 3 substitute— PART 3 … 5 …\": Part 3 and the regulations its quote makes, never reg.2's (SI 2014/3075 reg.2(3))" do
      quote =
        ~S|<BlockAmendment><Part><Number>PART 3</Number><Title>Project approval</Title><P1group><Title>Approval</Title><P1><Pnumber>5</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>A person may apply.</Text></P2para></P2></P1para></P1></P1group></Part></BlockAmendment>|

      d =
        part_doc(
          "UK_uksi_2014_3075",
          [
            "The Greenhouse Gas Emissions Trading Scheme Regulations 2005 are amended as follows.",
            "In regulation 2(1) (interpretation), omit the definition of “the 2005 Regulations”."
          ],
          "regulation-2-3",
          "For Part 3 (project approval and authorisation to participate) substitute—",
          quote
        )

      t = targets(Reader.instruction(d, "regulation-2-3", %{}, [@cdm]))
      assert "pt.3" in t and "reg.5" in t
      refute Enum.any?(t, &String.starts_with?(&1, "reg.2"))
    end

    test "\"Omit Part 3\" after \"Omit regulation 7\" (SI 2016/279 reg.2(3))" do
      noise = Reader.law_ref("UK_uksi_1975_2116", "Control of Noise (Appeals) Regulations", "reg")

      d =
        part_doc(
          "UK_uksi_2016_279",
          [
            "The Control of Noise (Appeals) Regulations 1975 are amended as follows.",
            "Omit regulation 7 (appeals under section 66(7))."
          ],
          "regulation-2-3",
          "Omit Part 3 (appeals to the Secretary of State)."
        )

      assert ["pt.3"] == targets(Reader.instruction(d, "regulation-2-3", %{}, [noise]))
    end

    test "a Schedule's Part is no section (asp 2005/3 Sch.5 para.7(10))" do
      wisa = Reader.law_ref("UK_asp_2002_3", "Water Industry (Scotland) Act", "s")

      d =
        doc(
          "UK_asp_2005_3",
          ~S|<Schedule id="schedule-5"><ScheduleBody><P1 id="schedule-5-paragraph-7"><P1para><Text>The Water Industry (Scotland) Act 2002 (asp 3) is amended as follows.</Text></P1para><P2 id="schedule-5-paragraph-7-9"><P2para><Text>Section 70 (interpretation) of that Act is amended as follows.</Text></P2para></P2><P2 id="schedule-5-paragraph-7-10"><P2para><Text>Part 1 (the Commissioner) of schedule 1 to that Act is repealed.</Text></P2para></P2></P1></ScheduleBody></Schedule>|
        )

      refute Enum.any?(
               targets(Reader.instruction(d, "schedule-5-paragraph-7-10", %{}, [wisa])),
               &String.starts_with?(&1, "s.70")
             )
    end
  end

  describe "text an amendment made is no place of the law it names" do
    test "\"in the inserted section 87 of the Water Industry Act 1991 …\" under \"Section 58 … is amended\" is the earlier amending provision's (2014 c.21 Sch.7 para.134(2)(a))" do
      wa03 = Reader.law_ref("UK_ukpga_2003_37", "Water Act", "s")

      d =
        doc(
          "UK_ukpga_2014_21",
          ~S|<Schedule id="schedule-7"><ScheduleBody><P1 id="schedule-7-paragraph-133"><P1para><Text>The Water Act 2003 is amended as follows.</Text></P1para></P1><P1 id="schedule-7-paragraph-134"><P1para><P2 id="schedule-7-paragraph-134-1"><P2para><Text>Section 58 (fluoridation of water supplies) is amended as follows.</Text></P2para></P2><P2 id="schedule-7-paragraph-134-2"><P2para><Text>In subsection (2)—</Text><P3 id="schedule-7-paragraph-134-2-a"><P3para><Text>in the inserted section 87 of the Water Industry Act 1991 (fluoridation of water supplies at request of relevant authorities), in subsections (2)(b) and (3)(b), for “licensed water supplier” there is substituted <InlineAmendment>“water supply licensee”</InlineAmendment>;</Text></P3para></P3></P2para></P2></P1para></P1></ScheduleBody></Schedule>|
        )

      rules = Reader.instruction(d, "schedule-7-paragraph-134-2-a", %{}, [@wia, wa03])
      refute Enum.any?(rules, &(&1.amends == "UK_ukpga_1991_56"))
      refute Enum.any?(rules, &(&1.operation == :inserted))
    end

    test "\"in each of the inserted subsections (5B) and (5C) for … substitute\": the words in the provision named above (2021 c.30 s.95(2)(b)(ii))" do
      ewa = Reader.law_ref("UK_anaw_2016_3", "Environment (Wales) Act", "s")

      d =
        doc(
          "UK_ukpga_2021_30",
          ~S|<P1 id="section-95"><P1para><P2 id="section-95-1"><P2para><Text>Section 83 of the Environment (Wales) Act 2016 is amended as follows.</Text></P2para></P2><P2 id="section-95-2"><P2para><Text>In subsection (2)—</Text><P3 id="section-95-2-b"><P3para><Text>in paragraph (b)—</Text><P4 id="section-95-2-b-ii"><P4para><Text>in each of the inserted subsections (5B) and (5C) for “The regulations” substitute <InlineAmendment>“Regulations under this section”</InlineAmendment>;</Text></P4para></P4></P3para></P3></P2para></P2></P1para></P1>|
        )

      assert [%{operation: :substituted, level: :words} = r] =
               Reader.instruction(d, "section-95-2-b-ii", %{}, [ewa])

      assert "s.83(2)(b)" in r.targets
      refute Enum.any?(r.targets, &(&1 =~ ~r/5B|5C/))
    end

    test "under \"Schedule 5 is amended\", \"in the inserted Article 34a\" is the Schedule's text, never the Order's article (SI 2022/1173 art.14(4)(a))" do
      ets =
        Reader.law_ref(
          "UK_uksi_2020_1265",
          "Greenhouse Gas Emissions Trading Scheme Order",
          "reg"
        )

      d =
        doc(
          "UK_uksi_2022_1173",
          ~S|<P1 id="article-14"><P1para><P2 id="article-14-1"><P2para><Text>The Greenhouse Gas Emissions Trading Scheme Order 2020 is amended as follows.</Text></P2para></P2><P2 id="article-14-2"><P2para><Text>Schedule 5 is amended as follows.</Text></P2para></P2><P2 id="article-14-4"><P2para><Text>In paragraph 24—</Text><P3 id="article-14-4-a"><P3para><Text>in the inserted Article 34a—</Text><P4 id="article-14-4-a-ii"><P4para><Text>in the first subparagraph omit “or aircraft operator” each time it occurs;</Text></P4para></P4></P3para></P3></P2para></P2></P1para></P1>|,
          "Secondary"
        )

      refute Enum.any?(
               targets(Reader.instruction(d, "article-14-4-a-ii", %{}, [ets])),
               &String.starts_with?(&1, "reg.34")
             )
    end
  end

  describe "\"delete X and substitute Y\" is one substitution" do
    @cpsr Reader.law_ref(
            "UK_uksi_1990_161",
            "Household Appliances (Noise Emission) Regulations",
            "reg"
          )

    defp sub_doc(amending, id, instruction),
      do:
        doc(
          amending,
          ~s|<P1 id="regulation-3"><P1para><Text>The Household Appliances (Noise Emission) Regulations 1990 shall be amended as follows—</Text><P2 id="#{id}"><P2para><Text>#{instruction}</Text></P2para></P2></P1para></P1>|,
          "Secondary"
        )

    defp ops(rules), do: rules |> Enum.map(&{&1.operation, &1.level}) |> Enum.uniq()

    test "split by \" and \" (SSI 2000/432 reg.3(3))" do
      grr = Reader.law_ref("UK_uksi_1993_1155", "Groundwater Regulations", "reg")

      d =
        doc(
          "UK_ssi_2000_432",
          ~S|<P1 id="regulation-3"><P1para><P2 id="regulation-3-1"><P2para><Text>The Groundwater Regulations 1993 are amended as follows.</Text></P2para></P2><P2 id="regulation-3-3"><P2para><Text>In paragraph (2) of regulation 3 delete “regulation 7(2)” and substitute “regulations 4A(2) and 7(2)”.</Text></P2para></P2></P1para></P1>|,
          "Secondary"
        )

      assert [{:substituted, :words}] = ops(Reader.instruction(d, "regulation-3-3", %{}, [grr]))
    end

    test "the words glued to \"and\" (SI 1994/1386 reg.3(c)(i))" do
      d =
        sub_doc(
          "UK_uksi_1994_1386",
          "regulation-3-c-i",
          "in regulation 6, at the start of paragraph (1) delete “The Secretary of State”and substitute “An enforcement authority”;"
        )

      assert [{:substituted, :words}] =
               ops(Reader.instruction(d, "regulation-3-c-i", %{}, [@cpsr]))
    end

    test "a mark: \"delete the full stop and substitute “; and …”\" (SI 1994/1386 reg.3(a)(ii))" do
      d =
        sub_doc(
          "UK_uksi_1994_1386",
          "regulation-3-a-ii",
          "in regulation 2(1), at the end of the definition of “relevant national standard“ delete the full stop and substitute “; and ”the 1987 Act” means the Consumer Protection Act 1987.”;"
        )

      assert [{:substituted, :words}] =
               ops(Reader.instruction(d, "regulation-3-a-ii", %{}, [@cpsr]))
    end
  end

  describe "headings, asides, modifications and words" do
    defp act_doc(amending, lead, id, instruction, parent \\ nil) do
      inner =
        if parent,
          do:
            ~s(<P2 id="#{String.replace(id, ~r/-[^-]+$/, "")}"><P2para><Text>#{parent}</Text><P3 id="#{id}"><P3para><Text>#{instruction}</Text></P3para></P3></P2para></P2>),
          else: ~s(<P2 id="#{id}"><P2para><Text>#{instruction}</Text></P2para></P2>)

      doc(
        amending,
        ~s(<P1 id="section-1"><P1para><P2 id="section-1-1"><P2para><Text>#{lead}</Text></P2para></P2>#{inner}</P1para></P1>)
      )
    end

    test "\"The italic heading immediately preceding section 88 is omitted\": the heading, never the section (asp 2024/13 s.10(5))" do
      ccsa = Reader.law_ref("UK_asp_2009_12", "Climate Change (Scotland) Act", "s")

      d =
        act_doc(
          "UK_asp_2024_13",
          "The Climate Change (Scotland) Act 2009 is amended as follows.",
          "section-1-5",
          "The italic heading immediately preceding section 88 is omitted."
        )

      assert [%{level: :words}] = Reader.instruction(d, "section-1-5", %{}, [ccsa])
    end

    test "\"in the words inserted into section 213(1) of the … Act\" is an earlier amending provision's (2014 c.21 Sch.7 para.145)" do
      d =
        act_doc(
          "UK_ukpga_2014_21",
          "The Water Act 2003 is amended as follows.",
          "section-1-2",
          "In section 35 (provision of infrastructure), in subsection (2), in the words inserted into section 213(1) of the Water Industry Act 1991, the words “17D(8),” are repealed (if section 35(2) remains to be brought into force to any extent)."
        )

      refute Enum.any?(
               Reader.instruction(d, "section-1-2", %{}, [@wia]),
               &(&1.amends == "UK_ukpga_1991_56")
             )
    end

    test "\"The amendments made to section 167(1) … by … shall cease to have effect\": its words (2010 c.29 s.41(1))" do
      d =
        doc(
          "UK_ukpga_2010_29",
          ~S|<P1 id="section-41"><P1para><P2 id="section-41-1"><P2para><Text>The amendments made to section 167(1) of the Water Industry Act 1991 (compulsory works orders) by paragraph 50 of Schedule 2 to the Planning Act 2008 (amendments consequential on the development consent regime) shall cease to have effect.</Text></P2para></P2></P1para></P1>|
        )

      assert [%{targets: ["s.167(1)"], operation: :repealed, level: :words}] =
               Reader.instruction(d, "section-41-1", %{}, [@wia])
    end

    test "\"there were substituted\" and \"shall have effect, in relation to …, as if\" are modifications (WSI 2019/414 reg.6(2)(b)(ii); SI 1994/73 reg.2)" do
      d =
        doc(
          "UK_uksi_1994_73",
          ~S|<P1 id="regulation-2"><P1para><Text>Section 33(1)(a) of the Water Industry Act 1991 (exclusion of small mergers from duty to make merger reference) shall have effect, in relation to mergers after the coming into force of these Regulations, as if for the words “the amount for the time being specified” there were substituted the words “£30 million”.</Text></P1para></P1>|,
          "Secondary"
        )

      assert [] == Reader.instruction(d, "regulation-2", %{}, [@wia])

      d =
        act_doc(
          "UK_wsi_2019_414",
          "The Water Industry Act 1991 is amended as follows.",
          "section-1-2-a",
          "for paragraph (3) there were substituted—",
          "In section 9(3) at the end insert “, and read as if— in Article 3—"
        )

      assert [] == Reader.instruction(d, "section-1-2-a", %{}, [@wia])
    end

    test "an aside of the amending law's own provisions is no place (1997 c.11 Sch.2 para.27(a); SSI 2002/276 reg.7(1))" do
      sa78 = Reader.law_ref("UK_ukpga_1978_3", "Refuse Disposal (Amenity) Act", "s")

      d =
        act_doc(
          "UK_ukpga_1997_11",
          "In section 8 of the Refuse Disposal (Amenity) Act 1978—",
          "section-1-2-a",
          "for “x” substitute “y”;",
          "in subsection (2) as substituted by subsection (4)—"
        )

      t = targets(Reader.instruction(d, "section-1-2-a", %{}, [sa78]))
      assert "s.8(2)" in t
      refute "s.8(4)" in t

      sr = Reader.law_ref("UK_uksi_1996_1564", "Special Waste Regulations", "reg")

      d =
        doc(
          "UK_ssi_2002_276",
          ~S|<P1 id="regulation-7"><P1para><P2 id="regulation-7-1"><P2para><Text>Subject to paragraph (2), regulation 3(1) of and Schedule 4 to the Special Waste Regulations 1996 are hereby revoked.</Text></P2para></P2></P1para></P1>|,
          "Secondary"
        )

      t = targets(Reader.instruction(d, "regulation-7-1", %{}, [sr]))
      assert "reg.3(1)" in t
      refute "reg.3(2)" in t
    end

    test "inline words substituted, the words in the parent or lost from the text, are words (1994 c.39 Sch.13 para.75(12)(b)(ii); 1995 c.17 Sch.1 para.120(3))" do
      ssa = Reader.law_ref("UK_ukpga_1968_47", "Sewerage (Scotland) Act", "s")

      d =
        act_doc(
          "UK_ukpga_1994_39",
          "In section 15 of the Sewerage (Scotland) Act 1968—",
          "section-1-2-a",
          "where they occur in the proviso, substitute <InlineAmendment>“ authority in question ”</InlineAmendment>; and",
          "in subsection (3), for “local authority”—"
        )

      assert [%{level: :words}] = Reader.instruction(d, "section-1-2-a", %{}, [ssa])

      d =
        act_doc(
          "UK_ukpga_1995_17",
          "The Water Industry Act 1991 is amended as follows.",
          "section-1-2",
          "In section 89 (publicity and consultation)— substitute <InlineAmendment>“ Health Authority ”</InlineAmendment>."
        )

      assert [%{targets: ["s.89"], level: :words}] =
               Reader.instruction(d, "section-1-2", %{}, [@wia])
    end
  end

  describe "parked bugs fixed in this step" do
    test "a quote restating its regulation's number: \"For regulation 3(1) substitute— 3 (1) …\" is reg.3(1) (NISR 2007/165 reg.3(3); NISR 2015/231 reg.2(4))" do
      ppc = Reader.law_ref("UK_nisr_1995_345", "Offshore Installations Regulations", "reg")

      d =
        doc(
          "UK_nisr_2007_165",
          ~S|<P1 id="regulation-3"><P1para><P2 id="regulation-3-1"><P2para><Text>The Offshore Installations Regulations 1995 shall be amended as follows.</Text></P2para></P2><P2 id="regulation-3-3"><P2para><Text>For regulation 3(1) there shall be substituted—</Text><BlockAmendment><P1><Pnumber PuncAfter=".">3</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>Within the territorial sea these Regulations shall apply only to x.</Text></P2para></P2></P1para></P1></BlockAmendment></P2para></P2></P1para></P1>|,
          "Secondary"
        )

      assert ["reg.3(1)"] == targets(Reader.instruction(d, "regulation-3-3", %{}, [ppc]))
    end

    test "\"Part IV (drainage works) of the 1999 Regulations is revoked\": Part IV, never the whole law (SSI 2017/114 reg.50(1))" do
      wer =
        Reader.law_ref(
          "UK_ssi_1999_1",
          "Environmental Impact Assessment (Scotland) Regulations",
          "reg"
        )

      d =
        doc(
          "UK_ssi_2017_114",
          ~S|<P1 id="regulation-50"><P1para><P2 id="regulation-50-1"><P2para><Text>Subject to paragraph (2), Part IV (drainage works) of the 1999 Regulations is revoked.</Text></P2para></P2></P1para></P1>|,
          "Secondary"
        )

      terms = %{"the 1999 regulations" => %{law: "UK_ssi_1999_1", title: nil}}
      assert ["pt.4"] == targets(Reader.read(d, "regulation-50-1", terms, [wer]))
    end

    test "a title printed with no space before its year, \"(Northern Ireland)1995\", names its law (NISR 2007/247 Sch.10 para.3)" do
      pfeer =
        Reader.law_ref(
          "UK_nisr_1995_345",
          "Offshore Installations (Prevention of Fire and Explosion, and Emergency Response) Regulations (Northern Ireland)",
          "reg"
        )

      mgmt =
        Reader.law_ref(
          "UK_nisr_1995_340",
          "Offshore Installations and Pipeline Works (Management and Administration) Regulations (Northern Ireland)",
          "reg"
        )

      d =
        doc(
          "UK_nisr_2007_247",
          ~S|<Schedules><Schedule id="schedule-10"><ScheduleBody><P1group><P1 id="schedule-10-paragraph-2"><P1para><Text>In the Offshore Installations and Pipeline Works (Management and Administration) Regulations (Northern Ireland) 1995, in regulation 17, omit “x”.</Text></P1para></P1><P1 id="schedule-10-paragraph-3"><P1para><Text>In the Offshore Installations (Prevention of Fire and Explosion, and Emergency Response) Regulations (Northern Ireland)1995, in regulation 2(1), omit “y”.</Text></P1para></P1></P1group></ScheduleBody></Schedule></Schedules>|,
          "Secondary"
        )

      assert [%{amends: "UK_nisr_1995_345"}] =
               Reader.instruction(d, "schedule-10-paragraph-3", %{}, [pfeer, mgmt])
    end

    test "a title keeps a year inside it; only the law's own year goes (SI 2015/1637)" do
      alias SertantaiLegal.Scraper.Amendment.ReadLaw

      assert "Deregulation Act 2015 (Health and Safety at Work) (General Duties of Self-Employed Persons) (Consequential Amendments) Order" ==
               ReadLaw.own_title(
                 "Deregulation Act 2015 (Health and Safety at Work) (General Duties of Self-Employed Persons) (Consequential Amendments) Order 2015",
                 "UK_uksi_2015_1637"
               )

      assert "Environment Act" == ReadLaw.own_title("Environment Act 1995", "UK_ukpga_1995_25")
      assert "Water Act" == ReadLaw.own_title("Water Act 1989 ", "UK_ukpga_1989_15")

      assert "Town and Country Planning (Scotland) Act" ==
               ReadLaw.own_title(
                 "Town and Country Planning (Scotland) Act 1972 (repealed 27.5.1997)",
                 "UK_ukpga_1972_52"
               )

      assert "Merchant Shipping (Work in Fishing Convention) (Survey and Certification) Regulations" ==
               ReadLaw.own_title(
                 "Merchant Shipping (Work in Fishing Convention) (Survey and Certification) Regulations 2018.",
                 "UK_uksi_2018_1107"
               )
    end

    test "an item with no verb of its own under \"The following provisions are repealed—\" is repealed, caption or none (asp 2015/13 s.1(2)(a))" do
      ports = Reader.law_ref("UK_ukpga_1991_52", "Ports Act", "s")

      d =
        doc(
          "UK_asp_2015_13",
          ~S|<P1 id="section-1"><P1para><P2 id="section-1-1"><P2para><Text>The Ports Act 1991 is amended as follows.</Text></P2para></P2><P2 id="section-1-2"><P2para><Text>The following provisions are repealed—</Text><P3 id="section-1-2-a"><P3para><Text>section 10 (schemes initiated by the Scottish Ministers),</Text></P3para></P3><P3 id="section-1-2-b"><P3para><Text>section 11,</Text></P3para></P3></P2para></P2></P1para></P1>|
        )

      for id <- ["section-1-2-a", "section-1-2-b"] do
        assert [%{operation: :repealed, level: :provision}] =
                 Reader.instruction(d, id, %{}, [ports])
      end
    end

    test "a pointer keeps the item before \"(with …)\" and never reads the aside's provisions" do
      alias SertantaiLegal.Scraper.AmendingLaw.Pointer

      p =
        Pointer.parse(%{
          text:
            "Sch. 1 para. 3 repealed by 1999 c. 28, ss. 5(1)(a), 7 (with s. 9(1) of the 1998 Act)",
          citation_law: "UK_ukpga_1999_28"
        })

      assert [{:section, "5", ["1", "a"]}, {:section, "7", []}] == p.provisions

      q =
        Pointer.parse(%{
          text:
            "Words substituted by 2005 c. 9, s. 67(1), Sch. 6 para. 41(2) (with ss. 27-29, 62)",
          citation_law: "UK_ukpga_2005_9"
        })

      assert [{:section, "67", ["1"]}, {:schedule, "6", nil, "41", ["2"]}] == q.provisions
    end

    test "a pointer's range names each provision in it, never its first end alone" do
      alias SertantaiLegal.Scraper.AmendingLaw.Pointer

      assert [{:section, "3", []}, {:section, "4", []}, {:section, "5", []}] ==
               Pointer.refs_in("ss. 3-5")

      assert [{:section, "5", ["1"]}, {:section, "5", ["2"]}, {:section, "5", ["3"]}] ==
               Pointer.refs_in("s. 5(1)-(3)")

      assert [{:article, "2", ["a"]}, {:article, "2", ["b"]}, {:article, "2", ["c"]}] ==
               Pointer.refs_in("art. 2(a)-(c)")

      assert [
               {:schedule, "2", nil, "4", []},
               {:schedule, "2", nil, "5", []},
               {:schedule, "2", nil, "6", []}
             ] == Pointer.refs_in("Sch. 2 paras. 4-6")

      assert [
               {:regulation, "10", []},
               {:regulation, "11", []},
               {:regulation, "12", []},
               {:regulation, "14", []}
             ] ==
               Pointer.refs_in("regs. 10-12, 14")

      # ends not plain ("12-12B", roman sub-paragraphs): the two ends only
      assert [{:section, "12", []}, {:section, "12B", []}] == Pointer.refs_in("ss. 12-12B")
    end

    test "an aside is read outside quoted words only, and never past a closing bracket (1994 c.19 Sch.15 para.40(b); 2002 c.40 s.267(2); 2010 c.29 Sch.4 para.23(3))" do
      alias SertantaiLegal.Scraper.Amendment.Reader.Clauses

      assert "in subsection (3) omit “as amended by subsection (1) above”." ==
               Clauses.no_made_text(
                 "in subsection (3) omit “as amended by subsection (1) above”."
               )

      # an aside inside a caption ends at its ")": the verb after it stays
      assert Clauses.no_made_text(
               "Section 81(1) and (2) of that Act (which amplify the provision substituted by subsection (1) above) shall cease to have effect."
             ) =~ ~r/^Section 81\(1\) and \(2\) of that Act \(.*\) shall cease to have effect\.$/u

      assert Clauses.no_made_text("After subsection (4)(g) (inserted by paragraph 17(6)) add—") =~
               ~r/^After subsection \(4\)\(g\) \(.*\) add—$/u

      # and its law is gone, so the caption names no law (2022 c.32 s.195(8))
      refute Clauses.no_made_text(
               "In subsection (8) (as amended by section 19 of the Armed Forces Act 2021)—"
             ) =~
               "Armed Forces"

      # still an aside where it stands outside brackets and quotes

      refute Clauses.no_made_text(
               "In regulation 13(4) of the LT Regulations as amended by regulations 5(2) to 5(4), for “x” substitute “y”"
             ) =~ "5(2)"
    end

    test "a Schedule's Part, or a Part named only for its application, is no Part of the law (2003 c.44 s.288; 2021 c.30 s.64(3)(b))" do
      alias SertantaiLegal.Scraper.Amendment.Reader.Targets

      assert :schedule ==
               Targets.own_part(
                 "In Part 1 of Schedule 6 to the Firearms Act 1968 (c. 27) (prosecution and punishment of offences) for the entries relating to offences under section 5 substitute—"
               )

      assert :schedule ==
               Targets.own_part(
                 "In Part 2 of Schedule 3 (appeals), omit the entry relating to section 169."
               )

      assert nil ==
               Targets.own_part(
                 "in the definition of “environmental licence”, in the application of Part 1 of the Act in relation to the Scottish Environment Protection Agency, omit paragraphs (l) to (o)."
               )

      assert {:part, "4"} ==
               Targets.own_part(
                 "Part 4 of the Airports Act 1986 (economic regulation of airports) is repealed."
               )

      assert {:part, "7"} ==
               Targets.own_part("At the end of Part VII of the principal Act there is inserted—")
    end

    test "a title holding another law's title names the whole: \"… Act 2005 (Consequential Provisions and Modifications) Order 2005\" is the Order (2013 c.24 Sch.6)" do
      order =
        Reader.law_ref(
          "UK_uksi_2005_3172",
          "Water Services etc. (Scotland) Act 2005 (Consequential Provisions and Modifications) Order",
          "reg",
          articles: true
        )

      act = Reader.law_ref("UK_asp_2005_3", "Water Services etc. (Scotland) Act", "s")

      d =
        doc(
          "UK_ukpga_2013_24",
          ~S|<P1 id="section-1"><P1para><P2 id="section-1-1"><P2para><Text>The Water Services etc. (Scotland) Act 2005 (Consequential Provisions and Modifications) Order 2005 is amended as follows.</Text></P2para></P2><P2 id="section-1-2"><P2para><Text>In article 4 (references: time limits), in paragraphs (2) and (3), for “Commission” substitute “CMA”.</Text></P2para></P2></P1para></P1>|
        )

      assert [%{amends: "UK_uksi_2005_3172"}] =
               Reader.instruction(d, "section-1-2", %{}, [order, act])
    end

    test "a law named only in a caption is never the law amended (2021 c.30 s.95; 1999 c.29 s.40(3))" do
      alias SertantaiLegal.Scraper.Amendment.Reader.LawNamed

      lda = Reader.law_ref("UK_ukpga_1991_59", "Land Drainage Act", "s")
      lga = Reader.law_ref("UK_ukpga_1972_70", "Local Government Act", "s")

      refute Enum.any?(
               LawNamed.named(
                 [
                   "Section 83 of the Agriculture (Wales) Act 2016 (which amends the Land Drainage Act 1991) is amended as follows."
                 ],
                 %{}
               ),
               &LawNamed.law_named?(&1, lda)
             )

      refute Enum.any?(
               LawNamed.named(
                 [
                   "After subsection (5) of that section (which implies certain terms into arrangements under section 101 of the Local Government Act 1972 etc) there shall be inserted—"
                 ],
                 %{}
               ),
               &LawNamed.law_named?(&1, lga)
             )

      # a title outside brackets still names its law
      assert Enum.any?(
               LawNamed.named(
                 ["In the Land Drainage Act 1991 (c. 59), omit section 2(2A)."],
                 %{}
               ),
               &LawNamed.law_named?(&1, lda)
             )
    end
  end
end
