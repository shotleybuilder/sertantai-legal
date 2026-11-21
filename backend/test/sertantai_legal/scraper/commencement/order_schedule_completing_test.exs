defmodule SertantaiLegal.Scraper.Commencement.OrderScheduleCompletingTest do
  @moduledoc """
  A Schedule table's row "Section 1, so far as not already commenced"
  completes the section, as "so far as not already in force" does; "in
  relation to England only" leaves it partly in force (LAT Change Pipeline,
  step Commencement reader). The Flood and Water Management Act 2010
  (Commencement No. 1 and Transitional Provisions) Order 2010 (SI
  2010/2169) art.4 and its Schedule.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @act %{law: "UK_ukpga_2010_29", title: "Flood and Water Management Act", year: "2010"}

  defp rules do
    Doc.new("UK_uksi_2010_2169", [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Flood and Water Management Act 2010 (Commencement No. 1 and Transitional Provisions) Order 2010</dc:title><Secondary><Body>
      <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>In this Order, “the Act” means the Flood and Water Management Act 2010.</Text></P1para></P1>
      <P1 id="article-4"><Pnumber>4</Pnumber><P1para><Text>The provisions of the Act specified in the Schedule come into force on 1st October 2010.</Text></P1para></P1>
      </Body><Schedules><Schedule id="schedule"><Number>SCHEDULE</Number><TitleBlock><Title>Provisions coming into force on 1st October 2010</Title></TitleBlock><Reference>article 4</Reference><ScheduleBody><Tabular><table xmlns="http://www.w3.org/1999/xhtml">
      <thead><tr><th>Provision of the Act</th><th>Subject matter</th></tr></thead>
      <tbody><tr><td>Section 1, so far as not already commenced</td><td>Definitions of “flood” and “coastal erosion”</td></tr>
      <tr><td>Section 5</td><td>Definition of “coastal erosion risk management function”</td></tr>
      <tr><td>Section 7, in relation to England only</td><td>National flood and coastal erosion risk management strategy: England</td></tr></tbody>
      </table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>
      """
    ])
    |> Order.rules(@act)
    |> Enum.filter(&(&1.treatment == :order_schedule))
    |> Map.new(&{&1.scope, &1})
  end

  test "so far as not already commenced completes the section; a place leaves it partly in force" do
    rules = rules()

    assert rules[["s.1"]].when == {:date, ~D[2010-10-01]}
    assert rules[["s.1"]].purposes == nil
    assert rules[["s.5"]].purposes == nil
    assert rules[["s.7"]].purposes != nil
    assert rules[["s.7"]].territory == "E"
  end
end
