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
