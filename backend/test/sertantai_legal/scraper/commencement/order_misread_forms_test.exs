defmodule SertantaiLegal.Scraper.Commencement.OrderMisreadFormsTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader — the misread scan's order
  forms, each from the order's own words: a bare bracket after an item's
  parenthesis keeps that item's level; roman sub-items under a letter and a
  letter after them; a range ending two levels down; section numbers such
  as 58Z4; a colon inside a bracketed heading; "including italic headings".
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  defp doc(law, title, body),
    do:
      Doc.new(law, [
        ~s(<Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>#{title}</dc:title><Secondary><Body>#{body}</Body></Secondary></Legislation>)
      ])

  defp refs(rules), do: rules |> Enum.flat_map(& &1.scope) |> Enum.sort()

  defp fully(rules), do: rules |> Enum.filter(&(&1.purposes == nil)) |> refs()

  test "SI 1992/3253 art.3: \"(m) (in so far as it relates to section 111), (n) and (o) and (2) to (10)\" stay under s.118(1)" do
    order =
      doc(
        "UK_uksi_1992_3253",
        "The Environmental Protection Act 1990 (Commencement No. 13) Order 1992",
        ~S"""
        <P1 id="article-3"><Pnumber>3</Pnumber><P1para><Text>The following provisions of the Environmental Protection Act 1990 shall come into force on 1st February 1993—</Text>
        <UnorderedList><ListItem><Para><Text>section 106(4) and (5),</Text></Para></ListItem>
        <ListItem><Para><Text>section 118(1)(a), (c), (e) to (l), (m) (in so far as it relates to section 111), (n) and (o) and (2) to (10),</Text></Para></ListItem>
        </UnorderedList></P1para></P1>
        """
      )

    rules =
      Order.rules(order, %{
        law: "UK_ukpga_1990_43",
        title: "Environmental Protection Act",
        year: "1990"
      })

    all = refs(rules)
    assert "s.118(1)(n)" in all
    assert "s.118(1)(o)" in all
    assert "s.118(2)..s.118(10)" in all
    assert "s.118(1)(a)" in all
    refute "s.118(n)" in all
    refute "s.118(o)" in all
    assert "s.118(1)(n)" in fully(rules)
    refute "s.118(1)(m)" in fully(rules)
  end

  @water %{law: "UK_ukpga_2003_37", title: "Water Act", year: "2003"}

  defp water_order(item) do
    doc(
      "UK_uksi_2005_2714",
      "The Water Act 2003 (Commencement No. 5, Transitional Provisions and Savings) Order 2005",
      """
      <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Water Act 2003.</Text></P1para></P1>
      <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions of the Act shall come into force on 1st October 2005—</Text>
      <P3 id="article-2-j"><Pnumber>j</Pnumber><P3para><Text>section 63 (drought plans) for all remaining purposes;</Text></P3para></P3>
      <P3 id="article-2-k"><Pnumber>k</Pnumber><P3para><Text>in section 100 (devolution: Wales)—</Text>
      <P4 id="article-2-k-i"><Pnumber>i</Pnumber><P4para><Text>#{item}</Text></P4para></P4>
      </P3para></P3>
      </P1para></P1>
      """
    )
  end

  test "SI 2005/2714 art.2(k)(i): roman sub-items sit under the letter before them, a letter after them beside it" do
    rules =
      water_order(
        "subsection (2)(a), (iii) to (vi), (viii) and (ix), (b)(vi) and (x) and (g) in so far as it relates to provisions amended or introduced by any provision of the Act which is brought into force by virtue of this article;"
      )
      |> Order.rules(@water)

    all = refs(rules)

    for r <- [
          "s.100(2)(a)(iii)..s.100(2)(a)(vi)",
          "s.100(2)(a)(viii)",
          "s.100(2)(a)(ix)",
          "s.100(2)(b)(vi)",
          "s.100(2)(b)(x)",
          "s.100(2)(g)"
        ],
        do: assert(r in all, "#{r} not in #{inspect(all)}")

    refute Enum.any?(all, &(&1 =~ ~r/^s\.100\((?:b|2\)\((?:iii|viii|ix))/))
  end

  test "SI 2005/2714 art.3(b)(i): \"(h), (i) and (j)\" are letters side by side" do
    rules =
      water_order(
        "subsection (2)(a)(ii), (iv) and (ix), (b)(i), (ii), (iv), (v), (viii), (ix) and (x), (d), (e), (h), (i) and (j) in so far as it relates to provisions amended or introduced by any provision of the Act which is brought into force by virtue of this article;"
      )
      |> Order.rules(@water)

    all = refs(rules)

    for r <- [
          "s.100(2)(a)(ii)",
          "s.100(2)(a)(iv)",
          "s.100(2)(a)(ix)",
          "s.100(2)(b)(i)",
          "s.100(2)(b)(v)",
          "s.100(2)(b)(x)",
          "s.100(2)(d)",
          "s.100(2)(e)",
          "s.100(2)(h)",
          "s.100(2)(i)",
          "s.100(2)(j)"
        ],
        do: assert(r in all, "#{r} not in #{inspect(all)}")
  end

  test "SI 2010/2317 art.2(9)(g): \"section 136(1) to (6)(a) to (e)\" ends at s.136(6)(e)" do
    order =
      doc(
        "UK_uksi_2010_2317",
        "The Equality Act 2010 (Commencement No. 4, Savings, Consequential, Transitional, Transitory and Incidental Provisions and Revocation) Order 2010",
        ~S"""
        <P1 id="article-2"><Pnumber>2</Pnumber><P1para>
        <P2 id="article-2-1"><Pnumber>1</Pnumber><P2para><Text>The following provisions of the Equality Act 2010 come into force on 1st October 2010—</Text>
        <P3 id="article-2-1-f"><Pnumber>f</Pnumber><P3para><Text>sections 118 to 135;</Text></P3para></P3>
        <P3 id="article-2-1-g"><Pnumber>g</Pnumber><P3para><Text>section 136(1) to (6)(a) to (e);</Text></P3para></P3>
        <P3 id="article-2-1-h"><Pnumber>h</Pnumber><P3para><Text>section 137;</Text></P3para></P3>
        </P2para></P2></P1para></P1>
        """
      )

    all =
      refs(Order.rules(order, %{law: "UK_ukpga_2010_15", title: "Equality Act", year: "2010"}))

    assert "s.136(1)..s.136(6)(e)" in all
    refute Enum.any?(all, &(&1 =~ "s.136(e)"))
  end

  test "SI 2023/362 reg.3(1)(s): \"sections 58C, 58O, 58U, 58V, 58Z4 and 58Z5 of the Building Act 1984\" are that Act's" do
    order =
      doc(
        "UK_uksi_2023_362",
        "The Building Safety Act 2022 (Commencement No. 4 and Transitional Provisions) Regulations 2023",
        ~S"""
        <P1 id="regulation-3"><Pnumber>3</Pnumber><P1para>
        <P2 id="regulation-3-1"><Pnumber>1</Pnumber><P2para><Text>The following provisions of the Building Safety Act 2022 come into force on 6th April 2023—</Text>
        <P3 id="regulation-3-1-r"><Pnumber>r</Pnumber><P3para><Text>section 39 (breach of building regulations), for the purpose of making regulations under section 35 of the Building Act 1984;</Text></P3para></P3>
        <P3 id="regulation-3-1-s"><Pnumber>s</Pnumber><P3para><Text>section 42 (regulation of building control profession), for the purpose of making regulations under sections 58C, 58O, 58U, 58V, 58Z4 and 58Z5 of the Building Act 1984;</Text></P3para></P3>
        </P2para></P2></P1para></P1>
        """
      )

    rules =
      Order.rules(order, %{law: "UK_ukpga_2022_30", title: "Building Safety Act", year: "2022"})

    assert refs(rules) == ["s.39", "s.42"]
    assert Enum.all?(rules, &(&1.purposes != nil))
  end

  test "a section number with digits after its letter is one number (\"sections 58Z4 and 58Z5\")" do
    assert Order.refs_in("sections 58V, 58Z4 and 58Z5") == ["s.58V", "s.58Z4", "s.58Z5"]
  end

  test "SI 2010/2169 art.3(3): a colon in a bracketed heading opens no list; s.76A(2) is the Water Industry Act 1991's" do
    order =
      doc(
        "UK_uksi_2010_2169",
        "The Flood and Water Management Act 2010 (Commencement No. 1 and Transitional Provisions) Order 2010",
        ~S"""
        <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Flood and Water Management Act 2010.</Text></P1para></P1>
        <P1 id="article-3"><Pnumber>3</Pnumber><P1para>
        <P2 id="article-3-3"><Pnumber>3</Pnumber><P2para><Text>Section 36 of the Act (water use: temporary bans) comes into force on 1stSeptember2010, so far as the amendments made by that section provide power for the Minister, as defined in section 76A(4) of the Water Industry Act 1991 (temporary bans: supplemental), to make an order under section 76A(2) of that Act.</Text></P2para></P2>
        </P1para></P1>
        """
      )

    rules =
      Order.rules(order, %{
        law: "UK_ukpga_2010_29",
        title: "Flood and Water Management Act",
        year: "2010"
      })

    assert refs(rules) == ["s.36"]
    assert [%{purposes: p}] = rules
    assert p != nil
  end

  test "SI 2012/57 art.4(1)(ee)(i)(dd): \"sections 33A to 33C and 33E to 33O including italic headings … of the 2000 Act\" are the 2000 Act's" do
    order =
      doc(
        "UK_uksi_2012_57",
        "The Localism Act 2011 (Commencement No. 2 and Transitional and Saving Provision) Order 2012",
        ~S"""
        <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Localism Act 2011 and “the 2000 Act” means the Local Government Act 2000.</Text></P1para></P1>
        <P1 id="article-4"><Pnumber>4</Pnumber><P1para>
        <P2 id="article-4-1"><Pnumber>1</Pnumber><P2para><Text>The following provisions of the Act (so far as they are not yet in force) come into force in relation to England and Wales on 15th January 2012—</Text>
        <P3 id="article-4-1-dd"><Pnumber>dd</Pnumber><P3para><Text>section 230; and</Text></P3para></P3>
        <P3 id="article-4-1-ee"><Pnumber>ee</Pnumber><P3para><Text>the following parts of Schedule 25 and section 237 so far as relating to those Parts—</Text>
        <P4 id="article-4-1-ee-i"><Pnumber>i</Pnumber><P4para><Text>Part 4 so far as they relate to the repeal of—</Text>
        <P5 id="article-4-1-ee-i-dd"><Pnumber>dd</Pnumber><P5para><Text>sections 33A to 33C and 33E to 33O including italic headings immediately preceding section 33J and section 33O of the 2000 Act;</Text></P5para></P5>
        </P4para></P4></P3para></P3>
        </P2para></P2></P1para></P1>
        """
      )

    all =
      refs(Order.rules(order, %{law: "UK_ukpga_2011_20", title: "Localism Act", year: "2011"}))

    assert "s.230" in all
    refute Enum.any?(all, &(&1 =~ ~r/^s\.33/)), inspect(all)
  end
end
