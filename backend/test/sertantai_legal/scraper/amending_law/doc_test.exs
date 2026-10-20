defmodule SertantaiLegal.Scraper.AmendingLaw.DocTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Locator, Text}

  @dir "test/fixtures/amending_law"
  defp doc,
    do:
      Doc.new("UK_ukpga_2000_27", [
        File.read!("#{@dir}/ukpga_2000_27_body.xml"),
        File.read!("#{@dir}/ukpga_2000_27_schedules.xml")
      ])

  test "Doc: ids, enactment date, the container title over each element" do
    d = doc()
    assert %Doc{law_name: "UK_ukpga_2000_27", type: "ukpga", enactment_date: ~D[2000-07-28]} = d
    assert Doc.element(d, "section-60-5") != nil
    assert Doc.title(d, "schedule-6-paragraph-33-c") == "Electricity Act 1989"
    assert Doc.title(d, "section-60-5") == "Orders"
  end

  test "Text: the instruction without quoted words, the quoted words apart; ancestors' text as context" do
    d = doc()
    t = Text.of(d, "section-60-5")
    assert t.instruction == "After subsection (5) of that section there is inserted—"
    assert t.quoted =~ "5A"

    assert t.context == [
             "The 1989 Act is amended as follows.",
             "In subsection (1) of section 25 (orders for securing compliance), for “and (5)” there is substituted .",
             "In subsection (5) of that section, paragraphs (b) and (c) shall cease to have effect."
           ]

    sch = Text.of(d, "schedule-6-paragraph-33-c")
    assert sch.instruction =~ "in subsection (2) for"

    assert sch.context == [
             "In section 40 (overall standards of performance)—",
             "in subsection (2) at the end there is inserted ;"
           ]
  end

  test "Locator: a pointer ref to the held ids — the path as far as it is held, Schedule parts ignored" do
    d = doc()
    assert Locator.ids(d, {:section, "60", ["5", "7"]}) == ["section-60-5"]
    assert Locator.ids(d, {:section, "60", []}) == ["section-60"]
    assert Locator.ids(d, {:schedule, "6", "II", "33", ["c"]}) == ["schedule-6-paragraph-33-c"]
    assert Locator.ids(d, {:schedule, "8", nil, nil, []}) == ["schedule-8"]
    assert Locator.ids(d, {:section, "999", []}) == []
  end
end
