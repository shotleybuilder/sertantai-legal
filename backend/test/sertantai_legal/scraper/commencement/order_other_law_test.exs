defmodule SertantaiLegal.Scraper.Commencement.OrderOtherLawTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader — another law's provisions
  are never the commenced Act's, each from the order's own words: a two-Act
  order's statements go to the Act each names; "of that Act" points to the
  law its item names; "of, and Schedule 5 to, the Police Act 1996".
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  defp doc(law, title, body),
    do:
      Doc.new(law, [
        ~s(<Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>#{title}</dc:title><Secondary><Body>#{body}</Body></Secondary></Legislation>)
      ])

  defp scopes(rules), do: Enum.map(rules, &{&1.source.ref, &1.scope, &1.purposes})

  defp refs(rules), do: rules |> Enum.flat_map(& &1.scope) |> Enum.sort()

  describe "a two-Act order (SI 2024/452)" do
    @planning %{law: "UK_ukpga_2008_29", title: "Planning Act", year: "2008"}
    @levelling %{
      law: "UK_ukpga_2023_55",
      title: "Levelling-up and Regeneration Act",
      year: "2023"
    }

    defp two_act_order do
      doc(
        "UK_uksi_2024_452",
        "The Planning Act 2008 (Commencement No. 8) and Levelling-up and Regeneration Act 2023 (Commencement No. 4 and Transitional Provisions) Regulations 2024",
        ~S"""
        <P1 id="regulation-1"><P1para>
        <P2 id="regulation-1-1"><Pnumber>1</Pnumber><P2para><Text>These Regulations may be cited as the Planning Act 2008 (Commencement No. 8) and Levelling-up and Regeneration Act 2023 (Commencement No. 4 and Transitional Provisions) Regulations 2024.</Text></P2para></P2>
        <P2 id="regulation-1-2"><Pnumber>2</Pnumber><P2para><Text>In these Regulations—</Text><UnorderedList Class="Definition">
        <ListItem><Para><Text>“the 1990 Act” means the Town and Country Planning Act 1990;</Text></Para></ListItem>
        <ListItem><Para><Text>“the 2008 Act” means the Planning Act 2008;</Text></Para></ListItem>
        <ListItem><Para><Text>“the 2023 Act” means the Levelling-up and Regeneration Act 2023.</Text></Para></ListItem>
        </UnorderedList></P2para></P2>
        </P1para></P1>
        <P1 id="regulation-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions of the 2008 Act come into force on 25th April 2024—</Text>
        <P3 id="regulation-2-a"><Pnumber>a</Pnumber><P3para><Text>section 196 (determination of procedure for certain proceedings), and</Text></P3para></P3>
        <P3 id="regulation-2-b"><Pnumber>b</Pnumber><P3para><Text>paragraphs 1, 7, 8 and 10 to 14 of Schedule 10 (further provisions as to the procedure for certain proceedings),</Text></P3para></P3>
        </P1para></P1>
        <P1 id="regulation-3"><Pnumber>3</Pnumber><P1para><Text>The following provisions of the 2023 Act come into force on 25th April 2024—</Text>
        <P3 id="regulation-3-a"><Pnumber>a</Pnumber><P3para><Text>section 103 (temporary stop notices in relation to listed buildings);</Text></P3para></P3>
        <P3 id="regulation-3-b"><Pnumber>b</Pnumber><P3para><Text>section 115 (time limits for enforcement);</Text></P3para></P3>
        </P1para></P1>
        <P1 id="regulation-4"><Pnumber>4</Pnumber><P1para><Text>Section 105 of the 2023 Act (removal of compensation for building preservation notice) comes into force on 25th July 2024.</Text></P1para></P1>
        """
      )
    end

    test "\"The following provisions of the 2008 Act\": the Planning Act 2008's only" do
      rules = Order.rules(two_act_order(), @planning)

      assert refs(rules) ==
               Enum.sort([
                 "s.196",
                 "sch.10.para.1",
                 "sch.10.para.7",
                 "sch.10.para.8",
                 "sch.10.para.10..sch.10.para.14"
               ])

      assert Enum.all?(rules, &(&1.source.ref == "reg.2"))
    end

    test "\"The following provisions of the 2023 Act\", \"Section 105 of the 2023 Act\": the 2023 Act's only" do
      rules = Order.rules(two_act_order(), @levelling)

      assert scopes(rules) == [
               {"reg.3", ["s.103"], nil},
               {"reg.3", ["s.115"], nil},
               {"reg.4", ["s.105"], nil}
             ]
    end
  end

  describe "\"of that Act\": the law its item names" do
    @road_safety %{law: "UK_ukpga_2006_49", title: "Road Safety Act", year: "2006"}
    @police_reform %{law: "UK_ukpga_2002_30", title: "Police Reform Act", year: "2002"}

    test "\"section 30 in so far as section 3ZA of the Road Traffic Act 1988 has effect for the purposes of sections 3 and 3A of that Act\" (SI 2007/2472 art.2(h))" do
      order =
        doc(
          "UK_uksi_2007_2472",
          "The Road Safety Act 2006 (Commencement No. 2) Order 2007",
          ~S"""
          <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions of the Road Safety Act 2006 shall come into force on 24th September 2007—</Text>
          <P3 id="article-2-g"><Pnumber>g</Pnumber><P3para><Text>section 29;</Text></P3para></P3>
          <P3 id="article-2-h"><Pnumber>h</Pnumber><P3para><Text>section 30 in so far as section 3ZA of the Road Traffic Act 1988 has effect for the purposes of sections 3 and 3A of that Act;</Text></P3para></P3>
          <P3 id="article-2-i"><Pnumber>i</Pnumber><P3para><Text>section 31;</Text></P3para></P3>
          </P1para></P1>
          """
        )

      assert scopes(Order.rules(order, @road_safety)) == [
               {"reg.2", ["s.29"], nil},
               {"reg.2", ["s.30"], :in_relation_to},
               {"reg.2", ["s.31"], nil}
             ]
    end

    test "\"section 63(3)(b), Chapter 1 of Part 4 and section 86 of, and Schedule 5 to, the Police Act 1996 and in section 105(2) of that Act the words …\" (SI 2004/913 art.2(f)(iv))" do
      order =
        doc(
          "UK_uksi_2004_913",
          "The Police Reform Act 2002 (Commencement No. 8) Order 2004",
          ~S"""
          <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions of the Police Reform Act 2002 shall come into force on 1st April 2004—</Text>
          <P3 id="article-2-d"><Pnumber>d</Pnumber><P3para><Text>Schedule 3 (handling of complaints and conduct matters etc.) to the extent not already in force;</Text></P3para></P3>
          <P3 id="article-2-f"><Pnumber>f</Pnumber><P3para><Text>in Schedule 8 (repeals), the entries relating to—</Text>
          <P4 id="article-2-f-iv"><Pnumber>iv</Pnumber><P4para><Text>section 63(3)(b), Chapter 1 of Part 4 and section 86 of, and Schedule 5 to, the Police Act 1996 and in section 105(2) of that Act the words from “paragraph 8” to “that paragraph”;</Text></P4para></P4>
          <P4 id="article-2-f-vi"><Pnumber>vi</Pnumber><P4para><Text>section 39(3) of the Police Act 1997;</Text></P4para></P4>
          </P3para></P3>
          </P1para></P1>
          """
        )

      held = refs(Order.rules(order, @police_reform))

      assert "sch.3" in held
      assert held -- ["sch.3", "sch.8"] == []
    end
  end

  describe "\"of and Schedule 2 to the 1996 Act\" (SI 1999/3271 art.4(d))" do
    @gla %{law: "UK_ukpga_1999_29", title: "Greater London Authority Act", year: "1999"}

    test "the entries' sections and Schedule are the 1996 Act's; the Part of the repeals Schedule, partly" do
      order =
        doc(
          "UK_uksi_1999_3271",
          "The Greater London Authority Act 1999 (Commencement No. 2) Order 1999",
          ~S"""
          <P1 id="article-1"><P1para><P2 id="article-1-2"><Pnumber>2</Pnumber><P2para><Text>In this Order “the 1999 Act” means the Greater London Authority Act 1999 and “the 1996 Act” means the Police Act 1996.</Text></P2para></P2></P1para></P1>
          <P1 id="article-4"><Pnumber>4</Pnumber><P1para><Text>The following provisions of the 1999 Act shall come into force on 1st April 2000:</Text>
          <P3 id="article-4-a"><Pnumber>a</Pnumber><P3para><Text>section 323 (alteration of the metropolitan police district);</Text></P3para></P3>
          <P3 id="article-4-d"><Pnumber>d</Pnumber><P3para><Text>the entries in Part VII of Schedule 34 which relate to sections 1(3) and 32(5) of and Schedule 2 to the 1996 Act (repeals consequential on alteration of metropolitan police district).</Text></P3para></P3>
          </P1para></P1>
          """
        )

      assert scopes(Order.rules(order, @gla)) == [
               {"reg.4", ["s.323"], nil},
               {"reg.4", ["sch.34.pt.VII"], :in_relation_to}
             ]
    end
  end

  describe "another law's Part as a purpose (SI 2021/1322 art.3)" do
    @equality %{law: "UK_ukpga_2010_15", title: "Equality Act", year: "2010"}

    test "\"for the purposes of the application of Part 1 of the 2006 Act in Wales and Scotland only\": no Part 1 of the Equality Act 2010" do
      order =
        doc(
          "UK_uksi_2021_1322",
          "The Equality Act 2010 (Commencement No. 16) (Wales and Scotland) Order 2021",
          ~S"""
          <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>In this Order, “the 2006 Act” means the Equality Act 2006.</Text></P1para></P1>
          <P1 id="article-3"><Pnumber>3</Pnumber><P1para><Text>The provision specified in article 4 comes into force on the day after the day on which this Order is made, for the purposes of the application of Part 1 of the 2006 Act in Wales and Scotland only.</Text></P1para></P1>
          <P1 id="article-4"><Pnumber>4</Pnumber><P1para><Text>The provision is paragraph 76 of Schedule 26 to the Equality Act 2010, in so far as it relates to section 34(2)(a) of the 2006 Act, as substituted by sub-paragraph (3)(b) of that paragraph.</Text></P1para></P1>
          """
        )

      refute "pt.1" in refs(Order.rules(order, @equality))
    end
  end

  describe "the Act named by its title without its year (SI 1998/781 art.2)" do
    @environment %{law: "UK_ukpga_1995_25", title: "Environment Act", year: "1995"}

    test "\"Section 116 of the Environment Act, insofar as it relates to paragraph 4 of Schedule 21, shall come into force on 8th April 1998\": the Act's own" do
      order =
        doc(
          "UK_uksi_1998_781",
          "The Environment Act 1995 (Commencement No. 12 and Transitional Provisions) (Scotland) Order 1998",
          ~S"""
          <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>This Order may be cited as the Environment Act 1995 (Commencement No. 12 and Transitional Provisions) (Scotland) Order 1998.</Text></P1para></P1>
          <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>Section 116 of the Environment Act, insofar as it relates to paragraph 4 of Schedule 21, shall come into force on 8th April 1998.</Text></P1para></P1>
          """
        )

      assert "s.116" in refs(Order.rules(order, @environment))
    end
  end

  describe "\"after … have come into force\": a transitional sentence, no commencement (SI 1994/3262 art.3(2))" do
    @pmca %{law: "UK_ukpga_1994_29", title: "Police and Magistrates' Courts Act", year: "1994"}

    test "\"As respects the first report … after the amendments made by paragraphs 1(2)(a) and 8(3) of Schedule 5 to the 1994 Act have come into force, those sections shall have effect as if …\" gives no rule" do
      order =
        doc(
          "UK_uksi_1994_3262",
          "The Police and Magistrates' Courts Act 1994 (Commencement No. 5 and Transitional Provisions) Order 1994",
          ~S"""
          <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>In this Order—</Text><UnorderedList Class="Definition">
          <ListItem><Para><Text>“the 1964 Act” means the Police Act 1964;</Text></Para></ListItem>
          <ListItem><Para><Text>“the 1994 Act” means the Police and Magistrates' Courts Act 1994;</Text></Para></ListItem>
          </UnorderedList></P1para></P1>
          <P1 id="article-3"><Pnumber>3</Pnumber><P1para>
          <P2 id="article-3-1"><Pnumber>1</Pnumber><P2para><Text>Section 93 of the 1994 Act shall come into force on 31st December 1994.</Text></P2para></P2>
          <P2 id="article-3-2"><Pnumber>2</Pnumber><P2para><Text>As respects the first report which is required to be made under section 12(1) of the 1964 Act or submitted to the Secretary of State under section 30(2) of that Act after the amendments made by paragraphs 1(2)(a) and 8(3) of Schedule 5 to the 1994 Act have come into force, those sections shall have effect as if, for any reference to the financial year, there was substituted a reference to the period of fifteen months ending with 31st March 1995.</Text></P2para></P2>
          </P1para></P1>
          """
        )

      assert scopes(Order.rules(order, @pmca)) == [{"reg.3(1)", ["s.93"], nil}]
    end
  end
end
