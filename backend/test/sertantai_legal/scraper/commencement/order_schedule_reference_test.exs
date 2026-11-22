defmodule SertantaiLegal.Scraper.Commencement.OrderScheduleReferenceTest do
  @moduledoc """
  A Schedule table dated by the article its Reference names, where that
  article's date is in its paragraph: "3.—(1) Subject to paragraph (2),
  10th June 2013 is the day appointed for the coming into force of the
  provisions of the Act specified in column 1 of the table in the
  Schedule" (SSI 2013/163, the Water Resources (Scotland) Act 2013
  (Commencement No. 1) Order 2013; LAT Change Pipeline, step Commencement
  reader).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @act %{law: "UK_asp_2013_5", title: "Water Resources (Scotland) Act", year: "2013"}

  defp row(cells),
    do: "<tr>" <> Enum.map_join(cells, &"<td><Para><Text>#{&1}</Text></Para></td>") <> "</tr>"

  test "the Schedule takes the date in its article's paragraph; column 3's purpose leaves a row partly in force" do
    rules =
      Doc.new("UK_ssi_2013_163", [
        ~s"""
        <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Resources (Scotland) Act 2013 (Commencement No. 1) Order 2013</dc:title><Secondary><Body>
        <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>In this Order, “the Act” means the Water Resources (Scotland) Act 2013.</Text></P1para></P1>
        <P1 id="article-3"><Pnumber>3</Pnumber><P1para>
        <P2 id="article-3-1"><Pnumber>1</Pnumber><P2para><Text>Subject to paragraph (2), 10th June 2013 is the day appointed for the coming into force of the provisions of the Act specified in column 1 of the table in the Schedule (the subject matter of which is specified in column 2 of that table).</Text></P2para></P2>
        <P2 id="article-3-2"><Pnumber>2</Pnumber><P2para><Text>Where a purpose is specified in column 3 of that table, the corresponding provision mentioned in column 1 comes into force in accordance with paragraph (1) only for that purpose.</Text></P2para></P2>
        </P1para></P1>
        </Body><Schedules><Schedule id="schedule"><Number>SCHEDULE</Number><Reference>Article 3</Reference><ScheduleBody><Tabular><table><thead><tr><th>Column 1 Provisions of the Act</th><th>Column 2 Subject matter</th><th>Column 3 Purpose</th></tr></thead><tbody>
        #{row(["Sections 1 to 4", "Development of water resources", ""])}
        #{row(["Sections 5 to 9", "Control of water abstraction: introduction", "The purpose of making subordinate legislation"])}
        </tbody></table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>
        """
      ])
      |> Order.rules(@act)

    assert %{when: {:date, ~D[2013-06-10]}, purposes: nil} =
             Enum.find(rules, &(&1.scope == ["s.1..s.4"]))

    assert %{purposes: p} = Enum.find(rules, &(&1.scope == ["s.5..s.9"]))
    assert p != nil
  end

  test "a Schedule of transitional provisions takes no date from its article's paragraph commencing the article (SI 2005/968 art.4(3))" do
    rules =
      Doc.new("UK_uksi_2005_968", [
        ~s"""
        <Legislation xmlns="http://www.legislation.gov.uk/namespaces/legislation" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Act 2003 (Commencement No. 4, Transitional Provisions and Savings) Order 2005</dc:title><Secondary><Body>
        <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Water Act 2003.</Text></P1para></P1>
        <P1 id="article-4"><Pnumber>4</Pnumber><P1para>
        <P2 id="article-4-1"><Pnumber>1</Pnumber><P2para><Text>The transitional provisions and savings in the Schedules to this Order shall have effect.</Text></P2para></P2>
        <P2 id="article-4-3"><Pnumber>3</Pnumber><P2para><Text>Paragraphs (1) and (2) shall come into force on 1st April 2005.</Text></P2para></P2>
        </P1para></P1>
        </Body><Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>Transitional provisions and savings</Title></TitleBlock><Reference>Article 4</Reference><ScheduleBody><Tabular><table><tbody>
        #{row(["Section 1", "The Consumer Council for Water"])}
        </tbody></table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>
        """
      ])
      |> Order.rules(%{law: "UK_ukpga_2003_37", title: "Water Act", year: "2003"})

    assert rules == []
  end
end
