defmodule SertantaiLegal.Scraper.Amendment.Reader.AmendingSchedulesTest do
  @moduledoc """
  An amending law's Schedules, read as its body is (Amending-law reader:
  amending Schedules, 2026-11-27): a Schedule whose title names the law
  amended names it for the paragraphs under it. Each case is the law's real
  wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.Reader

  @hswa Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

  defp doc(amending, schedules),
    do:
      Doc.new(amending, [
        ~s(<Legislation><Primary><Body/></Primary></Legislation>),
        ~s(<Legislation><Primary><Schedules>#{schedules}</Schedules></Primary></Legislation>)
      ])

  describe "a lead naming a provision's brackets" do
    @gas Reader.law_ref(
           "UK_uksi_1998_2451",
           "Gas Safety (Installation and Use) Regulations",
           "reg"
         )
    @equality Reader.law_ref("UK_ukpga_2010_15", "Equality Act", "s")

    defp body(amending, body),
      do:
        Doc.new(amending, [
          ~s(<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>)
        ])

    # SI 2018/139 reg.5
    @reg5 ~S|<P1 id="regulation-2"><P1para><Text>The Gas Safety (Installation and Use) Regulations 1998 are amended in accordance with the following regulations.</Text></P1para></P1><P1 id="regulation-5"><P1para><P2 id="regulation-5-1"><P2para><Text>Regulation 36(3) (timing of gas safety checks and record keeping obligations) is amended as follows.</Text></P2para></P2><P2 id="regulation-5-2"><P2para><Text>In sub-paragraph (a), after “Regulations or not” insert “; and see regulation 36A”.</Text></P2para></P2><P2 id="regulation-5-5"><P2para><Text>In regulation 37(2), omit “gas”.</Text></P2para></P2></P1para></P1>|

    test "\"Regulation 36(3) … is amended as follows.\" places \"In sub-paragraph (a)\" at reg.36(3)(a) (SI 2018/139 reg.5(2))" do
      assert [%{targets: targets}] =
               Reader.read(body("UK_uksi_2018_139", @reg5), "regulation-5-2", %{}, [@gas])

      # (reg.36(3), reg.36(a) beside it are candidates, kept only where held)
      assert "reg.36(3)(a)" in targets
    end

    test "a clause naming its own provision keeps it (\"In regulation 37(2)\" under the same lead)" do
      assert [%{targets: targets}] =
               Reader.read(body("UK_uksi_2018_139", @reg5), "regulation-5-5", %{}, [@gas])

      assert "reg.37(2)" in targets
      refute Enum.any?(targets, &String.starts_with?(&1, "reg.37(3)"))
    end

    # 2013 c.24 s.97
    @s97 ~S|<P1 id="section-97"><P1para><P2 id="section-97-1"><P2para><Text>Section 9(5) of the Equality Act 2010 is amended in accordance with subsections (2) to (4).</Text></P2para></P2><P2 id="section-97-2"><P2para><Text>Omit “may by order”.</Text></P2para></P2><P2 id="section-97-3"><P2para><Text>In paragraph (a) (power to provide for caste to be an aspect of race) at the beginning insert <InlineAmendment>“must by order”</InlineAmendment>.</Text></P2para></P2></P1para></P1>|

    test "\"Section 9(5) of the Equality Act 2010 is amended …\" places \"In paragraph (a)\" at s.9(5)(a) (2013 c.24 s.97(3))" do
      d =
        Doc.new("UK_ukpga_2013_24", [
          ~s(<Legislation><Primary><Body>#{@s97}</Body></Primary></Legislation>)
        ])

      assert [%{targets: targets}] = Reader.read(d, "section-97-3", %{}, [@equality])
      assert "s.9(5)(a)" in targets
      # the lead's own "in accordance with subsections (2) to (4)" places nothing
      refute Enum.any?(targets, &(&1 in ["s.9(2)", "s.9(3)", "s.9(4)"]))
    end
  end

  describe "a paragraph's provision in an unnumbered or Part-numbered Schedule" do
    @cu Reader.law_ref(
          "UK_uksi_1986_1078",
          "Road Vehicles (Construction and Use) Regulations",
          "reg"
        )
    @copa Reader.law_ref("UK_ukpga_1974_40", "Control of Pollution Act", "s")

    # SI 2019/734's only Schedule: ids schedule-paragraph-N
    @para58 ~S|<Schedule id="schedule"><ScheduleBody><P1 id="schedule-paragraph-58"><Pnumber>58</Pnumber><P1para><P2 id="schedule-paragraph-58-1"><Pnumber>1</Pnumber><P2para><Text>Regulation 37 (audible warning instruments) of the Road Vehicles (Construction and Use) Regulations 1986 is amended as follows.</Text></P2para></P2><P2 id="schedule-paragraph-58-2"><Pnumber>2</Pnumber><P2para><Text>After paragraph (5)(c) insert—</Text><BlockAmendment Context="unknown" TargetClass="unknown" TargetSubClass="unknown" Format="double"><P3><Pnumber>ca</Pnumber><P3para><Text>owned by the Scottish Ministers for the purposes of their functions under the Forestry and Land Management (Scotland) Act 2018 and used from time to time for the purposes of fighting fires,</Text></P3para></P3></BlockAmendment><AppendText>.</AppendText></P2para></P2></P1para></P1></ScheduleBody></Schedule>|

    test "an unnumbered Schedule's sub-paragraph reads its paragraph's lead (SI 2019/734 Sch. para.58(2))" do
      d =
        Doc.new("UK_uksi_2019_734", [
          ~s(<Legislation><Secondary><Schedules>#{@para58}</Schedules></Secondary></Legislation>)
        ])

      targets =
        d |> Reader.read("schedule-paragraph-58-2", %{}, [@cu]) |> Enum.flat_map(& &1.targets)

      assert "reg.37(5)(ca)" in targets
    end

    # SI 2016/1154 Sch.29 Pt.1: ids schedule-29-part-1-paragraph-N
    @para3 ~S|<Schedule id="schedule-29"><Number>SCHEDULE 29</Number><TitleBlock><Title>Consequential amendments</Title></TitleBlock><ScheduleBody><Part id="schedule-29-part-1"><Number>PART 1</Number><Title>Public General Acts</Title><P1 id="schedule-29-part-1-paragraph-3" shortId="schedule-29-paragraph-3"><Pnumber>3</Pnumber><P1para><Text>In section 30(5) of the Control of Pollution Act 1974—</Text><P3 id="schedule-29-part-1-paragraph-3-a" shortId="schedule-29-paragraph-3-a"><Pnumber>a</Pnumber><P3para><Text>in the words before paragraph (a), for “the Environmental Permitting (England and Wales) Regulations 2010” substitute <InlineAmendment>“the Environmental Permitting (England and Wales) Regulations 2016 (S.I. 2016/1154)”</InlineAmendment>;</Text></P3para></P3></P1para></P1></Part></ScheduleBody></Schedule>|

    test "a Part-numbered Schedule's sub-paragraph reads its paragraph's lead (SI 2016/1154 Sch.29 Pt.1 para.3(a))" do
      d = doc("UK_uksi_2016_1154", @para3)

      assert [%{amends: "UK_ukpga_1974_40", targets: targets}] =
               Reader.read(d, "schedule-29-part-1-paragraph-3-a", %{}, [@copa])

      assert "s.30(5)" in targets
    end
  end

  describe "a Schedule's title names the law" do
    @tcpa Reader.law_ref("UK_ukpga_1990_8", "Town and Country Planning Act", "s")
    @lura Reader.law_ref("UK_ukpga_2023_55", "Levelling-up and Regeneration Act", "s")

    # asc 2026/7 Sch.1 para.5: a condition names another law, never the law amended
    @sch1_tcpa ~S|<Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>AMENDMENTS TO THE TOWN AND COUNTRY PLANNING ACT 1990</Title></TitleBlock><ScheduleBody><P1 id="schedule-1-paragraph-5"><Pnumber>5</Pnumber><P1para><Text>In section 5(3), if paragraphs 4 and 5 of Schedule 11 to LURA 2023 are in force, for “to 95” substitute “to 93J”.</Text></P1para></P1></ScheduleBody></Schedule>|

    test "\"if paragraphs 4 and 5 of Schedule 11 to LURA 2023 are in force,\" names no law amended (asc 2026/7 Sch.1 para.5)" do
      d = doc("UK_asc_2026_7", @sch1_tcpa)

      terms = %{
        "lura 2023" => %{law: "UK_ukpga_2023_55", title: "Levelling-up and Regeneration Act 2023"}
      }

      assert [%{amends: "UK_ukpga_1990_8", targets: targets}] =
               Reader.read(d, "schedule-1-paragraph-5", terms, [@tcpa, @lura])

      assert "s.5(3)" in targets
    end

    @sch1_61 ~S|<Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>AMENDMENTS TO THE TOWN AND COUNTRY PLANNING ACT 1990</Title></TitleBlock><ScheduleBody><P1 id="schedule-1-paragraph-61"><Pnumber>61</Pnumber><P1para><Text>If paragraphs 3 to 6 of Schedule 11 to LURA 2023 are in force, omit sections 94 to 96 and the italic heading before them.</Text></P1para></P1></ScheduleBody></Schedule>|

    test "a condition opening the sentence names no law amended (asc 2026/7 Sch.1 para.61)" do
      terms = %{
        "lura 2023" => %{law: "UK_ukpga_2023_55", title: "Levelling-up and Regeneration Act 2023"}
      }

      assert [%{amends: "UK_ukpga_1990_8"} | _] =
               Reader.read(doc("UK_asc_2026_7", @sch1_61), "schedule-1-paragraph-61", terms, [
                 @tcpa,
                 @lura
               ])
    end

    # Employment Protection Act 1975 Sch.15: the title's "Etc." in capitals
    @sch15 ~S|<Schedule id="schedule-15"><Number>Schedule 15</Number><TitleBlock><Title> Amendments of the <CommentaryRef Ref="c890629"/> Health and Safety at Work Etc. Act 1974</Title></TitleBlock><Reference>Section 116</Reference><ScheduleBody><P1 id="schedule-15-paragraph-2"><Pnumber>2</Pnumber><P1para><Text>In section 2, omit subsection (5) and in subsection (7) for the words “subsections (4) and (5)” substitute the words “subsection (4)”.</Text></P1para></P1></ScheduleBody></Schedule>|

    test "\"Amendments of the Health and Safety at Work Etc. Act 1974\" names HSWA (1975 c.71 Sch.15 para.2)" do
      rules =
        Reader.read(doc("UK_ukpga_1975_71", @sch15), "schedule-15-paragraph-2", %{}, [@hswa])

      assert Enum.all?(rules, &(&1.amends == "UK_ukpga_1974_37"))
      targets = Enum.flat_map(rules, & &1.targets)
      assert "s.2(5)" in targets
      assert "s.2(7)" in targets
    end
  end

  describe "an amendments table" do
    @transport Reader.law_ref("UK_ukpga_1968_73", "Transport Act", "s")
    @ppva Reader.law_ref("UK_ukpga_1981_14", "Public Passenger Vehicles Act", "s")
    @pesticides Reader.law_ref("UK_uksi_1986_1510", "Control of Pesticides Regulations", "reg")

    # SI 2013/1644 Sch.1: each table titled by its law, "Provision | Amendment"
    @sch1 ~S|<Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>Amendments extending to England and Wales and Scotland – Primary Legislation</Title></TitleBlock><Reference>Article 3</Reference><ScheduleBody><Tabular Orientation="portrait"><Title>The Transport Act 1968</Title><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Provision</th><th>Amendment</th></tr></thead><tbody><tr><td>section 96 (permitted driving time and periods of duty),</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In subsection (10)(b), for “the traffic commissioner for any area”, substitute “a traffic commissioner”.</Text></Para></td></tr><tr><td>section 98 (written records),</td><td>In subsection (3), for “the traffic commissioner for any area”, substitute “a traffic commissioner”.</td></tr></tbody></table></Tabular><Tabular Orientation="portrait"><Title>The Public Passenger Vehicles Act 1981</Title><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Provision</th><th>Amendment</th></tr></thead><tbody><tr><td>section 3 (traffic areas),</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>For subsection (3), substitute—</Text></Para><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><BlockAmendment Context="unknown" TargetClass="unknown" TargetSubClass="unknown" Format="double"><P2><Pnumber>3</Pnumber><P2para><Text>An order under this section may contain such provisions.</Text></P2para></P2></BlockAmendment></Para></td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|

    test "each row's amendment, at its provision in the table's law (SI 2013/1644 Sch.1)" do
      d =
        Doc.new("UK_uksi_2013_1644", [
          ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
          ~s(<Legislation><Secondary><Schedules>#{@sch1}</Schedules></Secondary></Legislation>)
        ])

      rules = Reader.read(d, "schedule-1", %{}, [@transport, @ppva])
      by = fn law -> rules |> Enum.filter(&(&1.amends == law)) |> Enum.flat_map(& &1.targets) end

      assert "s.96(10)(b)" in by.("UK_ukpga_1968_73")
      assert "s.98(3)" in by.("UK_ukpga_1968_73")
      refute "s.3(3)" in by.("UK_ukpga_1968_73")
      assert "s.3(3)" in by.("UK_ukpga_1981_14")
    end

    # SI 2013/1644 Sch.3: the Transport Act 2000's table runs on in a table
    # with no title or header of its own
    @sch3 ~S|<Schedule id="schedule-3"><Number>SCHEDULE 3</Number><ScheduleBody><Tabular Orientation="portrait"><Title>The Transport Act 2000</Title><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Provision</th><th>Amendment</th></tr></thead><tbody><tr><td>section 114 (quality partnership schemes),</td><td>In subsection (3C), for “the traffic commissioners are”, substitute “a traffic commissioner is”.</td></tr></tbody></table></Tabular><Tabular Orientation="portrait"><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><tbody><tr><td>section 132D (enhanced partnership schemes),</td><td>In subsection (7), for “the traffic commissioners”, substitute “a traffic commissioner”.</td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|
    @transport_2000 Reader.law_ref("UK_ukpga_2000_38", "Transport Act", "s")

    test "a table with no header runs on from the one before (SI 2013/1644 Sch.3)" do
      d =
        Doc.new("UK_uksi_2013_1644", [
          ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
          ~s(<Legislation><Secondary><Schedules>#{@sch3}</Schedules></Secondary></Legislation>)
        ])

      targets =
        d |> Reader.read("schedule-3", %{}, [@transport_2000]) |> Enum.flat_map(& &1.targets)

      assert "s.114(3C)" in targets
      assert "s.132D(7)" in targets
    end

    # SI 2013/1644 Sch.1, the Public Passenger Vehicles Act 1981: a provision
    # cell empty, or spanning the rows under it (a row with its amendment only)
    @spans ~S|<Schedule id="schedule-1"><ScheduleBody><Tabular Orientation="portrait"><Title>The Public Passenger Vehicles Act 1981</Title><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Provision</th><th>Amendment</th></tr></thead><tbody><tr><td>section 12 (PSV operators’ licences),</td><td>In subsection (2), for “the traffic commissioner” substitute “a traffic commissioner”.</td></tr><tr><td/><td>In subsection (4), for “the traffic commissioner” substitute “a traffic commissioner”.</td></tr><tr><td rowspan="2">section 15 (duration of licences),</td><td>In subsection (3), for “requests” substitute “asks”.</td></tr><tr><td>In subsection (4), for “The traffic commissioner” substitute “A traffic commissioner”.</td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|

    test "an empty or spanning provision cell is the provision above (SI 2013/1644 Sch.1)" do
      d =
        Doc.new("UK_uksi_2013_1644", [
          ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
          ~s(<Legislation><Secondary><Schedules>#{@spans}</Schedules></Secondary></Legislation>)
        ])

      targets = d |> Reader.read("schedule-1", %{}, [@ppva]) |> Enum.flat_map(& &1.targets)

      assert Enum.all?(["s.12(2)", "s.12(4)", "s.15(3)", "s.15(4)"], &(&1 in targets))
    end

    # SI 2013/1644 Sch.1, PPVA 1981 s.16(6): a cell's lead over a list
    @list ~S|<Schedule id="schedule-1"><ScheduleBody><Tabular Orientation="portrait"><Title>The Public Passenger Vehicles Act 1981</Title><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Provision</th><th>Amendment</th></tr></thead><tbody><tr><td>section 16 (conditions attached to licences),</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In subsection (6)—</Text></Para><OrderedList xmlns="http://www.legislation.gov.uk/namespaces/legislation" Decoration="parens" Type="alpha"><ListItem><Para><Text>for “the traffic commissioner by whom the licence was granted”, substitute “a traffic commissioner”; and</Text></Para></ListItem><ListItem><Para><Text>in the words following paragraph (c), for the words from “the traffic commissioner” to “duties”, substitute “the traffic commissioner dealing with the application”.</Text></Para></ListItem></OrderedList></td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|

    test "a cell's lead over its list: each item at the lead's provision (SI 2013/1644 Sch.1, PPVA s.16(6))" do
      d =
        Doc.new("UK_uksi_2013_1644", [
          ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
          ~s(<Legislation><Secondary><Schedules>#{@list}</Schedules></Secondary></Legislation>)
        ])

      rules = Reader.read(d, "schedule-1", %{}, [@ppva])

      assert length(rules) == 2
      assert Enum.all?(rules, &("s.16(6)" in &1.targets))
    end

    # SI 2008/960 Sch.3: "Column 1 | Column 2" over "Title | Extent of amendment"
    @sch3_960 ~S|<Schedule id="schedule-3"><Number>SCHEDULE 3</Number><TitleBlock><Title>AMENDMENTS</Title></TitleBlock><ScheduleBody><P><Text>The enactments and instruments listed in column 1 below shall be amended to the extent set out in column 2.</Text><Tabular Orientation="portrait"><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Column 1</th><th>Column 2</th></tr><tr><th>Title</th><th>Extent of amendment</th></tr></thead><tbody><tr><td>Explosives Act 1875 (c.17)</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In section 103, for “the Health and Safety Commission” substitute “the Health and Safety Executive”.</Text></Para></td></tr></tbody></table></Tabular></P></ScheduleBody></Schedule>|
    @explosives Reader.law_ref("UK_ukpga_1875_17", "Explosives Act", "s")

    test "a law column: \"Title | Extent of amendment\" (SI 2008/960 Sch.3)" do
      d =
        Doc.new("UK_uksi_2008_960", [
          ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
          ~s(<Legislation><Secondary><Schedules>#{@sch3_960}</Schedules></Secondary></Legislation>)
        ])

      assert [%{amends: "UK_ukpga_1875_17", targets: targets}] =
               Reader.read(d, "schedule-3", %{}, [@explosives])

      assert "s.103" in targets
    end

    # SI 2006/1177 Sch.: the law and its sections in the first cell, an
    # instruction per paragraph in the second, one with a list
    @byways ~S|<Schedule id="schedule"><ScheduleBody><Tabular Orientation="portrait"><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Column 1</th><th>Column 2</th></tr><tr><th>Provisions applying in relation to restricted byways</th><th>Amendments</th></tr></thead><tbody><tr><td>Road Traffic Regulation Act 1984, section 15 (so far as it relates to footpaths), section 22A and section 127.</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In section 15 (duration of orders and notices under section 14), in subsection (1)(a), after “bridleway,” there is inserted “restricted byway,”.</Text></Para><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In section 22A (traffic regulation on certain roads for purpose of conserving natural beauty), in subsection (1)(c), after “bridleway” there is inserted “, a restricted byway”.</Text></Para><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>In section 127 (footpaths, bridleways and byways open to all traffic)—</Text><OrderedList Decoration="parens" Type="alpha"><ListItem><Para><Text>in subsections (1) and (4), after “bridleway”, in both places where it occurs, there is inserted “, restricted byway”, and</Text></Para></ListItem><ListItem><Para><Text>in the sidenote, after “bridleways” there is inserted “, restricted byways”.</Text></Para></ListItem></OrderedList></Para></td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|
    @rtra Reader.law_ref("UK_ukpga_1984_27", "Road Traffic Regulation Act", "s")

    test "a cell's paragraphs, each its own instruction (SI 2006/1177 Sch., RTRA 1984)" do
      d =
        Doc.new("UK_uksi_2006_1177", [
          ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
          ~s(<Legislation><Secondary><Schedules>#{@byways}</Schedules></Secondary></Legislation>)
        ])

      targets = d |> Reader.read("schedule", %{}, [@rtra]) |> Enum.map(& &1.targets)

      assert Enum.any?(targets, &("s.15(1)(a)" in &1 and "s.22A(1)(c)" not in &1))
      assert Enum.any?(targets, &("s.22A(1)(c)" in &1 and "s.15(1)(a)" not in &1))
      assert Enum.any?(targets, &("s.127(1)" in &1))
    end

    # SI 2011/2131 Sch.4: "Regulations to be amended | Regulation … to be amended | Amendments to be made",
    # the law cell empty under its first row
    @sch4 ~S|<Schedule id="schedule-4"><Number>SCHEDULE 4</Number><TitleBlock><Title>Amendments</Title></TitleBlock><ScheduleBody><Tabular Orientation="portrait"><table xmlns="http://www.w3.org/1999/xhtml" cols="3"><thead><tr><th>Regulations to be amended</th><th>Regulation and Schedule to be amended</th><th>Amendments to be made</th></tr></thead><tbody><tr><td>The Control of Pesticides Regulations 1986</td><td>Regulation 2(1)</td><td>After the definition of “provisional approval” insert— ““Regulation 1107/2009” means Regulation (EC) No 1107/2009;”.</td></tr><tr><td/><td>Regulation 3(2)(d)</td><td><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>Omit the words after</Text></Para><Para xmlns="http://www.legislation.gov.uk/namespaces/legislation"><Text>“any plant protection product”.</Text></Para></td></tr></tbody></table></Tabular></ScheduleBody></Schedule>|

    test "a law column, its empty cells the law above (SI 2011/2131 Sch.4)" do
      d =
        Doc.new("UK_uksi_2011_2131", [
          ~s(<Legislation><Secondary><Body/></Secondary></Legislation>),
          ~s(<Legislation><Secondary><Schedules>#{@sch4}</Schedules></Secondary></Legislation>)
        ])

      targets = d |> Reader.read("schedule-4", %{}, [@pesticides]) |> Enum.flat_map(& &1.targets)

      assert "reg.2(1)" in targets
      assert "reg.3(2)(d)" in targets
    end
  end
end
