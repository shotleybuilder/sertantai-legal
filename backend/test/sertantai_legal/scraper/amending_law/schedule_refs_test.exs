defmodule SertantaiLegal.Scraper.AmendingLaw.ScheduleRefsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, ScheduleRefs}

  test "a Schedule's introducing section: its Reference, else the section saying it has effect" do
    doc =
      Doc.new("UK_ukpga_2005_15", [
        ~S|<Legislation><Primary><Body><P1 id="section-111"><P1para><Text>Schedule 7, which supplements section 110, has effect.</Text></P1para></P1></Body><Schedules><Schedule id="schedule-17"><Reference>Section 174(2)</Reference></Schedule></Schedules></Primary></Legislation>|
      ])

    assert ScheduleRefs.references(doc) == %{
             "schedule-7" => "section-111",
             "schedule-17" => "section-174"
           }

    assert ScheduleRefs.reference(doc, "schedule-17") == "section-174"
  end
end
