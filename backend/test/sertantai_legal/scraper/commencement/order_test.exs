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
end
