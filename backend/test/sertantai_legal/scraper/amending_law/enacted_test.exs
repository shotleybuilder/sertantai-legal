defmodule SertantaiLegal.Scraper.AmendingLaw.EnactedTest do
  @moduledoc "A repeals Schedule as enacted where the revised text leaves it out (CV-06a, U12)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Enacted}

  defp doc(schedules),
    do:
      Doc.new("UK_ukpga_1975_71", [
        "<Legislation><Primary><Schedules>" <> schedules <> "</Schedules></Primary></Legislation>"
      ])

  @title_only ~S|<Schedule id="schedule-18"><Number>SCHEDULE 18</Number><TitleBlock><Title>Enactments Repealed</Title></TitleBlock><Reference>Section 125.</Reference></Schedule>|
  @table ~S|<Schedule id="schedule-17"><Tabular><table><tbody><tr><td>1961 c. 34.</td><td>Factories Act 1961.</td><td>Section 1.</td></tr></tbody></table></Tabular></Schedule>|

  test "a Schedule left as its title, or not held, is empty; one with a table is not" do
    d = doc(@title_only <> @table)
    assert Enacted.empty?(d, "schedule-18")
    assert Enacted.empty?(d, "schedule-3")
    refute Enacted.empty?(d, "schedule-17")
  end

  test "wanted: the empty Schedules the pointers name, each once" do
    d = doc(@title_only <> @table)

    refs = [
      {:schedule, "18", nil, nil, []},
      {:schedule, "18", nil, "2", []},
      {:schedule, "17", nil, nil, []},
      {:section, "125", []}
    ]

    assert Enacted.wanted(d, refs) == ["schedule-18"]
  end

  test "wanted: a provision held repealed (its number and dots), never one with text (EPA 1990 Sch. 15 para. 14; OSA 1992 s.4)" do
    d =
      Doc.new("UK_ukpga_1990_43", [
        ~S|<Legislation><Primary><Body><P1 id="section-4"><Pnumber>4</Pnumber><P1para><Text>. . . . . . .</Text></P1para></P1><P1 id="section-5"><Pnumber>5</Pnumber><P1para><Text>In section 2 insert—</Text></P1para></P1></Body><Schedules><Schedule id="schedule-15"><ScheduleBody><P1 id="schedule-15-paragraph-14"><Pnumber>14</Pnumber><P1para><Text>. . . . . . .</Text></P1para></P1><P1 id="schedule-15-paragraph-15"><Pnumber>15</Pnumber><P1para><Text>In section 3 omit “x”. and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and and</Text></P1para></P1></ScheduleBody></Schedule></Schedules></Primary></Legislation>|
      ])

    refs = [
      {:section, "4", ["1", "6"]},
      {:section, "5", []},
      {:schedule, "15", nil, "14", ["b"]},
      {:schedule, "15", nil, "15", []}
    ]

    assert Enacted.wanted(d, refs) == ["schedule-15-paragraph-14", "section-4"]

    assert Enacted.path("UK_ukpga_1990_43", "schedule-15-paragraph-14") ==
             "/ukpga/1990/43/schedule/15/paragraph/14/enacted/data.xml"

    assert Enacted.id("data/cache/clml/ukpga/1992/15/enacted/section/4/data.xml.gz") ==
             "section-4"

    assert Enacted.id(
             "data/cache/clml/ukpga/1990/43/enacted/schedule/15/paragraph/14/data.xml.gz"
           ) ==
             "schedule-15-paragraph-14"
  end

  test "an Act's Schedule as enacted, an SI's as made; kept apart under enacted/" do
    assert Enacted.path("UK_ukpga_1975_71", "schedule-18") ==
             "/ukpga/1975/71/schedule/18/enacted/data.xml"

    assert Enacted.path("UK_uksi_1977_746", "schedule-3") ==
             "/uksi/1977/746/schedule/3/made/data.xml"

    assert Enacted.path("UK_ukpga_1986_59", "schedule") ==
             "/ukpga/1986/59/schedule/enacted/data.xml"

    assert Enacted.store_path("UK_ukpga_1975_71", "schedule-18") ==
             "/ukpga/1975/71/enacted/schedule/18/data.xml"

    assert Enacted.id("data/cache/clml/ukpga/1975/71/enacted/schedule/18/data.xml.gz") ==
             "schedule-18"

    assert Enacted.id("data/cache/clml/ukpga/1986/59/enacted/schedule/data.xml.gz") == "schedule"
  end
end
