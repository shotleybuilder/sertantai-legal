defmodule SertantaiLegal.Scraper.AmendingLaw.DocTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Locator, RowRef, Text}

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

  test "RowRef: a LAT row's law and provision path" do
    assert %RowRef{
             law_name: "UK_ukpga_1989_29",
             year: "1989",
             number: "29",
             kind: :section,
             number_ref: "25",
             subs: ["5A"]
           } =
             RowRef.new("UK_ukpga_1989_29:s.25(5A)", "Electricity Act")

    assert %RowRef{kind: :regulation, number_ref: "4", subs: ["2", "b"]} =
             RowRef.new("UK_uksi_1999_1:reg.4(2)(b)", "X Regulations")

    assert %RowRef{kind: :section, number_ref: "13", subs: ["1A"]} =
             RowRef.new("UK_ukpga_1974_40:s.13(1A)[S]", "Control of Pollution Act")

    assert RowRef.new("UK_ukpga_1974_40:pt.II", "Act").kind == :other
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
