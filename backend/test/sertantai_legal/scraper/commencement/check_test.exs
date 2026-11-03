defmodule SertantaiLegal.Scraper.Commencement.CheckTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Check

  describe "yardstick/1: the reader's full date against the feed's" do
    test "neither, own only, agree, feed only, feed partial only, differ" do
      assert Check.yardstick(%{feed: nil, full_from: nil}) == :neither
      assert Check.yardstick(%{feed: nil, full_from: ~D[1975-01-01]}) == :own_only
      assert Check.yardstick(%{feed: {nil, ~D[1975-01-01]}, full_from: ~D[1975-01-01]}) == :agree
      assert Check.yardstick(%{feed: {nil, ~D[1975-01-01]}, full_from: nil}) == :feed_only

      assert Check.yardstick(%{feed: {~D[1974-01-01], nil}, full_from: ~D[1975-01-01]}) ==
               :feed_partial_only

      assert Check.yardstick(%{feed: {nil, ~D[1976-01-01]}, full_from: ~D[1975-01-01]}) == :differ
    end
  end

  test "feed_index/1 keys each record by its provision without a version" do
    index =
      Check.feed_index([
        ["s.2[E+W]", ~D[1975-01-01], nil],
        ["s.3", ~D[1975-01-01], ~D[1976-01-01]]
      ])

    assert index["s.2"] == {~D[1975-01-01], nil}
    assert index["s.3"] == {~D[1975-01-01], ~D[1976-01-01]}
  end

  test "row_tallies/1 counts outcomes with their laws, the rows left to orders and the yardstick" do
    rows = [
      %{law: "A", outcome: :dated, yardstick: :own_only},
      %{law: "B", outcome: :dated, yardstick: :agree},
      %{law: "B", outcome: :by_order, yardstick: :neither},
      %{law: "B", outcome: :by_order_partly, yardstick: :neither}
    ]

    t = Check.row_tallies(rows)
    assert t.laws == 2
    assert {:dated, 2, 2, false} in t.outcomes
    assert hd(t.outcomes) |> elem(0) == :dated
    assert t.by_order == 2
    assert hd(t.yardstick) == {:neither, 2}
  end

  test "gap_class/1 names a dated gap by its pointer and an undated one by its reason" do
    assert Check.gap_class(%{why: {:dated, ~D[2000-01-01], :order}}) == "dated via order"
    assert Check.gap_class(%{why: {:undated, :no_rules}}) == "undated: no_rules"
  end

  test "gap_tallies/1 counts text changes and those off Schedules, and the undated gaps' amending laws" do
    gap = fn target, op, why, amender ->
      %{change: %{target: target, resolved: %{operation: op}}, why: why, amender: amender}
    end

    gaps = [
      gap.("s.1", :inserted, {:undated, :no_rules}, "X"),
      gap.("sch.1.para.2", :repealed, {:undated, :no_rules}, "X"),
      gap.("s.2", :commenced, {:undated, :no_rules}, nil),
      gap.("s.3", :substituted, {:dated, ~D[2000-01-01], :order}, "Y")
    ]

    t = Check.gap_tallies(gaps)
    assert t.text == 3
    assert {"undated: no_rules", 3, 2, 1} in t.classes
    assert {"dated via order", 1, 1, 1} in t.classes
    assert t.amenders == [{"undated: no_rules", [{"X", 2}, {nil, 1}]}]
  end

  test "short/1 cuts an effect id to its last six characters (push protection)" do
    assert Check.short("key-" <> String.duplicate("a", 26) <> "123456") == "key-…123456"
    assert Check.short("d29p5797") == "d29p5797"
  end
end
