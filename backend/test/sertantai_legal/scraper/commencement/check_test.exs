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

    test "a partial start on the feed's own first day, neither in force fully, agrees" do
      # SI 2010/2169 Sch.: "Section 7, in relation to England only" on
      # 1 October 2010, the feed's record partial from that day too
      partial = %{feed: {~D[2010-10-01], nil}, partial_from: ~D[2010-10-01], full_from: nil}
      assert Check.yardstick(partial) == :agree
      assert Check.yardstick(%{partial | partial_from: nil}) == :feed_only
      assert Check.yardstick(%{partial | partial_from: ~D[2010-09-01]}) == :feed_only
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

  test "the feed's stages for each place are fully in force once they cover the row's extent (Water Act 2003 s.77: England, then Wales)" do
    feed =
      Check.feed_index([
        ["s.77", ~D[2004-10-01], nil, [[~D[2004-10-01], "E"], [~D[2004-11-11], "W"]]],
        ["s.78", ~D[2004-10-01], nil, [[~D[2004-10-01], "E"]]]
      ])

    rows =
      for id <- ["s.77", "s.78", "s.79"],
          do: %{section_id: "UK_x:" <> id, text: "", part: nil, chapter: nil, extent_code: "E+W"}

    by_id = "UK_x" |> Check.rows(rows, [], feed, false) |> Map.new(&{&1.id, &1.feed})

    assert by_id["s.77"] == {~D[2004-10-01], ~D[2004-11-11]}
    assert by_id["s.78"] == {~D[2004-10-01], nil}
    assert by_id["s.79"] == nil
  end

  test "a section the feed has wholly in force brings its subsections fully in, whatever their own records say (Water Act 2014 s.6: SI 2016/465)" do
    feed =
      Check.feed_index([
        ["s.6", ~D[2016-04-01], ~D[2016-04-01]],
        ["s.6(1)", ~D[2015-12-18], nil],
        ["s.7(1)", ~D[2015-11-20], ~D[2016-04-01]],
        ["s.7", ~D[2017-01-01], ~D[2017-01-01]]
      ])

    rows =
      for id <- ["s.6(1)", "s.6(2)", "s.7(1)"],
          do: %{section_id: "UK_x:" <> id, text: "", part: nil, chapter: nil, extent_code: "E+W"}

    by_id = "UK_x" |> Check.rows(rows, [], feed, false) |> Map.new(&{&1.id, &1.feed})

    assert by_id["s.6(1)"] == {~D[2015-12-18], ~D[2016-04-01]}
    assert by_id["s.6(2)"] == {~D[2016-04-01], ~D[2016-04-01]}
    # its own earlier full stands
    assert by_id["s.7(1)"] == {~D[2015-11-20], ~D[2016-04-01]}
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
