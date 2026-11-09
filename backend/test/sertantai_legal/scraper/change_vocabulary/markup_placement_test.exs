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

  # Environmental Protection: Markup reader, Decision 1 (Jason 2026-11-09):
  # a scoped law is read for its scope, from our rows to the law. The
  # Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024
  # holds only s.64 (`section/64`); its other sections' commencements are
  # outside our LAT scope, not row faults.
  @scoped %{
    rows: MapSet.new(["pt.3", "s.64", "s.64(1)"]),
    schedules?: false,
    scope: ["section-64"]
  }

  test "a scoped law: a change beyond its fragments is outside_lat_scope" do
    assert P.classify(["s.23"], [["part-2", "section-23"]], @scoped) ==
             {:unplaced, :outside_lat_scope}

    assert P.classify([], [["part-2", "section-23", "section-23-1"]], @scoped) ==
             {:unplaced, :outside_lat_scope}
  end

  test "a scoped law: within its fragments, a missing row is still our fault" do
    no_row = %{@scoped | rows: MapSet.new(["pt.3"])}

    assert P.classify(["s.64(9)"], [["part-3", "section-64", "section-64-9"]], no_row) ==
             {:unplaced, :row_missing}

    assert P.classify(["s.64(1)"], [["part-3", "section-64", "section-64-1"]], @scoped) ==
             :placed
  end

  test "a scoped law: a change on a held row outside the fragments is placed" do
    assert P.classify(["pt.3"], [["part-3"]], @scoped) == :placed
  end

  test "a fragment holds what is under it, never a sibling that shares its digits" do
    part = %{@scoped | scope: ["part-15-chapter-5"]}

    assert P.classify(["s.640"], [["part-15", "section-640"]], %{@scoped | scope: ["section-64"]}) ==
             {:unplaced, :outside_lat_scope}

    assert P.classify(["s.90"], [["part-15", "part-15-chapter-5", "section-90"]], part) ==
             {:unplaced, :row_missing}
  end

  test "our faults" do
    assert P.fault?(:row_missing)
    assert P.fault?(:id_not_converted)
    assert P.fault?(:group_row_missing)
    refute P.fault?(:schedule_not_parsed)
    refute P.fault?(:outside_provisions)
    refute P.fault?(:outside_lat_scope)
  end

  test "keys against the feed" do
    id = "key-" <> String.duplicate("a", 32)
    assert P.against_feed(id, MapSet.new([id])) == :in_feed
    assert P.against_feed(id, MapSet.new()) == :not_in_feed
    assert P.against_feed("d29p12", MapSet.new()) == :legacy
  end
end
