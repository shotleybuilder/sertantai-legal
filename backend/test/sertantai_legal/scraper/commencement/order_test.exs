defmodule SertantaiLegal.Scraper.Commencement.OrderTest do
  @moduledoc """
  CR-04: a commencement order as rules — the forms traced in the orders
  that gave no date (inline ranges, listed items, Schedule paragraphs via
  their introducing section, appointed-day sentences, qualifications).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order, Rule}

  @act %{law: "UK_ukpga_1993_43", title: "Railways Act", year: "1993"}

  defp order(body),
    do:
      Doc.new("UK_uksi_1994_571", [
        ~s(<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Railways Act 1993.</Text></P1para></P1>#{body}</Body></Secondary></Legislation>)
      ])

  defp lines(rules),
    do: Enum.map(rules, &(&1 |> Rule.to_text() |> String.split(" — UK_uksi") |> hd()))

  defp dated(rules, id),
    do:
      rules
      |> Evaluator.evaluate(Order.ref(id), Order.context())
      |> Map.take([:full_from, :partial_from])

  test "\"The appointed day for the coming into force of … is <date>\" (WSI 2017/546 art.3: Planning (Wales) Act 2015)" do
    act = %{law: "UK_anaw_2015_4", title: "Planning (Wales) Act", year: "2015"}

    rules =
      Order.rules(
        Doc.new("UK_wsi_2017_546", [
          ~S"""
          <Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t1">the 2015 Act</Term>” means the Planning (Wales) Act 2015.</Text></P1para></P1>
          <P1 id="article-2"><P1para><Text>The appointed day for the coming into force of section 54 of the 2015 Act, so far as it is not already in force, is 10 April 2017.</Text></P1para></P1>
          <P1 id="article-3"><P1para><Text>The appointed day for the coming into force of the following provisions of the 2015 Act so far as they are not already in force is 5 May 2017—</Text>
          <P2 id="article-3-a"><P2para><Text>section 39;</Text></P2para></P2>
          <P2 id="article-3-b"><P2para><Text>sections 47 and 48;</Text></P2para></P2></P1para></P1>
          </Body></Secondary></Legislation>
          """
        ]),
        act
      )

    # a Welsh Act's provisions extend to Wales: the order's W covers them
    welsh = Map.put(Order.context(), :extent, "W")
    at = &Evaluator.evaluate(rules, Order.ref(&1), welsh).full_from

    assert at.("section-47") == ~D[2017-05-05]
    assert at.("section-39") == ~D[2017-05-05]
    assert at.("section-54") == ~D[2017-04-10]
    assert Enum.all?(rules, &(&1.source.law == "UK_wsi_2017_546"))
  end

  test "a definition with no Term markup names the Act (“the 2015 Act” (“Deddf 2015”) means …: WSI 2017/546 art.1(2), art.2)" do
    act = %{law: "UK_anaw_2015_4", title: "Planning (Wales) Act", year: "2015"}

    rules =
      Order.rules(
        Doc.new("UK_wsi_2017_546", [
          ~S"""
          <Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order—</Text><UnorderedList Class="Definition"><ListItem><Para><Text>“the 2015 Act” (“<Emphasis>Deddf 2015</Emphasis>”) means the Planning (Wales) Act 2015.</Text></Para></ListItem></UnorderedList></P1para></P1>
          <P1 id="article-2"><P1para><Text>The appointed day for the coming into force of section 54 of the 2015 Act, so far as it is not already in force, is 10 April 2017.</Text></P1para></P1>
          </Body></Secondary></Legislation>
          """
        ]),
        act
      )

    welsh = Map.put(Order.context(), :extent, "W")
    assert Evaluator.evaluate(rules, "s.54", welsh).full_from == ~D[2017-04-10]
  end

  test "ref/1: an amending provision's id in the Act's grammar" do
    assert Order.ref("section-36-3") == "s.36(3)"
    assert Order.ref("schedule-11-paragraph-137-a") == "sch.11.para.137(a)"
    assert Order.ref("schedule-34") == "sch.34"
  end

  test "ref/1: an unnumbered Schedule and a paragraph inside a Schedule's Part (CV-S02a K10; CV-S05 round 13)" do
    assert Order.ref("schedule") == "sch"
    assert Order.ref("schedule-part-I") == "sch.pt.I"
    assert Order.ref("schedule-paragraph-1") == "sch.para.1"
    assert Order.ref("schedule-paragraph-14-2") == "sch.para.14(2)"
    assert Order.ref("schedule-part-I-paragraph-3") == "sch.pt.I.para.3"
    assert Order.ref("schedule-part") == "sch"
    # (the triple where the id holds the Part, Jason 2026-10-27: unique where
    # numbering restarts in each Part; nested Parts kept)
    assert Order.ref("schedule-4-part-2-paragraph-3") == "sch.4.pt.2.para.3"
    assert Order.ref("schedule-2-part-2-part-3-paragraph-142-a") == "sch.2.pt.2.pt.3.para.142(a)"
    assert Order.context().ancestors.("sch.para.3") == ["sch"]
    assert Order.context().ancestors.("sch.4.para.3") == ["sch.4"]
    assert Order.context().ancestors.("sch.4.pt.2.para.3") == ["sch.4.pt.2", "sch.4"]
  end

  test "an inline range of sections and a Schedule (SI 1994/571 art. 6)" do
    rules =
      Order.rules(
        order(
          ~S|<P1 id="article-6"><P1para><Text>Sections 17 to 22 of, and Schedule 4 to, the Act shall come into force on 2nd April 1994.</Text></P1para></P1>|
        ),
        @act
      )

    assert lines(rules) == ["s.17..s.22, sch.4 — 1994-04-02 — everywhere, fully — order_date"]
    assert %{full_from: ~D[1994-04-02]} = dated(rules, "section-20-1")
    assert %{full_from: ~D[1994-04-02]} = dated(rules, "schedule-4-paragraph-3")
    assert %{full_from: nil} = dated(rules, "section-36-3")
  end

  test "a list under the statement; Schedule paragraphs after \"the following paragraphs of Schedule 11—\" (SI 2006/2541)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><Text>The following provisions of the Act come into force on 1st October 2006—</Text>
        <UnorderedList><ListItem><Para><Text>section 1(4);</Text></Para></ListItem>
        <ListItem><Para><Text>section 11, so far as it has not already been commenced;</Text></Para></ListItem>
        <ListItem><Para><Text>section 105(1), so far as it has not already been commenced, and the following paragraphs of Schedule 11—</Text></Para></ListItem>
        <ListItem><Para><Text>paragraphs 1 to 33;</Text></Para></ListItem>
        <ListItem><Para><Text>paragraph 34, so far as it has not already been commenced;</Text></Para></ListItem>
        <ListItem><Para><Text>paragraphs 135 to 152;</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert %{full_from: ~D[2006-10-01]} = dated(rules, "section-11-2")
    assert %{full_from: ~D[2006-10-01]} = dated(rules, "schedule-11-paragraph-137-a")
    assert %{full_from: ~D[2006-10-01]} = dated(rules, "schedule-11-paragraph-34")
    assert %{full_from: nil} = dated(rules, "schedule-11-paragraph-60")
  end

  test "a section brought in so far as it relates to Schedule paragraphs: the paragraphs fully, the section partly (SI 1995/1983)" do
    rules =
      Order.rules(
        order(
          ~S|<P1 id="article-3"><P1para><Text>The following provisions of the Act shall come into force on 21st September 1995— section 116 in so far as it relates to paragraphs 2(1) to (3) of Schedule 21;</Text></P1para></P1>|
        ),
        @act
      )

    assert %{full_from: ~D[1995-09-21]} = dated(rules, "schedule-21-paragraph-2-2")
    assert %{full_from: nil} = dated(rules, "schedule-21-paragraph-2-4")
    assert %{full_from: nil, partial_from: ~D[1995-09-21]} = dated(rules, "section-116")
  end

  test "an appointed-day sentence; \"in Schedule 13 to the Act, paragraphs …\" with asides (SI 1996/323 art. 4)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-4"><P2 id="article-4-1"><P2para><Text>Subject to paragraph (2) below, 1st April 1996 is the day appointed for the coming into force of—</Text>
        <P3 id="article-4-1-a"><Pnumber>a</Pnumber><P3para><Text>in Schedule 13 to the Act, paragraphs 1, 2, 4 (so far as not already in force), 5, 6, 8 to 26 and 167(3);</Text></P3para></P3></P2para></P2></P1>
        """),
        @act
      )

    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-13-paragraph-167-3")
    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-13-paragraph-4")
    assert %{full_from: nil} = dated(rules, "schedule-13-paragraph-7")
  end

  test "qualified items are partial; another law's sections are not the Act's" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><Text>The following provisions of the Act come into force on 6th April 2009—</Text>
        <UnorderedList><ListItem><Para><Text>section 196 and paragraphs 1, 3 to 6 of Schedule 10 so far as they relate to any appeal under section 78 of the Town and Country Planning Act 1990;</Text></Para></ListItem>
        <ListItem><Para><Text>section 195 in relation to Wales.</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert %{partial_from: ~D[2009-04-06], full_from: nil} =
             dated(rules, "schedule-10-paragraph-4")

    assert %{full_from: nil} = dated(rules, "section-78")
    assert [%Rule{territory: "W"}] = Enum.filter(rules, &(&1.scope == ["s.195"]))
  end

  test "an order commencing another law: no rules" do
    other = %{law: "UK_ukpga_1990_8", title: "Town and Country Planning Act", year: "1990"}

    assert Order.rules(
             order(
               ~S|<P1 id="article-6"><P1para><Text>Sections 17 to 22 of the Act shall come into force on 2nd April 1994.</Text></P1para></P1>|
             ),
             other
           ) == []
  end

  test "bare paragraph numbers after \"the following paragraphs of Schedule 22—\" (SI 1996/186)" do
    rules =
      Order.rules(
        order(
          ~S|<P1 id="article-3"><P1para><Text>The following provisions of the Act shall come into force on 1st April 1996— section 120(1) in so far as it relates to the following paragraphs of Schedule 22— 1, 3, 5 to 12, 86(2), 88;</Text></P1para></P1>|
        ),
        @act
      )

    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-22-paragraph-86-2")
    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-22-paragraph-7")
    assert %{full_from: nil} = dated(rules, "schedule-22-paragraph-87")
  end

  test "dated from the order's making (SI 2012/873: \"the day after this Order is made\")" do
    d =
      Doc.new("UK_uksi_2012_873", [
        ~S|<Legislation><ukm:Metadata xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"><ukm:SecondaryMetadata><ukm:Made Date="2012-03-20"/></ukm:SecondaryMetadata></ukm:Metadata><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Railways Act 1993.</Text></P1para></P1><P1 id="article-2"><P1para><Text>The following provisions of the Act come into force the day after this Order is made—</Text><UnorderedList><ListItem><Para><Text>section 3 (framework regulations);</Text></Para></ListItem></UnorderedList></P1para></P1></Body></Secondary></Legislation>|
      ])

    assert %{full_from: ~D[2012-03-21]} = dated(Order.rules(d, @act), "section-3-1")
  end

  test "territory: a statement's place reaches its items; a Welsh order commences in relation to Wales" do
    head =
      Order.rules(
        order(
          ~S|<P1 id="article-2"><P1para><Text>The following provisions of the Act come into force in relation to England on 6th April 2015— section 8 (charges schemes);</Text></P1para></P1>|
        ),
        @act
      )

    assert [%Rule{territory: "E", scope: ["s.8"]}] = head

    welsh =
      Order.rules(
        Doc.new("UK_wsi_2019_1", [
          ~S|<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Railways Act 1993.</Text></P1para></P1><P1 id="article-2"><P1para><Text>Section 8 of the Act comes into force on 1st April 2019.</Text></P1para></P1></Body></Secondary></Legislation>|
        ]),
        @act
      )

    assert [%Rule{territory: "W"}] = welsh

    ctx = Map.put(Order.context(), :extent, "E+W")
    r = Evaluator.evaluate(head ++ welsh, "s.8(1)", ctx)
    assert %{partial_from: ~D[2015-04-06], full_from: ~D[2019-04-01]} = r
  end

  test "a heading \"as follows\" commences nothing itself; a section of the amended law isn't the Act's (Water Act 2014 s.8)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><Text>The following provisions of the Act come into force on 6th April 2015—</Text>
        <UnorderedList><ListItem><Para><Text>section 8 (bulk supply of water by water undertakers) as follows—</Text></Para></ListItem>
        <ListItem><Para><Text>section 8(1) so far as it inserts section 40J (duty to provide information about bulk supplies) into the 1991 Act;</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert [%Rule{scope: ["s.8(1)"], purposes: :in_relation_to}] = rules
  end

  test "\"the following provisions of Schedule 22—\", \"provisions in Schedules 13 and 14 … specified\": a subset, never the whole Schedule" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-3"><P1para><Text>The following provisions of the Act shall come into force on 21st September 1995—</Text>
        <UnorderedList><ListItem><Para><Text>section 120(1) in so far as it relates to the following provisions of Schedule 22— paragraphs 37(1) and (4), 38;</Text></Para></ListItem>
        <ListItem><Para><Text>section 180 of the Act, so far as it relates to the provisions in Schedules 13 and 14 to the Act specified in sub-paragraphs (c) and (d) below;</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert %{full_from: ~D[1995-09-21]} = dated(rules, "schedule-22-paragraph-38")
    assert %{full_from: nil} = dated(rules, "schedule-22-paragraph-109")
    assert %{full_from: nil} = dated(rules, "schedule-13-paragraph-119-7-a")
  end

  test "\"the provisions of … Schedules 15, 16 and 18 to, the Act which are specified in Schedule 3 to this Order\": a subset (SI 1995/2490)" do
    rules =
      Order.rules(
        order(
          ~S|<P1 id="article-5"><P1para><Text>The provisions of Part VII of, and Schedules 15, 16 and 18 to, the Act which are specified in Schedule 3 to this Order shall come into force on 1st October 1995.</Text></P1para></P1>|
        ),
        @act
      )

    assert %{full_from: nil} = dated(rules, "schedule-16-paragraph-3")
  end

  test "an order made for one territory says so in its title (SI 2000/340, \"(England) Order\")" do
    d =
      Doc.new("UK_uksi_2000_340", [
        ~S|<Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Environment Act 1995 (Commencement No. 16 and Saving Provision) (England) Order 2000</dc:title><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Railways Act 1993.</Text></P1para></P1><P1 id="article-2"><P1para><Text>Section 57 of the Act comes into force on 1st April 2000.</Text></P1para></P1></Body></Secondary></Legislation>|
      ])

    assert [%Rule{territory: "E"}] = Order.rules(d, @act)
  end

  test "\"in so far as that sub-paragraph is not already in force\" is full (SI 1996/186)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-3"><P1para><Text>The following provisions of the Act shall come into force on 1st April 1996—</Text>
        <UnorderedList><ListItem><Para><Text>section 120(1) in so far as it relates to the following paragraphs of Schedule 22—</Text></Para></ListItem>
        <ListItem><Para><Text>1, 29(1) in so far as that sub-paragraph is not already in force, 140</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-22-paragraph-140")
  end

  test "a commencement table's subject column is no purpose (SI 1997/1539: \"Minor and consequential amendments\")" do
    rules =
      Order.rules(
        order(~S"""
        <Schedules><Schedule id="schedule"><TitleBlock><Title>Provisions coming into force on 17th July 1997</Title></TitleBlock><ScheduleBody><Tabular><table><tbody>
        <tr><td>Schedule 6 so far as it is not already in force</td><td>Minor and consequential amendments</td></tr>
        <tr><td>Section 8</td><td>For the purposes of making regulations</td></tr>
        </tbody></table></Tabular></ScheduleBody></Schedule></Schedules>
        """),
        @act
      )

    assert %{full_from: ~D[1997-07-17]} = dated(rules, "schedule-6-paragraph-20")
    assert %{full_from: nil, partial_from: ~D[1997-07-17]} = dated(rules, "section-8")
  end

  test "CR-07: an older order lists its items first and states the date last; Parts are items; \"so far as relating to the entries\" names no other law's sections (SI 1982/1217)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><Text>The following provisions of the Act, namely—</Text>
        <P3 id="article-2-a"><P3para><Text>Part I so far as not already in force;</Text></P3para></P3>
        <P3 id="article-2-b"><P3para><Text>Schedule 17 so far as relating to the entries in Part II thereof as respects sections 27 to 35 and 38 of the Countryside Act 1968,</Text></P3para></P3>
        <Text>shall come into force on 28th September 1982.</Text></P1para></P1>
        """),
        @act
      )

    ctx = Map.put(Order.context(), :ancestors, fn _ -> ["pt.I"] end)
    assert %{full_from: ~D[1982-09-28]} = Evaluator.evaluate(rules, "s.3(1)", ctx)
    refute Enum.any?(rules, &("s.27..s.35" in List.wrap(&1.scope)))
  end

  test "CR-07: another law's section whose title has small words is not the Act's (\"the repeal of section 1 of the Control of Pollution Act 1974\": SI 1994/1096)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><Text>The following provisions of the Act shall come into force on 1st May 1994—</Text>
        <UnorderedList><ListItem><Para><Text>section 54;</Text></Para></ListItem>
        <ListItem><Para><Text>the repeal of section 1 of the Control of Pollution Act 1974;</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert %{full_from: ~D[1994-05-01]} = dated(rules, "section-54")
    assert %{full_from: nil} = dated(rules, "section-1")
  end

  test "CR-08: a table's \"Schedule 6, paragraphs … and 20\"; \"to the extent that it relates to\" is partial (SI 1997/1082)" do
    rules =
      Order.rules(
        order(~S"""
        <Schedules><Schedule id="schedule"><TitleBlock><Title>Provisions coming into force on 23rd March 1997</Title></TitleBlock><ScheduleBody><Tabular><table><tbody>
        <tr><td>Section 29(1), to the extent that it relates to the provisions of Schedule 6 specified below</td><td>Minor and consequential amendments</td></tr>
        <tr><td>Schedule 6, paragraphs 18(1), 19(1) and 20</td><td>Minor and consequential amendments</td></tr>
        </tbody></table></Tabular></ScheduleBody></Schedule></Schedules>
        """),
        @act
      )

    assert %{full_from: ~D[1997-03-23]} = dated(rules, "schedule-6-paragraph-20")
    assert %{full_from: nil, partial_from: ~D[1997-03-23]} = dated(rules, "section-29-1")
  end

  test "CR-08: a wrapped list's tail \"… 29 and 30 of Schedule 15\" is paragraphs, not the Schedule (SI 1991/1042)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><Text>The following provisions of the Act shall come into force on 1st April 1991—</Text>
        <UnorderedList><ListItem><Para><Text>section 162(1) in so far as it relates to paragraphs 1, 2(1) (except in so far as it relates to the</Text></Para></ListItem>
        <ListItem><Para><Text>Pollution Act 1974) and (3), 20, 23, 29 and 30 of Schedule 15;</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert %{full_from: ~D[1991-04-01]} = dated(rules, "schedule-15-paragraph-30")
    assert %{full_from: nil} = dated(rules, "schedule-15-paragraph-31-2")
  end

  test "AR-12: \"the provisions of the Act specified in Part II of Schedule 1 to this Order\" are the order's Schedule's, each Part dated by its title (SI 1999/2830)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><P2 id="article-2-1"><P2para><Text>The provisions of the Act specified in Part I of Schedule 1 to this Order shall come into force on 25th October 1999.</Text></P2para></P2><P2 id="article-2-2"><P2para><Text>The provisions of the Act specified in Part II of Schedule 1 to this Order shall come into force on 15th December 1999.</Text></P2para></P2></P1para></P1>
        <Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><Reference>Article 2(1) and (2)</Reference><ScheduleBody>
        <Part id="schedule-1-part-I"><Number>PART I</Number><Title>PROVISIONS COMING INTO FORCE ON 25th OCTOBER 1999</Title><Tabular><table><tbody>
        <tr><td>Section 2 and Schedule 2</td><td>Detriment related to union membership</td></tr>
        </tbody></table></Tabular></Part>
        <Part id="schedule-1-part-II"><Number>PART II</Number><Title>PROVISIONS COMING INTO FORCE ON 15th DECEMBER 1999</Title><Tabular><table><tbody>
        <tr><td>Section 7 and Part I of Schedule 4</td><td>Maternity and parental leave</td></tr>
        <tr><td>Section 9 and Part III of Schedule 4</td><td>Consequential amendments</td></tr>
        </tbody></table></Tabular></Part>
        </ScheduleBody></Schedule></Schedules>
        """),
        @act
      )

    assert %{full_from: ~D[1999-10-25]} = dated(rules, "section-2")
    assert %{full_from: ~D[1999-10-25]} = dated(rules, "schedule-2-paragraph-3")
    assert %{full_from: ~D[1999-12-15]} = dated(rules, "section-7")
    assert %{full_from: ~D[1999-12-15]} = dated(rules, "schedule-4-part-III")
    # the order's own Schedule 1 is never the Act's; Part III of Schedule 4
    # is not its Part I nor the whole Schedule
    assert %{full_from: nil, partial_from: nil} = dated(rules, "schedule-1-paragraph-1")
    assert %{full_from: nil, partial_from: nil} = dated(rules, "schedule-4-paragraph-10")
    assert Order.ref("schedule-4-part-III") == "sch.4.pt.III"
  end

  test "AR-14: \"Subsections (1) to (5) of section 18\", \"sub-sections (2), (3) and (4) of section 34\" are those subsections, not the section (SI 1999/2830, SI 2004/1572)" do
    rules =
      Order.rules(
        order(~S"""
        <P1 id="article-2"><P1para><Text>The following provisions of the Act shall come into force on 1st July 2004—</Text>
        <UnorderedList><ListItem><Para><Text>Subsections (1) to (5) of section 18;</Text></Para></ListItem>
        <ListItem><Para><Text>sub-sections (2), (3) and (4) of section 34 (compulsory purchase);</Text></Para></ListItem>
        <ListItem><Para><Text>subsection (1) of section 22 (establishment).</Text></Para></ListItem></UnorderedList></P1para></P1>
        """),
        @act
      )

    assert %{full_from: ~D[2004-07-01]} = dated(rules, "section-18-3")
    assert %{full_from: ~D[2004-07-01]} = dated(rules, "section-34-4")
    assert %{full_from: ~D[2004-07-01]} = dated(rules, "section-22-1")
    assert %{full_from: nil} = dated(rules, "section-18-6")
    assert %{full_from: nil} = dated(rules, "section-34-1")
    assert %{full_from: nil} = dated(rules, "section-22-2")
  end

  test "AR-15: a table row with no subject cell is an item unless rows under it continue it (SI 1999/2830: \"Section 31 and in Schedule 7, paragraphs 1, 2, 5 (… into the Employment Agencies Act 1973), 6 and 8\")" do
    rules =
      Order.rules(
        order(~S"""
        <Schedules><Schedule id="schedule"><TitleBlock><Title>Provisions coming into force on 25th October 1999</Title></TitleBlock><ScheduleBody><Tabular><table><tbody>
        <tr><td>Section 30</td><td>Partnerships at work</td></tr>
        <tr><td>Section 31 and in Schedule 7, paragraphs 1, 2, 5 (to the extent that it inserts section 11A into the Employment Agencies Act 1973), 6 and 8</td></tr>
        <tr><td>Section 32</td><td>Employment outside Great Britain</td></tr>
        <tr><td>Section 44</td><td/></tr>
        <tr><td>paragraph 3</td><td>Repeals</td></tr>
        <tr><td>Section 50</td></tr>
        </tbody></table></Tabular></ScheduleBody></Schedule></Schedules>
        """),
        @act
      )

    # dated (partly: "to the extent that it inserts …" is read over the whole
    # line — the open bug of a qualifier on one item of a list)
    assert %{full_from: f, partial_from: p} = dated(rules, "section-31")
    assert ~D[1999-10-25] in [f, p]
    assert %{full_from: f, partial_from: p} = dated(rules, "schedule-7-paragraph-8")
    assert ~D[1999-10-25] in [f, p]
    assert %{full_from: ~D[1999-10-25]} = dated(rules, "section-32")
    assert %{full_from: ~D[1999-10-25]} = dated(rules, "section-50")
    # a heading row continued by the rows under it is not an item itself
    refute Enum.any?(rules, &(&1.source.text == "Section 44 |"))
    assert Enum.any?(rules, &(&1.source.text == "Section 44 paragraph 3 | Repeals"))
  end

  test "AR measure: \"Paragraphs 1 to 27(3) and 28 to 43 of Schedule 7, and section 22(1) so far as it relates thereto\": the paragraphs fully, the section partly (SI 1996/396)" do
    rules =
      Order.rules(
        order(~S"""
        <Schedules><Schedule id="schedule"><TitleBlock><Title>Provisions coming into force on 1st April 1996</Title></TitleBlock><ScheduleBody><Tabular><table><tbody>
        <tr><td>Paragraphs 1 to 3 and 5 of Schedule 7, and section 22(1) so far as it relates thereto</td><td>Highways</td></tr>
        <tr><td>Paragraph 13 of Schedule 2 and section 1(3) so far as it relates thereto</td><td>Definition of “county” for the purposes of the Parliamentary Constituencies Act 1986.</td></tr>
        </tbody></table></Tabular></ScheduleBody></Schedule></Schedules>
        """),
        @act
      )

    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-7-paragraph-2")
    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-7-paragraph-5")
    assert %{full_from: nil, partial_from: ~D[1996-04-01]} = dated(rules, "section-22-1")
    assert %{full_from: ~D[1996-04-01]} = dated(rules, "schedule-2-paragraph-13")
    assert %{full_from: nil, partial_from: ~D[1996-04-01]} = dated(rules, "section-1-3")
  end

  test "AR-15: \"the repeals listed in the said Part I\" is the order's Part, not the Act's; \"for the purposes only of\" is partial (SI 1997/3114 art. 3)" do
    rules =
      Order.rules(
        order(
          ~S|<P1 id="article-3"><P1para><Text>The provisions of the Act specified in Part I of the Schedule to this Order shall come into force on 17th December 1997, save that:</Text><P3 id="article-3-a"><Pnumber>a</Pnumber><P3para><Text>subsections (3) and (4) of section 2 shall come into force on that date for the purposes only of making a compensation scheme, and</Text></P3para></P3><P3 id="article-3-b"><Pnumber>b</Pnumber><P3para><Text>subsection (7) of section 2 shall come into force on that date to the extent only that it relates to the repeals listed in the said Part I.</Text></P3para></P3></P1para></P1>|
        ),
        @act
      )

    refute Enum.any?(rules, &("pt.I" in &1.scope))
    assert %{full_from: nil, partial_from: ~D[1997-12-17]} = dated(rules, "section-2-7")
    assert %{full_from: nil, partial_from: ~D[1997-12-17]} = dated(rules, "section-2-3")
  end

  test "LR-43: \"so far as it is not yet in force\" is full (SI 1992/1630)" do
    rules =
      Order.rules(
        order(
          ~S|<P1 id="article-2"><P1para><Text>The following provisions of the Act shall come into force on 27th July 1992— section 4, so far as it is not yet in force;</Text></P1para></P1>|
        ),
        @act
      )

    assert %{full_from: ~D[1992-07-27]} = dated(rules, "section-4-1")
  end

  describe "CV-S04: the whole Act" do
    test "the Act named as the item: all of it (SI 1973/28: EMAS Act 1972)" do
      act = %{
        law: "UK_ukpga_1972_28",
        title: "Employment Medical Advisory Service Act",
        year: "1972"
      }

      rules =
        Order.rules(
          Doc.new("UK_uksi_1973_28", [
            ~S"""
            <Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>The Employment Medical Advisory Service Act 1972 shall come into operation on 1st February 1973.</Text></P1para></P1>
            <P1 id="article-2"><P1para><Text>This Order may be cited as the Employment Medical Advisory Service Act 1972 (Commencement) Order 1973.</Text></P1para></P1>
            </Body></Secondary></Legislation>
            """
          ]),
          act
        )

      assert lines(rules) == ["all — 1973-02-01 — everywhere, fully — order_date"]
    end

    test "all but the provisions another paragraph lists, so far as not in force (SI 2008/401: CMCHA 2007)" do
      act = %{
        law: "UK_ukpga_2007_19",
        title: "Corporate Manslaughter and Corporate Homicide Act",
        year: "2007"
      }

      rules =
        Order.rules(
          Doc.new("UK_uksi_2008_401", [
            ~S"""
            <Legislation><Secondary><Body><P1 id="article-2"><P1para>
            <P2 id="article-2-1"><Pnumber>1</Pnumber><P2para><Text>Apart from the provisions mentioned in paragraph (2), the Corporate Manslaughter and Corporate Homicide Act 2007 shall, to the extent that it is not already in force, come into force on 6th April 2008.</Text></P2para></P2>
            <P2 id="article-2-2"><Pnumber>2</Pnumber><P2para><Text>Those provisions are—</Text>
            <P3 id="article-2-2-a"><P3para><Text>section 2(1)(d) (duty owed to a person in custody etc. to be a relevant duty of care);</Text></P3para></P3>
            <P3 id="article-2-2-b"><P3para><Text>section 10 (power to order conviction etc to be publicised).</Text></P3para></P3></P2para></P2>
            </P1para></P1></Body></Secondary></Legislation>
            """
          ]),
          act
        )

      assert lines(rules) == [
               "all except s.2(1)(d), s.10 — 2008-04-06 — everywhere, fully — order_date"
             ]

      at = &Evaluator.evaluate(rules, &1, Order.context()).full_from
      assert at.("s.1") == ~D[2008-04-06]
      assert at.("s.10") == nil
    end

    test "an order never commences itself (NISR 2012/286)" do
      act = %{law: "UK_uksi_1994_571", title: "Railways (Commencement) Order", year: "1994"}

      assert Order.rules(
               order(
                 ~s(<P1 id="article-2"><P1para><Text>Section 1 of the Act shall come into force on 1st April 1994.</Text></P1para></P1>)
               ),
               act
             ) == []
    end
  end

  describe "CV-S04: Schedule table items (SI 1974/1439, HSWA 1974)" do
    @hswa %{law: "UK_ukpga_1974_37", title: "Health and Safety at Work etc. Act", year: "1974"}

    defp hswa_rules(rows) do
      tr = Enum.map_join(rows, "", fn {a, b} -> "<tr><td>#{a}</td><td>#{b}</td></tr>" end)

      Order.rules(
        Doc.new("UK_uksi_1974_1439", [
          ~s(<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Health and Safety at Work etc. Act 1974.</Text></P1para></P1></Body><Schedules><Schedule id="schedule"><TitleBlock><Title>Provisions coming into operation on 1st April 1975</Title></TitleBlock><ScheduleBody><Tabular><table><tbody>#{tr}</tbody></table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>)
        ]),
        @hswa
      )
    end

    test "\"(except so far as already in operation)\", \"(except as aforesaid)\": the rest, fully" do
      rules =
        hswa_rules([
          {"Section 47 (except so far as already in operation).", "Civil liability."},
          {"Section 53 (except as aforesaid).", "General interpretation of Part I."}
        ])

      assert Enum.all?(rules, &Rule.full?/1)
      assert Enum.map(rules, & &1.scope) == [["s.47"], ["s.53"]]
    end

    test "\"33(1)(a) and (b)\": the sibling at its own depth" do
      assert [%{scope: ["s.33(1)(a)", "s.33(1)(b)"]}] =
               hswa_rules([{"Section 33(1)(a) and (b).", "Offences."}])
    end

    test "another law's provisions after its title and a dash are not the Act's; \"the following repeals\" is part of a Schedule" do
      assert [%{scope: ["sch.10"], purposes: :in_relation_to}] =
               hswa_rules([
                 {"Schedule 10, the following repeals:— The Employment Medical Advisory Service Act 1972- sections 1 and 6 and Schedule 1.",
                  "Repeals."}
               ])
    end
  end

  describe "CV-S04 orders catalogue" do
    defp doc_of(law, body, schedules \\ ""),
      do:
        Doc.new(law, [
          ~s|<Legislation><Secondary><Body>#{body}</Body>#{schedules}</Secondary></Legislation>|
        ])

    test "\"18 March 2011 is the appointed day …\": the day kept, the appointed day read (WSI 2011/824)" do
      act = %{law: "UK_ukpga_2008_23", title: "Children and Young Persons Act", year: "2008"}

      rules =
        Order.rules(
          doc_of(
            "UK_wsi_2011_824",
            ~s|<P1 id="article-2"><P1para><Text>18 March 2011 is the appointed day for the coming into force of the following provisions of the Children and Young Persons Act 2008—</Text><P2 id="article-2-a"><P2para><Text>section 21(1);</Text></P2para></P2></P1para></P1>|
          ),
          act
        )

      assert [%{scope: ["s.21(1)"], when: {:date, ~D[2011-03-18]}}] = rules
    end

    test "\"The 1989 Act, so far as not already in force, …\"; a bracketed alias (SI 1997/134, SI 1999/161)" do
      act = %{law: "UK_ukpga_1989_38", title: "Employment Act", year: "1989"}

      assert [%{scope: :all, when: {:date, ~D[1997-03-03]}}] =
               Order.rules(
                 doc_of(
                   "UK_uksi_1997_134",
                   ~s|<P1 id="article-1"><P1para><Text>This Order may be cited as the Employment Act 1989 (Commencement No. 2) Order 1997.</Text></P1para></P1><P1 id="article-2"><P1para><Text>The 1989 Act, so far as not already in force, shall come into force on 3rd March 1997.</Text></P1para></P1>|
                 ),
                 act
               )

      act = %{law: "UK_ukpga_1998_17", title: "Petroleum Act", year: "1998"}

      assert [%{scope: :all}] =
               Order.rules(
                 doc_of(
                   "UK_uksi_1999_161",
                   ~s|<P1 id="article-2"><P1para><Text>The Petroleum Act 1998 (hereinafter referred to as “the Act”) shall come into force on 15th February 1999.</Text></P1para></P1>|
                 ),
                 act
               )
    end

    test "a table's Schedule from its title (SI 1991/2905: \"EXTENT OF COMMENCEMENT OF SCHEDULE 7\")" do
      act = %{law: "UK_ukpga_1991_34", title: "Planning and Compensation Act", year: "1991"}

      rules =
        Order.rules(
          doc_of(
            "UK_uksi_1991_2905",
            ~s|<P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Planning and Compensation Act 1991.</Text></P1para></P1>|,
            ~s|<Schedules><Schedule id="schedule"><TitleBlock><Title>Extent of commencement of Schedule 7: provisions coming into force on 2nd January 1992</Title></TitleBlock><ScheduleBody><Tabular><table><tbody><tr><td>Paragraphs 2 and 4</td><td></td></tr><tr><td>Paragraph 7</td><td>Amendments</td></tr></tbody></table></Tabular></ScheduleBody></Schedule></Schedules>|
          ),
          act
        )

      assert Enum.any?(rules, &("sch.7.para.7" in List.wrap(&1.scope)))
    end
  end

  describe "CV-S04 agent round 2" do
    test "N1: a bare Schedule list's own qualifier stays on its item (SI 1996/186 reg.3)" do
      act = %{law: "UK_ukpga_1995_25", title: "Environment Act", year: "1995"}

      rules =
        Order.rules(
          Doc.new("UK_uksi_1996_186", [
            ~s|<Legislation><Secondary><Body><P1 id="article-3"><P1para><Text>The following provisions of the Environment Act 1995 shall come into force on 1st April 1996—</Text><P2 id="article-3-a"><P2para><Text>section 120(1) in so far as it relates to the following paragraphs of Schedule 22— 1, 3, 29(1) in so far as it is not already in force, 30, 32 to 35.</Text></P2para></P2></P1para></P1></Body></Secondary></Legislation>|
          ]),
          act
        )

      para30 = Enum.find(rules, &("sch.22.para.30" in List.wrap(&1.scope)))
      assert para30 && Rule.full?(para30)
    end

    test "N1: \"Section 33 (except subsection (1)(a) and (b))\" is the section but those (SI 1974/1439)" do
      act = %{law: "UK_ukpga_1974_37", title: "Health and Safety at Work etc. Act", year: "1974"}

      [rule] =
        Order.rules(
          Doc.new("UK_uksi_1974_1439", [
            ~s|<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Health and Safety at Work etc. Act 1974.</Text></P1para></P1></Body><Schedules><Schedule id="schedule-2"><TitleBlock><Title>Provisions coming into operation on 1st January 1975</Title></TitleBlock><ScheduleBody><Tabular><table><tbody><tr><td>Section 33 (except subsection (1)(a) and (b)).</td><td>Offences.</td></tr></tbody></table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>|
          ]),
          act
        )

      assert rule.scope == ["s.33"] and rule.except == ["s.33(1)(a)", "s.33(1)(b)"] and
               Rule.full?(rule)
    end
  end

  describe "CV-S04 agent round 3" do
    test "\"The day appointed for the purpose of section 18(2) … shall be D\": what s.18(2) leaves to it (SI 1996/218)" do
      act = %{law: "UK_ukpga_1995_45", title: "Gas Act", year: "1995"}

      rules =
        Order.rules(
          Doc.new("UK_uksi_1996_218", [
            ~s|<Legislation><Secondary><Body><P1 id="article-2"><P1para><Text>The day appointed for the purpose of section 18(2) of the Gas Act 1995 shall be 1st March 1996.</Text></P1para></P1></Body></Secondary></Legislation>|
          ]),
          act
        )

      own =
        Rule.new(
          commences: "UK_ukpga_1995_45",
          scope: :all,
          except: ["s.18", "s.13"],
          when: {:appointed, "by order"},
          source: %{law: "UK_ukpga_1995_45", ref: "s.18(2)", text: "This Act, except— …"},
          treatment: :by_order
        )

      assert [%{scope: :all, except: ["s.18", "s.13"], when: {:date, ~D[1996-03-01]}}] =
               Order.resolve_appointed_for(rules, [own])

      assert Order.resolve_appointed_for(rules, []) == []
    end
  end

  describe "CV-S04 agent round 3: order items" do
    test "\"insofar\": a whole-Act commencement (SI 1998/1542) and an item partly (SI 2006/1680)" do
      act = %{law: "UK_ukpga_1997_42", title: "Police (Health and Safety) Act", year: "1997"}

      assert [%{scope: :all, when: {:date, ~D[1998-07-01]}}] =
               Order.rules(
                 Doc.new("UK_uksi_1998_1542", [
                   ~s|<Legislation><Secondary><Body><P1 id="article-2"><P1para><Text>The Police (Health and Safety) Act 1997 shall, insofar as it is not already in force, come into force on 1st July 1998.</Text></P1para></P1></Body></Secondary></Legislation>|
                 ]),
                 act
               )
    end

    test "repeal descriptions name another Act's provisions; \"In Schedule 18, the repeals …\" is part of Schedule 18 (SI 1996/396, SI 2004/2593)" do
      act = %{law: "UK_ukpga_2004_5", title: "Planning and Compulsory Purchase Act", year: "2004"}

      rules =
        Order.rules(
          Doc.new("UK_uksi_2004_2593", [
            ~s|<Legislation><Secondary><Body><P1 id="article-2"><P1para><Text>The following provisions of the Planning and Compulsory Purchase Act 2004 shall come into force on 31 October 2004—</Text><P2 id="article-2-a"><P2para><Text>section 111(2);</Text></P2para></P2><P2 id="article-2-b"><P2para><Text>in the Town and Country Planning Act 1990, sections 226 and 245;</Text></P2para></P2><P2 id="article-2-c"><P2para><Text>In Schedule 9, the repeals to the Game Licences Act 1860.</Text></P2para></P2></P1para></P1></Body></Secondary></Legislation>|
          ]),
          act
        )

      scopes = Enum.flat_map(rules, &List.wrap(&1.scope))
      assert "s.111(2)" in scopes
      refute "s.226" in scopes
      assert Enum.any?(rules, &(&1.scope == ["sch.9"] and &1.purposes == :in_relation_to))
    end
  end

  describe "CV-S04 agent round 4" do
    @epa %{law: "UK_ukpga_1990_43", title: "Environmental Protection Act", year: "1990"}

    defp epa_order(text),
      do:
        Order.rules(
          Doc.new("UK_uksi_1990_2635", [
            ~s|<Legislation><Secondary><Body><P1 id="article-3"><P1para><Text>#{text}</Text></P1para></P1></Body></Secondary></Legislation>|
          ]),
          @epa
        )

    test "N3: each item its own bracketed qualifier (SI 1990/2635 reg.3)" do
      rules =
        epa_order(
          "Sections 1, 2, 4 to 28, 105 (in so far as it is not already in force), 159 and 162(2) (in so far as it relates to Part V of Schedule 16) of the Environmental Protection Act 1990 shall come into force on 1st January 1991."
        )

      full = &Enum.any?(rules, fn r -> &1 in List.wrap(r.scope) and Rule.full?(r) end)
      assert full.("s.1") and full.("s.4..s.28") and full.("s.105") and full.("sch.16.pt.V")
      refute full.("s.162(2)")
    end

    test "N1: a qualifier after the date; N2: quoted words and another Act's provisions are not refs" do
      rules =
        epa_order(
          "Section 120(1) of, and Schedule 22 to, the Environmental Protection Act 1990 come into force on 1st April 2015 in so far as they relate to paragraph 81 of Schedule 22."
        )

      assert Enum.any?(rules, &(&1.scope == ["s.120(1)", "sch.22"] and not Rule.full?(&1)))

      rules =
        epa_order(
          "The following provisions of the Environmental Protection Act 1990 shall come into force on 1st April 1996— section 3; the repeal of sections 7(2) and (8) and 11(3) of the Control of Pollution (Amendment) Act 1989; in section 33(1) the words “section 54”."
        )

      scopes = Enum.flat_map(rules, &List.wrap(&1.scope))
      assert "s.3" in scopes
      refute Enum.any?(scopes, &(&1 in ["s.7(2)", "s.11(3)", "s.54"]))
    end

    test "repeal lists: entries and \"the following repeals\" are the Schedule in relation to, never their items (SI 1996/3056, SI 1997/3114)" do
      rules =
        epa_order(
          "Section 162(2) of the Environmental Protection Act 1990 shall come into force on 16th December 1996 in so far as it relates to the following repeals in Part I of Schedule 16 to that Act:</Text><P3 id=\"article-3-a\"><P3para><Text>the repeal of section 1(1)(d) and section 5 of the Health and Safety at Work etc. Act 1974;</Text></P3para></P3><Text>"
        )

      scopes = Enum.flat_map(rules, &List.wrap(&1.scope))
      assert Enum.any?(rules, &(&1.scope == ["sch.16.pt.I"] and not Rule.full?(&1)))
      refute Enum.any?(scopes, &(&1 in ["s.1(1)(d)", "s.5"]))

      rules =
        Order.rules(
          order(~S"""
          <Schedules><Schedule id="schedule"><TitleBlock><Title>Provisions coming into force on 17th December 1997</Title></TitleBlock><ScheduleBody><Tabular><table><tbody>
          <tr><td>Section 2</td><td>Consequential amendments and repeals</td></tr>
          <tr><td>In the Schedule—the entries relating to sections 11 to 14 of, and Schedule 1 and paragraph 13 of Schedule 2 to, the Firearms (Amendment) Act 1997.</td><td>Repeals</td></tr>
          </tbody></table></Tabular></ScheduleBody></Schedule></Schedules>
          """),
          @act
        )

      scopes = Enum.flat_map(rules, &List.wrap(&1.scope))
      assert Enum.any?(rules, &(&1.scope == ["sch"] and not Rule.full?(&1)))
      refute Enum.any?(scopes, &(&1 in ["s.11..s.14", "sch.1", "sch.2.para.13"]))
    end

    test "N4: a Schedule's Part either way" do
      alias SertantaiLegal.Scraper.LatRef
      assert LatRef.covers?("sch.16.pt.1", "sch.16.pt.I")
      refute LatRef.covers?("sch.16.pt.2", "sch.16.pt.I")
    end
  end
end
