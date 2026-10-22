defmodule SertantaiLegal.Scraper.AmendingLaw.RefListTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.RefList

  test "a law's own provision list (SOCPA 2005 s.179(3), Coronavirus Act 2020 s.89(2))" do
    assert RefList.parse(
             "sections 60 to 68, 70, 107(1) and (4) and 108, section 123, Schedules 1, 3, 5 and 15, Part 2 of Schedule 10, this section",
             "s.179"
           ) ==
             [
               "s.60..s.68",
               "s.70",
               "s.107(1)",
               "s.107(4)",
               "s.108",
               "s.123",
               "sch.1",
               "sch.3",
               "sch.5",
               "sch.15",
               "sch.10.pt.2",
               "s.179"
             ]

    assert RefList.parse("sections 59 to 70;") == ["s.59..s.70"]
  end

  test "covers?/2: a ref inside an item" do
    assert RefList.covers?("s.59..s.70", "s.62(1)")
    refute RefList.covers?("s.59..s.70", "s.78")
    assert RefList.covers?("sch.7", "sch.7.para.27(2)")
    assert RefList.covers?("s.107", "s.107(4)")
  end
end
