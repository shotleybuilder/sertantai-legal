defmodule SertantaiLegal.Scraper.Commencement.OrderScheduleProvisionColumnTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader — a Schedule table whose
  columns are "Schedule | Provision": the second cell lists the paragraphs
  of the Schedule the first names, and only those come into force. The
  Water Act 2003 (Commencement No. 1 and Transitional Provisions) Order 2004
  (SI 2004/641) Schedule 2 ("Schedule 8 | In paragraph 1, sub-paragraph (4),
  … Paragraphs 19, 23, 43, 44 and 48 …") had brought the whole of Schedule 8
  in on 1 April 2004, dating 160 of its insertions into the Water Industry
  and Water Resources Acts 1991 a year or more early.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @act %{law: "UK_ukpga_2003_37", title: "Water Act", year: "2003"}

  defp rules do
    Doc.new("UK_uksi_2004_641", [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Act 2003 (Commencement No. 1 and Transitional Provisions) Order 2004</dc:title><Secondary><Body>
      <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Water Act 2003.</Text></P1para></P1>
      </Body><Schedules><Schedule id="schedule-2"><Number>SCHEDULE 2</Number><TitleBlock><Title>MINOR AND CONSEQUENTIAL AMENDMENTS AND REPEALS: PROVISIONS COMING INTO FORCE ON 1ST APRIL 2004</Title></TitleBlock><Reference>Article 3(y)</Reference><ScheduleBody><Tabular><table xmlns="http://www.w3.org/1999/xhtml">
      <thead><tr><th>Schedule</th><th>Provision</th></tr></thead>
      <tbody><tr><td>Schedule 7</td><td>Paragraphs 6, 14, 31, 37 and 40, and paragraph 1 in so far as it relates to those paragraphs.</td></tr>
      <tr><td>Schedule 8</td><td>In paragraph 1, sub-paragraph (4), and sub-paragraph (1) in so far as it relates to that sub-paragraph. Paragraphs 19, 23, 43, 44 and 48, and paragraph 2 in so far as it relates to those paragraphs.</td></tr></tbody>
      </table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>
      """
    ])
    |> Order.rules(@act)
    |> Enum.filter(&(&1.treatment == :order_schedule))
  end

  test "the Provision column names the Schedule's paragraphs; the Schedule itself is never brought in whole" do
    rules = rules()
    scopes = rules |> Enum.flat_map(& &1.scope) |> MapSet.new()

    refute "sch.7" in scopes
    refute "sch.8" in scopes

    for ref <-
          ~w[sch.7.para.6 sch.7.para.14 sch.7.para.40 sch.8.para.1(4) sch.8.para.19 sch.8.para.48],
        do: assert(ref in scopes, "#{ref} in #{inspect(MapSet.to_list(scopes))}")

    assert Enum.all?(rules, &(&1.when == {:date, ~D[2004-04-01]}))
  end
end
