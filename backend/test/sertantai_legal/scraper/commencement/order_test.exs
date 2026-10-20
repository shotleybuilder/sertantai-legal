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

  test "ref/1: an amending provision's id in the Act's grammar" do
    assert Order.ref("section-36-3") == "s.36(3)"
    assert Order.ref("schedule-11-paragraph-137-a") == "sch.11.para.137(a)"
    assert Order.ref("schedule-34") == "sch.34"
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
end
