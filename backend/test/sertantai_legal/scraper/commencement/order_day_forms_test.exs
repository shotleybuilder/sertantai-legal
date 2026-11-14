defmodule SertantaiLegal.Scraper.Commencement.OrderDayFormsTest do
  @moduledoc """
  Fire and OH&S: Commencement reader — an order's completing start for one
  place, and its "day appointed" statements, each from the order's own
  words.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}

  defp doc(law, title, body, schedules \\ ""),
    do:
      Doc.new(law, [
        ~s(<Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>#{title}</dc:title><Secondary><Body>#{body}</Body>#{schedules}</Secondary></Legislation>)
      ])

  defp lines(rules),
    do: Enum.map(rules, &(&1 |> Rule.to_text() |> String.split(" — UK_") |> hd()))

  describe "the part for one place not already commenced (SI 1992/2984 and SI 1992/2990 Sch.2)" do
    @nrswa %{law: "UK_ukpga_1991_22", title: "New Roads and Street Works Act", year: "1991"}

    defp nrswa_order(law, title, place, more \\ " and has not already been commenced") do
      doc(
        law,
        title,
        ~S"""
        <P1 id="article-1"><P1para><P2 id="article-1-2"><P2para><Text>In this Order “the 1991 Act” means the New Roads and Street Works Act 1991.</Text></P2para></P2></P1para></P1>
        <P1 id="article-2"><P1para><P2 id="article-2-2"><Pnumber>2</Pnumber><P2para><Text>The provisions of the 1991 Act specified in the first column of Schedule 2 to this Order (which relates to the matters specified in the second column thereof) shall come into force on 1st January 1993.</Text></P2para></P2></P1para></P1>
        """,
        ~s"""
        <Schedules><Schedule id="schedule-2"><Number>SCHEDULE 2</Number><Reference>Article 2(2)</Reference><ScheduleBody><Tabular><table><tbody>
        <tr><td>Section 168 in so far as it relates to the provisions of Schedules 8 and 9 of the 1991 Act referred to in this Schedule</td><td>Minor and consequential amendments and repeals</td></tr>
        <tr><td>Schedule 8 in so far as it relates to #{place}#{more}</td><td>Minor and consequential amendments</td></tr>
        <tr><td>Schedule 9 in so far as it relates to #{place}#{more}</td><td>Repeals</td></tr>
        </tbody></table></Tabular></ScheduleBody></Schedule></Schedules>
        """
      )
    end

    test "“Schedule 8 in so far as it relates to England and Wales and has not already been commenced”: fully, there" do
      order =
        nrswa_order(
          "UK_uksi_1992_2984",
          "The New Roads and Street Works Act 1991 (Commencement No. 5 and Transitional Provisions and Savings) Order 1992",
          "England and Wales"
        )

      assert lines(Order.rules(order, @nrswa)) == [
               "s.168 — 1993-01-01 — everywhere, in relation to — order_schedule",
               "sch.8 — 1993-01-01 — E+W, fully — order_schedule",
               "sch.9 — 1993-01-01 — E+W, fully — order_schedule"
             ]
    end

    test "“… in so far as it relates to Scotland and has not already been commenced”: fully, in Scotland" do
      order =
        nrswa_order(
          "UK_uksi_1992_2990",
          "The New Roads and Street Works Act 1991 (Commencement No.6 and Transitional Provisions and Savings) (Scotland) Order 1992",
          "Scotland"
        )

      assert order |> Order.rules(@nrswa) |> lines() |> Enum.drop(1) == [
               "sch.8 — 1993-01-01 — S, fully — order_schedule",
               "sch.9 — 1993-01-01 — S, fully — order_schedule"
             ]
    end

    test "relating to a place alone, with no completing words, stays partial" do
      order =
        nrswa_order("UK_uksi_1992_2984", "The New Roads … Order 1992", "England and Wales", "")

      assert [_, sch8, _] = order |> Order.rules(@nrswa) |> lines()
      assert sch8 =~ "in relation to"
    end
  end

  describe "the day appointed for the whole law" do
    test "date first: “1st April 2013 is the day appointed for the coming into force of the Act, so far as not already in force.” (SSI 2013/51 art.2)" do
      order =
        doc(
          "UK_ssi_2013_51",
          "The Police and Fire Reform (Scotland) Act 2012 (Commencement No. 4, Transitory and Transitional Provisions) Order 2013",
          ~S"""
          <P1 id="article-1"><P1para><P2 id="article-1-2"><P2para><Text>In this Order “the Act” means the Police and Fire Reform (Scotland) Act 2012.</Text></P2para></P2></P1para></P1>
          <P1 id="article-2"><P1para><Text>1st April 2013 is the day appointed for the coming into force of the Act, so far as not already in force.</Text></P1para></P1>
          """
        )

      act = %{law: "UK_asp_2012_8", title: "Police and Fire Reform (Scotland) Act", year: "2012"}

      assert lines(Order.rules(order, act)) == [
               "all — 2013-04-01 — everywhere, fully — order_date"
             ]
    end

    test "an order naming a longer title does not commence the Act its tail spells (“Police and Fire Reform (Scotland) Act 2012” is not the Scotland Act 2012)" do
      order =
        doc(
          "UK_ssi_2013_51",
          "The Police and Fire Reform (Scotland) Act 2012 (Commencement No. 4, Transitory and Transitional Provisions) Order 2013",
          ~S"""
          <P1 id="article-1"><P1para><P2 id="article-1-2"><P2para><Text>In this Order “the Act” means the Police and Fire Reform (Scotland) Act 2012.</Text></P2para></P2></P1para></P1>
          <P1 id="article-2"><P1para><Text>1st April 2013 is the day appointed for the coming into force of the Act, so far as not already in force.</Text></P1para></P1>
          """
        )

      assert Order.rules(order, %{law: "UK_ukpga_2012_11", title: "Scotland Act", year: "2012"}) ==
               []
    end

    test "an Article named in an order commencing an Act is the order's own, never the Act's (SSI 2015/139 art.1: “Article 3 comes into force on 1st April 2015”)" do
      order =
        doc(
          "UK_ssi_2015_139",
          "The Pollution Prevention and Control Act 1999 (Commencement No. 3) (Scotland) Order 2015",
          ~S"""
          <P1 id="article-1"><P1para><P2 id="article-1-1"><P2para><Text>In this Order “the Act” means the Pollution Prevention and Control Act 1999.</Text></P2para></P2><P2 id="article-1-2"><P2para><Text>Article 3 comes into force on 1st April 2015.</Text></P2para></P2></P1para></P1>
          """
        )

      act = %{
        law: "UK_ukpga_1999_24",
        title: "Pollution Prevention and Control Act",
        year: "1999"
      }

      assert Order.rules(order, act) == []
    end

    test "“In so far as not already in operation, the day appointed for the coming into operation of the … Order 2006 is 15th November 2010” (NISR 2010/328 art.2)" do
      order =
        doc(
          "UK_nisr_2010_328",
          "The Fire and Rescue Services (2006 Order) (Commencement No. 2) Order (Northern Ireland) 2010",
          ~S"""
          <P1 id="article-1"><P1para><Text>This Order may be cited as the Fire and Rescue Services (2006 Order) (Commencement No. 2) Order (Northern Ireland) 2010.</Text></P1para></P1>
          <P1 id="article-2"><P1para><Text>In so far as not already in operation, the day appointed for the coming into operation of the Fire and Rescue Services (Northern Ireland) Order 2006 is 15th November 2010.</Text></P1para></P1>
          """
        )

      act = %{
        law: "UK_nisi_2006_1254",
        title: "Fire and Rescue Services (Northern Ireland) Order",
        year: "2006"
      }

      assert [%Rule{scope: :all, when: {:date, ~D[2010-11-15]}, purposes: nil}] =
               Order.rules(order, act)
    end
  end

  describe "the day appointed for one provision of an Order named by its title" do
    test "“The day appointed for the coming into operation of Article 4(3) of the Offshore, and Pipelines, Safety (Northern Ireland) Order 1992 is 14th July 1996.” (NISR 1996/251 art.2)" do
      order =
        doc(
          "UK_nisr_1996_251",
          "The Offshore, and Pipelines, Safety (1992 Order) (Commencement No. 2) Order (Northern Ireland) 1996",
          ~S"""
          <P1 id="article-1"><P1para><Text>This Order may be cited as the Offshore, and Pipelines, Safety (1992 Order) (Commencement No. 2) Order (Northern Ireland) 1996.</Text></P1para></P1>
          <P1 id="article-2"><P1para><Text>The day appointed for the coming into operation of Article 4(3) of the Offshore, and Pipelines, Safety (Northern Ireland) Order 1992 is 14th July 1996.</Text></P1para></P1>
          """
        )

      act = %{
        law: "UK_nisi_1992_1728",
        title: "Offshore, and Pipelines, Safety (Northern Ireland) Order",
        year: "1992"
      }

      assert [%Rule{scope: ["reg.4(3)"], when: {:date, ~D[1996-07-14]}, purposes: nil}] =
               Order.rules(order, act)
    end
  end

  describe "a repeals Schedule's entries naming other Orders' Articles (NISR 2006/257 art.2(e))" do
    test "“Schedule 4 in so far as it relates to— … Articles 3 to 20 and 49A to 52 of and Schedules 1, 2, 3 and 5 to the Fire Services (Northern Ireland) Order 1984”: Schedule 4 partly, never the 2006 Order's own Articles" do
      order =
        doc(
          "UK_nisr_2006_257",
          "The Fire and Rescue Services (2006 Order) (Commencement No. 1) Order (Northern Ireland) 2006",
          ~S"""
          <P1 id="article-2"><P1para><Text>The day appointed for the coming into operation of the following provisions of the Fire and Rescue Services (Northern Ireland) Order 2006 is 1st July 2006—</Text>
          <P3 id="article-2-a"><Pnumber>a</Pnumber><P3para><Text>Articles 3 to 24;</Text></P3para></P3>
          <P3 id="article-2-b"><Pnumber>b</Pnumber><P3para><Text>Articles 53 to 63;</Text></P3para></P3>
          <P3 id="article-2-c"><Pnumber>c</Pnumber><P3para><Text>Schedules 1 and 2;</Text></P3para></P3>
          <P3 id="article-2-e"><Pnumber>e</Pnumber><P3para><Text>Schedule 4 in so far as it relates to—</Text>
          <P4><Pnumber>i</Pnumber><P4para><Text>The Northern Ireland Assembly Disqualification Act 1975;</Text></P4para></P4>
          <P4><Pnumber>ii</Pnumber><P4para><Text>Articles 3 to 20 and 49A to 52 of and Schedules 1, 2, 3 and 5 to the Fire Services (Northern Ireland) Order 1984;</Text></P4para></P4>
          <P4><Pnumber>iv</Pnumber><P4para><Text>Articles 3, 5 and 6 of the Fire Services (Amendment) (Northern Ireland) Order 1998;</Text></P4para></P4>
          <P4><Pnumber>vi</Pnumber><P4para><Text>The Audit and Accountability (Northern Ireland) Order 2003.</Text></P4para></P4>
          </P3para></P3></P1para></P1>
          """
        )

      act = %{
        law: "UK_nisi_2006_1254",
        title: "Fire and Rescue Services (Northern Ireland) Order",
        year: "2006"
      }

      assert lines(Order.rules(order, act)) == [
               "reg.3..reg.24 — 2006-07-01 — NI, fully — order_date",
               "reg.53..reg.63 — 2006-07-01 — NI, fully — order_date",
               "sch.1, sch.2 — 2006-07-01 — NI, fully — order_date",
               "sch.4 — 2006-07-01 — NI, in relation to — order_date"
             ]
    end
  end
end
