defmodule SertantaiLegal.Scraper.ChangeCollector.MarkupTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeCollector.{Markup, Record}

  @law "UK_ukpga_1974_37"

  test "change markup no effect explains: a record per change, source markup, no date or law" do
    rows = [
      %{section_id: "#{@law}:s.1", unjoined_changes: [{"d29p1", "c124", "repealed"}]},
      %{section_id: "#{@law}:s.2", unjoined_changes: []},
      %{section_id: "#{@law}:s.3"}
    ]

    assert [
             %Record{
               law_name: @law,
               section_id: "UK_ukpga_1974_37:s.1",
               via: ["markup"],
               pointer: "c124",
               source: "markup",
               evidence: "d29p1",
               operation: "repealed",
               effective_from: nil,
               affecting_law: nil
             }
           ] = Markup.records(@law, rows)
  end

  test "the same change id on two rows: a record for each row" do
    rows = [
      %{section_id: "#{@law}:s.1", unjoined_changes: [{"d30p2", "c9", "inserted"}]},
      %{section_id: "#{@law}:s.1(a)", unjoined_changes: [{"d30p2", "c9", "inserted"}]}
    ]

    assert Markup.records(@law, rows) |> Enum.map(& &1.section_id) == [
             "#{@law}:s.1",
             "#{@law}:s.1(a)"
           ]
  end
end
