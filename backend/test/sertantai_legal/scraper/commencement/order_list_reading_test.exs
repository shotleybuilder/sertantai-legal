defmodule SertantaiLegal.Scraper.Commencement.OrderListReadingTest do
  @moduledoc """
  Fire and OH&S: Commencement reader — the order-list readings taken from
  the leftovers and the parked order bugs, each from the order's own words.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}

  defp doc(law, title, body),
    do:
      Doc.new(law, [
        ~s(<Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>#{title}</dc:title><Secondary><Body>#{body}</Body></Secondary></Legislation>)
      ])

  defp lines(rules),
    do: Enum.map(rules, &(&1 |> Rule.to_text() |> String.split(" — UK_") |> hd()))

  describe "the whole Act, so far as not already in force (SI 2004/2304 art.2(2))" do
    @frsa %{law: "UK_ukpga_2004_21", title: "Fire and Rescue Services Act", year: "2004"}

    defp frsa_order(title) do
      doc("UK_uksi_2004_2304", title, ~S"""
      <P1 id="article-1"><P1para>
      <P2 id="article-1-2"><Pnumber>2</Pnumber><P2para><Text>This Order does not apply in relation to Wales.</Text></P2para></P2>
      <P2 id="article-1-3"><Pnumber>3</Pnumber><P2para><Text>In this Order—</Text><UnorderedList Class="Definition"><ListItem><Para><Text>“the 2004 Act” means the Fire and Rescue Services Act 2004.</Text></Para></ListItem></UnorderedList></P2para></P2>
      </P1para></P1>
      <P1 id="article-2"><P1para>
      <P2 id="article-2-2"><Pnumber>2</Pnumber><P2para><Text>Subject to article 3 the 2004 Act shall, insofar as it is not already in force, come into force on 1st October 2004.</Text></P2para></P2>
      </P1para></P1>
      """)
    end

    test "\"Subject to article 3 the 2004 Act shall, insofar as it is not already in force, come into force on …\": the whole Act" do
      rules =
        Order.rules(
          frsa_order("The Fire and Rescue Services Act 2004 (Commencement) Order 2004"),
          @frsa
        )

      assert lines(rules) == ["all — 2004-10-01 — everywhere, fully — order_date"]
    end

    test "an order titled for two territories commences there (\"(England and Scotland) Order\")" do
      title =
        "The Fire and Rescue Services Act 2004 (Commencement) (England and Scotland) Order 2004"

      assert [%Rule{scope: :all, when: {:date, ~D[2004-10-01]}, territory: "E+S", purposes: nil}] =
               Order.rules(frsa_order(title), @frsa)
    end
  end

  describe "items first: \"namely in Schedule 8, the entries relating to:—\" (SI 1978/1583 art.3)" do
    @lga %{law: "UK_ukpga_1974_7", title: "Local Government Act", year: "1974"}

    test "the Schedule's entries, partly; the entries' own sections are other laws'" do
      order =
        doc(
          "UK_uksi_1978_1583",
          "The Local Government Act 1974 (Commencement No. 3) Order 1978",
          ~S"""
          <P1 id="article-2"><P1para><P2 id="article-2-2"><P2para><Text>In this order, “the Act” means the Local Government Act 1974.</Text></P2para></P2></P1para></P1>
          <P1 id="article-3"><P1para><Text>The following provisions of the Act, namely in Schedule 8, the entries relating to:—</Text>
          <P3 id="article-3-a"><Pnumber>a</Pnumber><P3para><Text>section 97 of the National Parks and Access to the Countryside Act 1949,</Text></P3para></P3>
          <P3 id="article-3-b"><Pnumber>b</Pnumber><P3para><Text>section 9 and 12(a) of the Rating Act 1966,</Text></P3para></P3>
          <P3 id="article-3-c"><Pnumber>c</Pnumber><P3para><Text>section 8 of the Local Government Act 1966, and</Text></P3para></P3>
          <P3 id="article-3-d"><Pnumber>d</Pnumber><P3para><Text>sections 33 to 36 of the Countryside Act 1968</Text></P3para></P3>
          <Text>shall come into operation on 1st April 1979.</Text></P1para></P1>
          """
        )

      assert lines(Order.rules(order, @lga)) == [
               "sch.8 — 1979-04-01 — everywhere, in relation to — order_date"
             ]
    end
  end

  describe "a paragraph list read past its asides (SI 1995/2950: Environment Act 1995 Sch.10)" do
    @ea %{law: "UK_ukpga_1995_25", title: "Environment Act", year: "1995"}

    defp ea_order(article) do
      doc(
        "UK_uksi_1995_2950",
        "The Environment Act 1995 (Commencement No. 4 and Saving Provisions) Order 1995",
        ~s"""
        <P1 id="article-1"><P1para><P2 id="article-1-2"><P2para><Text>In this Order—</Text><UnorderedList Class="Definition"><ListItem><Para><Text>“the 1995 Act” means the Environment Act 1995.</Text></Para></ListItem></UnorderedList></P2para></P2></P1para></P1>
        #{article}
        """
      )
    end

    test "\"paragraphs 1, 2 (except sub-paragraphs (2) and (9)(b)), 3 to 7, … 35 (insofar as it adds …), 36, 37 and 38(1) of Schedule 10\": the whole list (art.2(1))" do
      rules =
        ~S"""
        <P1 id="article-2"><P1para><P2 id="article-2-1"><Pnumber>1</Pnumber><P2para><Text>Subject to paragraph (2), the following provisions of the 1995 Act shall come into force on the 23rd November 1995—</Text>
        <UnorderedList><ListItem><Para><Text>Section 78 insofar as it relates to paragraphs 1, 2 (except sub-paragraphs (2) and (9)(b)), 3 to 7, 8(2), 9, 10(1) and (3), 11, 12, 14, 15, 17 to 19, 21, 23 to 26, 28 to 31, 32(1) to (13) and (15) to (18), 33(1) to (5), 34, 35 (insofar as it adds to section 35(5) of the Local Government Finance Act 1992 (definition of “special items”) the words “or (c) a National park authority in relation to a National Park in Wales”), 36, 37 and 38(1) of Schedule 10;</Text></Para></ListItem></UnorderedList>
        </P2para></P2></P1para></P1>
        """
        |> ea_order()
        |> Order.rules(@ea)

      assert lines(rules) == [
               "s.78 — 1995-11-23 — everywhere, in relation to — order_date",
               "sch.10.para.1, sch.10.para.2, sch.10.para.3..sch.10.para.7, sch.10.para.8(2), sch.10.para.9, sch.10.para.10(1), sch.10.para.10(3), sch.10.para.11, sch.10.para.12, sch.10.para.14, sch.10.para.15, sch.10.para.17..sch.10.para.19, sch.10.para.21, sch.10.para.23..sch.10.para.26, sch.10.para.28..sch.10.para.31, sch.10.para.32(1)..sch.10.para.32(13), sch.10.para.32(15)..sch.10.para.32(18), sch.10.para.33(1)..sch.10.para.33(5), sch.10.para.34, sch.10.para.36, sch.10.para.37, sch.10.para.38(1) except sch.10.para.2(2), sch.10.para.2(9)(b) — 1995-11-23 — everywhere, fully — order_date",
               "sch.10.para.35 — 1995-11-23 — everywhere, in relation to — order_date"
             ]
    end

    test "“paragraphs 2(2) and (9)(b), 8(1), and (3), 13, 16, 20 and 22(3), (4)(a) and (b) and (5) of Schedule 10”: read past “, and” (art.3(1))" do
      rules =
        ~S"""
        <P1 id="article-3"><P1para><P2 id="article-3-1"><Pnumber>1</Pnumber><P2para><Text>Subject to paragraph (2), the following provisions of the 1995 Act shall come into force on 1st April 1996—</Text>
        <UnorderedList><ListItem><Para><Text>Section 78 insofar as it relates to paragraphs 2(2) and (9)(b), 8(1), and (3), 13, 16, 20 and 22(3), (4)(a) and (b) and (5) of Schedule 10;</Text></Para></ListItem></UnorderedList>
        </P2para></P2></P1para></P1>
        """
        |> ea_order()
        |> Order.rules(@ea)

      assert lines(rules) == [
               "s.78 — 1996-04-01 — everywhere, in relation to — order_date",
               "sch.10.para.2(2), sch.10.para.2(9)(b), sch.10.para.8(1), sch.10.para.8(3), sch.10.para.13, sch.10.para.16, sch.10.para.20, sch.10.para.22(3), sch.10.para.22(4)(a), sch.10.para.22(4)(b), sch.10.para.22(5) — 1996-04-01 — everywhere, fully — order_date"
             ]
    end
  end

  describe "asides read past leave what the item names" do
    @act %{law: "UK_ukpga_1993_43", title: "Railways Act", year: "1993"}

    defp railways_order(item) do
      doc("UK_uksi_1994_571", "The Railways Act 1993 (Commencement No. 1) Order 1994", ~s"""
      <P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Railways Act 1993.</Text></P1para></P1>
      <P1 id="article-2"><P1para><Text>The following provisions of the Act shall come into force on 1st April 1994—</Text>
      <P3 id="article-2-a"><Pnumber>a</Pnumber><P3para><Text>#{item}</Text></P3para></P3></P1para></P1>
      """)
    end

    test "\"paragraphs 3 and 19 in Part 2 (Modifications of the … Act (Northern Ireland) 2016) of Schedule 11\": the paragraphs, never the Part (NISR 2020/58)" do
      rules =
        "paragraphs 3, 4 and 19 in Part 2 (Modifications of the Mental Capacity Act (Northern Ireland) 2016) of Schedule 11 (Mental Capacity: Northern Ireland)"
        |> railways_order()
        |> Order.rules(@act)

      assert lines(rules) == [
               "sch.11.para.3, sch.11.para.4, sch.11.para.19 — 1994-04-01 — everywhere, fully — order_date"
             ]
    end

    test "\"paragraphs 10 to 14 of Schedule 3 (and section 44(1) so far as relating thereto)\": the paragraphs fully, the section partly (SI 1999/987)" do
      rules =
        "paragraphs 10 to 14 of Schedule 3 (and section 44(1) so far as relating thereto)."
        |> railways_order()
        |> Order.rules(@act)

      assert lines(rules) == [
               "sch.3.para.10..sch.3.para.14 — 1994-04-01 — everywhere, fully — order_date",
               "s.44(1) — 1994-04-01 — everywhere, in relation to — order_date"
             ]
    end
  end

  describe "\"in section N—\" heads its items, never the whole section (SI 2004/2528 art.2)" do
    @water %{law: "UK_ukpga_2003_37", title: "Water Act", year: "2003"}

    defp water_order(items) do
      doc(
        "UK_uksi_2004_2528",
        "The Water Act 2003 (Commencement No. 2, Transitional Provisions and Savings) Order 2004",
        ~s"""
        <P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Water Act 2003.</Text></P1para></P1>
        <P1 id="article-2"><P1para><Text>The following provisions of the Act shall come into force on 1st October 2004—</Text>
        #{items}</P1para></P1>
        """
      )
    end

    test "\"in section 86 (…)– (i) in subsection (2), paragraph (f); and (ii) subsection (1) in so far as it relates to that paragraph\"" do
      rules =
        ~S"""
        <P3 id="article-2-p"><Pnumber>p</Pnumber><P3para><Text>section 80 (Crown application);</Text></P3para></P3>
        <P3 id="article-2-q"><Pnumber>q</Pnumber><P3para><Text>in section 86 (contaminated land: pollution of controlled waters)–</Text>
        <P4 id="article-2-q-i"><Pnumber>i</Pnumber><P4para><Text>in subsection (2), paragraph (f); and</Text></P4para></P4>
        <P4 id="article-2-q-ii"><Pnumber>ii</Pnumber><P4para><Text>subsection (1) in so far as it relates to that paragraph;</Text></P4para></P4></P3para></P3>
        <P3 id="article-2-r"><Pnumber>r</Pnumber><P3para><Text>section 87 (transfer of discharge consents);</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert lines(rules) == [
               "s.80 — 2004-10-01 — everywhere, fully — order_date",
               "s.86(2)(f) — 2004-10-01 — everywhere, fully — order_date",
               "s.86(1) — 2004-10-01 — everywhere, in relation to — order_date",
               "s.87 — 2004-10-01 — everywhere, fully — order_date"
             ]
    end

    test "\"in section 8 (…), subsections (3) to (7) and subsection (1) in so far as it relates to those subsections\": the subsections fully, subsection (1) partly (SI 2006/984 art.2(e))" do
      rules =
        ~S"""
        <P3 id="article-2-e"><Pnumber>e</Pnumber><P3para><Text>in section 8 (amendments relating to section 7), subsections (3) to (7) and subsection (1) in so far as it relates to those subsections;</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert lines(rules) == [
               "s.8(3)..s.8(7) — 2004-10-01 — everywhere, fully — order_date",
               "s.8(1) — 2004-10-01 — everywhere, in relation to — order_date"
             ]
    end

    test "\"in section 25 (…), subsection (1), in so far as it relates to subsection (2), and subsections (2) and (4)\": the subsections after the qualifier fully (SI 2004/641 art.3(h))" do
      rules =
        ~S"""
        <P3 id="article-2-h"><Pnumber>h</Pnumber><P3para><Text>in section 25 (compensation for modification of licence on direction of the Secretary of State), subsection (1), in so far as it relates to subsection (2), and subsections (2) and (4);</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert lines(rules) == [
               "s.25(1) — 2004-10-01 — everywhere, in relation to — order_date",
               "s.25(2), s.25(4) — 2004-10-01 — everywhere, fully — order_date"
             ]
    end

    test "\"section 56 (…), but— (i) in its application to paragraphs 2 and 4 of Schedule 4, only in so far as …\": the section partly (SI 2004/641 art.3(l))" do
      rules =
        ~S"""
        <P3 id="article-2-l"><Pnumber>l</Pnumber><P3para><Text>section 56 (licensing of water suppliers), but—</Text>
        <P4 id="article-2-l-i"><Pnumber>i</Pnumber><P4para><Text>in its application to paragraphs 2 and 4 of Schedule 4, only in so far as the paragraph in question has effect for the purpose of conferring powers to make regulations; and</Text></P4para></P4>
        <P4 id="article-2-l-ii"><Pnumber>ii</Pnumber><P4para><Text>in its application to paragraph 1 of Schedule 4, only for the purpose of giving effect to paragraphs 2 and 4 of that Schedule;</Text></P4para></P4></P3para></P3>
        <P3 id="article-2-m"><Pnumber>m</Pnumber><P3para><Text>section 87 (transfer of discharge consents);</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert Enum.find(rules, &(&1.scope == ["s.56"])).purposes != nil
      assert Enum.find(rules, &(&1.scope == ["s.87"])).purposes == nil
    end

    test "\"section 16 (…), except the amendments made by subsections (4) and (5)\": the section but those subsections (SI 2004/641 art.3(e))" do
      rules =
        ~S"""
        <P3 id="article-2-e"><Pnumber>e</Pnumber><P3para><Text>section 16 (protection from derogation), except the amendments made by subsections (4) and (5);</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert [%{scope: ["s.16"], except: ["s.16(4)", "s.16(5)"], purposes: nil}] = rules
    end

    test "\"section 34 (…) except in so far as subsection (2) gives effect to Schedule 1 …\": the section but subsection (2) fully, subsection (2) partly (SI 2005/2714 art.4(a))" do
      rules =
        ~S"""
        <P3 id="article-2-a"><Pnumber>a</Pnumber><P3para><Text>section 34 (the Authority) except in so far as subsection (2) gives effect to Schedule 1 for the purposes of inserting into the WIA paragraph 11 of Schedule 1A;</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert lines(rules) == [
               "s.34 except s.34(2) — 2004-10-01 — everywhere, fully — order_date",
               "s.34(2) — 2004-10-01 — everywhere, in relation to — order_date"
             ]
    end

    test "\"section 69 (…), in so far as it applies in relation to England\": England's, no purpose (SI 2004/641 art.2(a))" do
      rules =
        ~S"""
        <P3 id="article-2-a"><Pnumber>a</Pnumber><P3para><Text>section 69 (grants for drainage works and flood warning systems), in so far as it applies in relation to England;</Text></P3para></P3>
        <P3 id="article-2-b"><Pnumber>b</Pnumber><P3para><Text>section 70 in so far as it relates to the Agency's functions in relation to Wales;</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert lines(rules) == [
               "s.69 — 2004-10-01 — E, fully — order_date",
               "s.70 — 2004-10-01 — W, in relation to — order_date"
             ]
    end

    test "\"in section 38 (…)– (i) subsection (1); and (ii) subsection (2) in so far as it repeals …\"; a list of subsections" do
      rules =
        ~S"""
        <P3 id="article-2-d"><Pnumber>d</Pnumber><P3para><Text>in section 38 (forward work programmes and annual reports)–</Text>
        <P4 id="article-2-d-i"><Pnumber>i</Pnumber><P4para><Text>subsection (1); and</Text></P4para></P4>
        <P4 id="article-2-d-ii"><Pnumber>ii</Pnumber><P4para><Text>subsection (2) in so far as it confers power to make regulations;</Text></P4para></P4></P3para></P3>
        <P3 id="article-2-s"><Pnumber>s</Pnumber><P3para><Text>in section 100 (devolution: Wales)–</Text>
        <P4 id="article-2-s-i"><Pnumber>i</Pnumber><P4para><Text>subsections (1), (3) and (4)(a).</Text></P4para></P4></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert lines(rules) == [
               "s.38(1) — 2004-10-01 — everywhere, fully — order_date",
               "s.38(2) — 2004-10-01 — everywhere, for making secondary legislation — order_date",
               "s.100(1), s.100(3), s.100(4)(a) — 2004-10-01 — everywhere, fully — order_date"
             ]
    end

    test "one line: \"in section 61, subsection (6)\" is the subsection, never the section too" do
      rules =
        ~S"""
        <P3 id="article-2-a"><Pnumber>a</Pnumber><P3para><Text>in section 61, subsections (5) to (7);</Text></P3para></P3>
        """
        |> water_order()
        |> Order.rules(@water)

      assert lines(rules) == ["s.61(5)..s.61(7) — 2004-10-01 — everywhere, fully — order_date"]
    end
  end

  describe "a repeals Schedule's Part and its entries (SI 2007/709 art.3: 2006 c.48 Sch.15)" do
    @pja %{law: "UK_ukpga_2006_48", title: "Police and Justice Act", year: "2006"}

    test "“Part 1(A) of Schedule 15”, “in Part 1(B) … of Schedule 15 the entries relating to —”, “in Part 2 of Schedule 15 (…) the entries relating to—”: the Part, partly" do
      order =
        doc(
          "UK_uksi_2007_709",
          "The Police and Justice Act 2006 (Commencement No. 2, Transitional and Saving Provisions) Order 2007",
          ~S"""
          <P1 id="article-2"><P1para><Text>In this Order “the 2006 Act” means the Police and Justice Act 2006.</Text></P1para></P1>
          <P1 id="article-3"><P1para><Text>Subject to articles 6 and 7 the following provisions of the 2006 Act shall come into force on 1st April 2007—</Text>
          <P3 id="article-3-q"><Pnumber>q</Pnumber><P3para><Text>Part 1(A) (national policing improvement agency) of Schedule 15;</Text></P3para></P3>
          <P3 id="article-3-r"><Pnumber>r</Pnumber><P3para><Text>in Part 1(B) (other repeals relating to Part 1) of Schedule 15 the entries relating to —</Text>
          <P4 id="article-3-r-i"><Pnumber>i</Pnumber><P4para><Text>the Police Act 1996;</Text></P4para></P4>
          <P4 id="article-3-r-ii"><Pnumber>ii</Pnumber><P4para><Text>section 5 of the Police Act 1997;</Text></P4para></P4></P3para></P3>
          <P3 id="article-3-t"><Pnumber>t</Pnumber><P3para><Text>in Part 2 of Schedule 15 (repeals: powers of police etc) the entries relating to—</Text>
          <P4 id="article-3-t-i"><Pnumber>i</Pnumber><P4para><Text>the Criminal Justice Act 2003.</Text></P4para></P4></P3para></P3>
          </P1para></P1>
          """
        )

      assert lines(Order.rules(order, @pja)) == [
               "sch.15.pt.1 — 2007-04-01 — everywhere, in relation to — order_date",
               "sch.15.pt.1 — 2007-04-01 — everywhere, in relation to — order_date",
               "sch.15.pt.2 — 2007-04-01 — everywhere, in relation to — order_date"
             ]
    end
  end

  describe "an item's bracketed heading is no territory and no purpose" do
    @env %{law: "UK_ukpga_2021_30", title: "Environment Act", year: "2021"}

    defp env_order(law, items) do
      doc(
        law,
        "The Environment Act 2021 (Commencement No. 2 and Saving Provision) Regulations 2022",
        ~s"""
        <P1 id="regulation-1"><P1para><Text>In these Regulations “<Term id="t">the Act</Term>” means the Environment Act 2021.</Text></P1para></P1>
        <P1 id="regulation-2"><P1para><Text>The following provisions of the Act come into force on 24th January 2022—</Text>
        #{items}</P1para></P1>
        """
      )
    end

    test "\"section 86 (water and sewerage undertakers in England: modifying appointments)\": wholly, everywhere (SI 2022/48)" do
      rules =
        env_order("UK_uksi_2022_48", ~S"""
        <P3 id="regulation-2-s"><Pnumber>s</Pnumber><P3para><Text>section 86 (water and sewerage undertakers in England: modifying appointments);</Text></P3para></P3>
        <P3 id="regulation-2-t"><Pnumber>t</Pnumber><P3para><Text>section 9 (meaning of local authority for the purpose of access rights);</Text></P3para></P3>
        <P3 id="regulation-2-u"><Pnumber>u</Pnumber><P3para><Text>section 60 (hazardous waste: England and Wales), so far as relating to England;</Text></P3para></P3>
        <P3 id="regulation-2-v"><Pnumber>v</Pnumber><P3para><Text>section 61 (in relation to Wales).</Text></P3para></P3>
        """)
        |> Order.rules(@env)

      assert lines(rules) == [
               "s.86 — 2022-01-24 — everywhere, fully — order_date",
               "s.9 — 2022-01-24 — everywhere, fully — order_date",
               "s.60 — 2022-01-24 — everywhere, in relation to — order_date",
               "s.61 — 2022-01-24 — W, in relation to — order_date"
             ]
    end

    test "\"Parts 1 and 3 of Schedule 12 (smoke control in England and Wales)\": those Parts, never paragraphs 1 and 3 (SI 2022/48)" do
      rules =
        env_order("UK_uksi_2022_48", ~S"""
        <P3 id="regulation-2-a"><Pnumber>a</Pnumber><P3para><Text>Parts 1 and 3 of Schedule 12 (smoke control in England and Wales).</Text></P3para></P3>
        """)
        |> Order.rules(@env)

      assert lines(rules) == [
               "sch.12.pt.1, sch.12.pt.3 — 2022-01-24 — everywhere, fully — order_date"
             ]
    end
  end

  describe "a devolved order commencing its own legislature's Act" do
    test "a Welsh order on a Senedd Act names no territory: the Act wherever it extends (WSI 2023/1149)" do
      act = %{
        law: "UK_asc_2023_2",
        title: "Environmental Protection (Single-use Plastic Products) (Wales) Act",
        year: "2023"
      }

      order =
        doc(
          "UK_wsi_2023_1149",
          "The Environmental Protection (Single-use Plastic Products) (Wales) Act 2023 (Commencement No. 1) Order 2023",
          ~S"""
          <P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Environmental Protection (Single-use Plastic Products) (Wales) Act 2023.</Text></P1para></P1>
          <P1 id="article-2"><P1para><Text>The following provisions of the Act come into force on 30 October 2023—</Text>
          <P3 id="article-2-a"><Pnumber>a</Pnumber><P3para><Text>section 5 (offence of supplying prohibited single-use plastic product);</Text></P3para></P3></P1para></P1>
          """
        )

      assert lines(Order.rules(order, act)) == [
               "s.5 — 2023-10-30 — everywhere, fully — order_date"
             ]
    end

    test "a Welsh order on a UK Act still commences in relation to Wales" do
      order =
        doc(
          "UK_wsi_2022_1",
          "The Environment Act 2021 (Commencement No. 1) (Wales) Regulations 2022",
          ~S"""
          <P1 id="regulation-1"><P1para><Text>In these Regulations “<Term id="t">the Act</Term>” means the Environment Act 2021.</Text></P1para></P1>
          <P1 id="regulation-2"><P1para><Text>Section 60 of the Act comes into force on 24th January 2022.</Text></P1para></P1>
          """
        )

      assert [%Rule{territory: "W"}] = Order.rules(order, @env)
    end
  end

  describe "the Schedule a list's paragraphs belong to" do
    @crow %{law: "UK_ukpga_2000_37", title: "Countryside and Rights of Way Act", year: "2000"}

    test "\"section 57 … in so far as it gives effect to the provisions of Schedule 6 to the Act referred to in sub-paragraphs (b) to (s) below\" heads Schedule 6's paragraphs (SI 2003/272 art.2)" do
      order =
        doc(
          "UK_uksi_2003_272",
          "The Countryside and Rights of Way Act 2000 (Commencement No. 2) Order 2003",
          ~S"""
          <P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Countryside and Rights of Way Act 2000.</Text></P1para></P1>
          <P1 id="article-2"><P1para><Text>12th February 2003 is the day appointed for the coming into force of the following provisions of the Act—</Text>
          <P3 id="article-2-a"><Pnumber>a</Pnumber><P3para><Text>section 57 of the Act (amendments to the 1980 Act and other Acts) in so far as it gives effect to the provisions of Schedule 6 to the Act referred to in sub-paragraphs (b) to (s) below;</Text></P3para></P3>
          <P3 id="article-2-b"><Pnumber>b</Pnumber><P3para><Text>paragraphs 1, 6, and 9(5) (rights of way improvement plans);</Text></P3para></P3>
          <P3 id="article-2-c"><Pnumber>c</Pnumber><P3para><Text>paragraph 20 (interpretation);</Text></P3para></P3>
          <P3 id="article-2-d"><Pnumber>d</Pnumber><P3para><Text>paragraph 5 (highways maintainable at public expense), except to the extent that the amendment made relates to a highway created in consequence of an SSSI diversion order.</Text></P3para></P3>
          </P1para></P1>
          """
        )

      assert lines(Order.rules(order, @crow)) == [
               "s.57 — 2003-02-12 — everywhere, in relation to — order_date",
               "sch.6.para.1, sch.6.para.6, sch.6.para.9(5) — 2003-02-12 — everywhere, fully — order_date",
               "sch.6.para.20 — 2003-02-12 — everywhere, fully — order_date",
               "sch.6.para.5 — 2003-02-12 — everywhere, in relation to — order_date"
             ]
    end

    test "\"In Part 1 of Schedule 7 (…), paragraphs 1, 2 and 13 to 20\": the paragraphs; a pointed-to paragraph's own number is no item (SI 2026/323 reg.4)" do
      act = %{law: "UK_ukpga_2025_36", title: "Employment Rights Act", year: "2025"}

      order =
        doc(
          "UK_uksi_2026_323",
          "The Employment Rights Act 2025 (Commencement No. 2) Regulations 2026",
          ~S"""
          <P1 id="regulation-1"><P1para><Text>In these Regulations “the 2025 Act” means the Employment Rights Act 2025.</Text></P1para></P1>
          <P1 id="regulation-4"><P1para>
          <P2 id="regulation-4-1"><Pnumber>1</Pnumber><P2para><Text>The provisions of Part 5 of the 2025 Act specified in the following paragraphs of this regulation come into force on 7th April 2026.</Text></P2para></P2>
          <P2 id="regulation-4-2"><Pnumber>2</Pnumber><P2para><Text>In Part 1 of Schedule 7 (legislation subject to enforcement under Part 5), paragraphs 1, 2 and 13 to 20.</Text></P2para></P2>
          <P2 id="regulation-4-3"><Pnumber>3</Pnumber><P2para><Text>Schedule 8 (warrants under Part 5: further provision).</Text></P2para></P2>
          </P1para></P1>
          """
        )

      assert lines(Order.rules(order, act)) == [
               "sch.7.para.1, sch.7.para.2, sch.7.para.13..sch.7.para.20 — 2026-04-07 — everywhere, fully — order_date",
               "sch.8 — 2026-04-07 — everywhere, fully — order_date"
             ]
    end
  end

  describe "a Schedule's rules carry the territory of the article bringing it in (SI 1988/818 art.2)" do
    @copa %{law: "UK_ukpga_1974_40", title: "Control of Pollution Act", year: "1974"}

    defp copa_order(article, schedule) do
      Doc.new("UK_uksi_1988_818", [
        ~s"""
        <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Control of Pollution Act 1974 (Commencement No. 19) Order 1988</dc:title><Secondary><Body>
        <P1 id="article-1"><P1para><Text>This Order may be cited as the Control of Pollution Act 1974 (Commencement No. 19) Order 1988.</Text></P1para></P1>
        <P1 id="article-2"><P1para><Text>#{article}</Text></P1para></P1>
        </Body><Schedules><Schedule id="schedule"><Number>SCHEDULE</Number><ScheduleBody>#{schedule}</ScheduleBody></Schedule></Schedules></Secondary></Legislation>
        """
      ])
    end

    @table ~S"""
    <Tabular><table><tbody>
    <tr><td>Section 12(1)-(9) and (11)</td><td>Collection of waste</td></tr>
    <tr><td>Section 14</td><td>Disposal of waste in England and Wales</td></tr>
    <tr><td>Section 30(1), in relation to Scotland</td><td>Interpretation</td></tr>
    </tbody></table></Tabular>
    """

    test "\"… specified in the Schedule to this Order … shall come into force in England and Wales, so far as they are not already in force, on 6th June 1988\": each row there; a row's own place stays" do
      rules =
        "The provisions of the Control of Pollution Act 1974 specified in the Schedule to this Order (the subject matter of which is described in the second column of the Schedule) shall come into force in England and Wales, so far as they are not already in force, on 6th June 1988."
        |> copa_order(@table)
        |> Order.rules(@copa)

      assert lines(rules) == [
               "s.12(1)..s.12(9), s.12(11) — 1988-06-06 — E+W, fully — order_schedule",
               "s.14 — 1988-06-06 — E+W, fully — order_schedule",
               # (a place alone is its territory, never a purpose: Decision 10's
               # round, 2026-11-22 — partly in force still, wherever S does
               # not cover the row's extent)
               "s.30(1) — 1988-06-06 — S, fully — order_schedule"
             ]
    end

    test "an article naming no place: the rows everywhere" do
      rules =
        "The provisions of the Control of Pollution Act 1974 specified in the Schedule to this Order shall come into force on 6th June 1988."
        |> copa_order(@table)
        |> Order.rules(@copa)

      assert Enum.map(rules, & &1.territory) == [nil, nil, "S"]
    end
  end

  describe "a repeals Schedule's entries in a Schedule list (SI 2005/1909 Sch.: Railways Act 2005 Sch.13 Part 1)" do
    @ra %{law: "UK_ukpga_2005_14", title: "Railways Act", year: "2005"}

    defp ra_order(items) do
      list = Enum.map_join(items, &"<ListItem><Para><Text>#{&1}</Text></Para></ListItem>")

      Doc.new("UK_uksi_2005_1909", [
        ~s"""
        <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Railways Act 2005 (Commencement No. 2) Order 2005</dc:title><Secondary><Body>
        <P1 id="article-1"><P1para><P2 id="article-1-2"><P2para><Text>In this Order “the Act” means the Railways Act 2005.</Text></P2para></P2></P1para></P1>
        <P1 id="article-2"><P1para><Text>The provisions of the Act specified in the Schedule to this Order shall come into force on 24th July 2005.</Text></P1para></P1>
        </Body><Schedules><Schedule id="schedule"><Number>SCHEDULE</Number><TitleBlock><Title>PROVISIONS COMING INTO FORCE ON 24th JULY 2005</Title></TitleBlock><Reference>Article 2</Reference><ScheduleBody>
        <UnorderedList Decoration="none">#{list}
        <ListItem><Para><Text>The following entries in Part 1 of Schedule 13:</Text><UnorderedList Decoration="none">
        <ListItem><Para><Text>The entry relating to the Transport Act 1968, as regards England and Wales.</Text></Para></ListItem>
        <ListItem><Para><Text>The entries relating to sections 2, 3, 7, 7A, 10(4) and 145(7) of the Railways Act 1993.</Text></Para></ListItem>
        <ListItem><Para><Text>The entries relating to sections 8 and 16(3) of the Railways Act 1993, except in so far as they repeal the words “and to the Health and Safety Executive” in sections 8(7)(a) and (b) and 16(3).</Text></Para></ListItem>
        <ListItem><Para><Text>The entries relating to Schedule 2, Schedule 3 and Schedule 6 of the Railways Act 1993.</Text></Para></ListItem>
        <ListItem><Para><Text>The entries relating to sections 175(1), 197 and 252(1) and Schedule 19, paragraph 5 of the Greater London Authority Act 1999.</Text></Para></ListItem>
        <ListItem><Para><Text>The entries relating to Schedule 16, paragraphs 2 to 7, 9 and 64 of the Transport Act 2000.</Text></Para></ListItem>
        <ListItem><Para><Text>The entry relating to Schedule 2, paragraph 3 of the Railways and Transport Safety Act 2003, in so far as the entries in the table in paragraph 3 relate to sections 7A, 77 and 79 and Schedules 2 and 3.</Text></Para></ListItem>
        </UnorderedList></Para></ListItem></UnorderedList>
        </ScheduleBody></Schedule></Schedules></Secondary></Legislation>
        """
      ])
    end

    test "“The following entries in Part 1 of Schedule 13:” is that Part, partly; “The entries relating to … Schedule 3 … of the Railways Act 1993” are other laws' provisions, never the Act's" do
      rules = Order.rules(ra_order(["Schedules 5 and 6."]), @ra)

      assert lines(rules) == [
               "sch.5, sch.6 — 2005-07-24 — everywhere, fully — order_schedule",
               "sch.13.pt.1 — 2005-07-24 — everywhere, in relation to — order_schedule"
             ]
    end

    test "the Act's Schedule 3 (its changes to the Health and Safety at Work etc. Act 1974) is not brought in by the entries" do
      refs = ra_order([]) |> Order.rules(@ra) |> Enum.flat_map(& &1.scope)

      assert refs == ["sch.13.pt.1"]
    end

    test "“Schedule 13, Part 2, paragraph 2.” is that paragraph of Schedule 13, never the whole Schedule (SI 2005/2812 Sch.1)" do
      items = ["Schedule 12, paragraph 18.", "Schedule 13, Part 2, paragraph 2."]

      assert items |> ra_order() |> Order.rules(@ra) |> lines() |> Enum.take(2) == [
               "sch.12.para.18 — 2005-07-24 — everywhere, fully — order_schedule",
               "sch.13.para.2 — 2005-07-24 — everywhere, fully — order_schedule"
             ]
    end

    test "“Schedule 3, to the extent that it has not already come into force.” completes it: fully (SI 2006/266 Sch., its changes to HSWA 1974 on 1st April 2006)" do
      items = [
        "Section 2, in so far as it relates to the provisions of Schedule 3 brought into force by this Schedule.",
        "Schedule 3, to the extent that it has not already come into force.",
        "Schedule 10, to the extent it has not already come into force.",
        "Section 1(3), in so far as it has not already come into force."
      ]

      assert items |> ra_order() |> Order.rules(@ra) |> lines() |> Enum.take(4) == [
               "s.2 — 2005-07-24 — everywhere, in relation to — order_schedule",
               "sch.3 — 2005-07-24 — everywhere, fully — order_schedule",
               "sch.10 — 2005-07-24 — everywhere, fully — order_schedule",
               "s.1(3) — 2005-07-24 — everywhere, fully — order_schedule"
             ]
    end
  end
end
