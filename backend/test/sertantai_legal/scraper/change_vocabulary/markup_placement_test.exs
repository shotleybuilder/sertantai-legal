defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPlacementTest do
  @moduledoc "CV-S03: where a markup change lands, each reason a test."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPlacement, as: P

  @held %{
    rows: MapSet.new(["s.1", "s.1(1)", "s.23[E+W]", "s.23[S]", "pt.1", "h.1"]),
    schedules?: false
  }

  test "on rows we hold: placed; as territorial versions: placed_versions" do
    assert P.classify(["s.1(1)"], [], @held) == :placed
    assert P.classify(["s.23"], [], @held) == :placed_versions
  end

  test "deeper than our rows, under a held one: placed_ancestor" do
    assert P.classify(["s.1(1)(a)"], [], @held) == :placed_ancestor
  end

  test "a legacy change across the law: whole_law" do
    assert P.classify(["*"], [], @held) == :whole_law
  end

  test "a change on several provisions is placed only when every one is" do
    assert P.classify(["s.1", "s.9"], [], @held) == {:unplaced, :row_missing}
    assert P.classify(["s.1", "s.23"], [], @held) == :placed
  end

  test "in a schedule while schedules aren't parsed: schedule_not_parsed (K1)" do
    assert P.classify(["sch.2.para.3"], [], @held) == {:unplaced, :schedule_not_parsed}

    assert P.classify([], [["schedule-2", "schedule-2-part-1"]], @held) ==
             {:unplaced, :schedule_not_parsed}
  end

  test "placed nowhere: outside provisions, a group with no row, an id not converted" do
    assert P.classify([], [[]], @held) == {:unplaced, :outside_provisions}
    assert P.classify([], [["part-2"]], @held) == {:unplaced, :group_row_missing}
    assert P.classify([], [["section-4", "term-car"]], @held) == {:unplaced, :id_not_converted}
  end

  test "our faults" do
    assert P.fault?(:row_missing)
    assert P.fault?(:id_not_converted)
    assert P.fault?(:group_row_missing)
    refute P.fault?(:schedule_not_parsed)
    refute P.fault?(:outside_provisions)
  end

  test "keys against the feed" do
    id = "key-" <> String.duplicate("a", 32)
    assert P.against_feed(id, MapSet.new([id])) == :in_feed
    assert P.against_feed(id, MapSet.new()) == :not_in_feed
    assert P.against_feed("d29p12", MapSet.new()) == :legacy
  end
end
