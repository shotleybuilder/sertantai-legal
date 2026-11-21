defmodule SertantaiLegal.Scraper.Commencement.OrderScheduleExceptionTest do
  @moduledoc """
  A Schedule brought in "except in relation to" some cases is partly in
  force (LAT Change Pipeline, step Commencement reader). The Offices, Shops
  and Railway Premises Act 1963 (Commencement No.1) Order 1964 (SI 1964/191)
  art.1 brings in the provisions in Schedule 1's Parts "Except in relation
  to the premises to which Article 2 of this Order applies" (covered market
  places, Schedule 2). So a provision in Schedule 1 is in force partly, and
  never fully unless an order says so (extended golden: OSRPA 1963 s.76,
  s.91 "commenced through its parts, never fully").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @act %{law: "UK_ukpga_1963_41", title: "Offices, Shops and Railway Premises Act", year: "1963"}

  defp order(article_1) do
    Doc.new("UK_uksi_1964_191", [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Offices, Shops and Railway Premises Act 1963 (Commencement No.1) Order 1964</dc:title><Secondary><Body>
      <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>#{article_1}</Text></P1para></P1>
      <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>In relation to premises which are in a covered market place, being a covered market place to which section 51 (power to adapt Act in relation to covered markets) of the Act relates, the provisions of the Act specified in Schedule 2 to this Order shall come into operation on 1st May 1964.</Text></P1para></P1>
      </Body><Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><ScheduleBody>
      <Part id="schedule-1-part-I"><Number>PART I</Number><Title>PROVISIONS COMING INTO OPERATION ON 18TH FEBRUARY 1964</Title><Tabular><table xmlns="http://www.w3.org/1999/xhtml">
      <thead><tr><th>Provisions of the Act</th><th>Subject matter of Provisions</th></tr></thead>
      <tbody><tr><td>Section 57(1)</td><td>Provision for securing discharge of local authorities' duties in uniform manner.</td></tr>
      <tr><td>Section 91(1), (2) and (3)</td><td>Short title, commencement and extent.</td></tr></tbody>
      </table></Tabular></Part>
      </ScheduleBody></Schedule></Schedules></Secondary></Legislation>
      """
    ])
  end

  @except "Except in relation to the premises to which Article 2 of this Order applies, the provisions of the Offices, Shops and Railway Premises Act 1963 (hereafter in this Order referred to as “the Act”) specified in the first column of each of the Parts of Schedule 1 to this Order (which relate to the matters specified in the second column thereof) shall come into operation on the day specified in the heading to the Part of that Schedule in which the provisions are specified."

  defp schedule_rules(rules), do: Enum.filter(rules, &(&1.treatment == :order_schedule))

  test "the Parts of Schedule 1, brought in except for covered markets, are partly in force (SI 1964/191 art.1)" do
    rules = order(@except) |> Order.rules(@act) |> schedule_rules()

    assert rules != []
    assert Enum.all?(rules, &(&1.purposes != nil))
    assert Enum.all?(rules, &(&1.when == {:date, ~D[1964-02-18]}))
    assert Enum.any?(rules, &("s.91(1)" in &1.scope))
  end

  test "the same Schedule with no exception in its article is fully in force" do
    plain =
      String.replace(
        @except,
        "Except in relation to the premises to which Article 2 of this Order applies, the",
        "The"
      )

    rules = order(plain) |> Order.rules(@act) |> schedule_rules()

    assert rules != []
    assert Enum.all?(rules, &(&1.purposes == nil))
  end
end
