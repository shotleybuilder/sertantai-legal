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

  test "an SI's Schedule: its Reference names a regulation or article (CV-S05 round 8 NEW-5)" do
    doc =
      Doc.new("UK_uksi_2019_696", [
        ~S|<Legislation><Secondary><Body><P1 id="regulation-30"><P1para><Text>Schedule 27 contains amendment of the Measuring Instruments Regulations 2016.</Text></P1para></P1></Body><Schedules><Schedule id="schedule-27"><Reference>Regulation 30</Reference></Schedule><Schedule id="schedule-2"><Reference>Article 3(2)</Reference></Schedule></Schedules></Secondary></Legislation>|
      ])

    assert ScheduleRefs.references(doc) == %{
             "schedule-27" => "regulation-30",
             "schedule-2" => "article-3"
           }
  end
end
