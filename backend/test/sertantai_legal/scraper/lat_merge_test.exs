defmodule SertantaiLegal.Scraper.LatMergeTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatMerge

  defp old(id, text, pos, enriched \\ true),
    do: %{section_id: id, text: text, position: pos, enriched: enriched}

  defp new(id, text, pos), do: %{section_id: id, text: text, position: pos}

  test "same section_id and same normalised text carries" do
    plan =
      LatMerge.plan([old("L:reg.1", "A  person must.", 1)], [new("L:reg.1", "A person must.", 1)])

    assert plan.carry == %{"L:reg.1" => "L:reg.1"}
    assert plan.renames == []
    assert plan.lost_unchanged == []
  end

  test "same section_id with changed text is not carried and is reported as changed" do
    plan = LatMerge.plan([old("L:reg.1", "Old text.", 1)], [new("L:reg.1", "New text.", 1)])

    assert plan.carry == %{}
    assert plan.changed == ["L:reg.1"]
    assert plan.lost_unchanged == []
  end

  test "a vanished id whose text uniquely reappears under a new id is a rename" do
    plan =
      LatMerge.plan(
        [old("L:reg.39(e)", "in relation to the disposal of fish;", 5)],
        [new("L:reg.39(2)(e)", "in relation to the disposal of fish;", 5)]
      )

    assert plan.carry == %{"L:reg.39(2)(e)" => "L:reg.39(e)"}
    assert plan.renames == [%{old: "L:reg.39(e)", new: "L:reg.39(2)(e)", match: "unique_text"}]
  end

  test "equal-sized groups of duplicate text are paired in document order" do
    plan =
      LatMerge.plan(
        [old("L:reg.4(4)", "revoked", 1), old("L:reg.4(5)", "revoked", 2)],
        [new("L:reg.4(1)", "revoked", 1), new("L:reg.4(2)", "revoked", 2)]
      )

    assert plan.carry == %{"L:reg.4(1)" => "L:reg.4(4)", "L:reg.4(2)" => "L:reg.4(5)"}
    assert Enum.all?(plan.renames, &(&1.match == "ordered_text"))
  end

  test "unequal duplicate groups are ambiguous; enriched ones with surviving text fail the gate" do
    plan =
      LatMerge.plan(
        [old("L:x.1", "revoked", 1), old("L:x.2", "revoked", 2), old("L:x.3", "revoked", 3)],
        [new("L:y.1", "revoked", 1), new("L:y.2", "revoked", 2)]
      )

    assert plan.carry == %{}
    assert Enum.sort(plan.ambiguous) == ["L:x.1", "L:x.2", "L:x.3"]
    assert Enum.sort(plan.lost_unchanged) == ["L:x.1", "L:x.2", "L:x.3"]
  end

  test "a new id is never claimed twice (same-id match wins over a rename)" do
    plan =
      LatMerge.plan(
        [old("L:reg.1", "Same text.", 1), old("L:reg.9", "Same text.", 9)],
        [new("L:reg.1", "Same text.", 1)]
      )

    assert plan.carry == %{"L:reg.1" => "L:reg.1"}
    assert plan.removed == ["L:reg.9"]
    assert plan.lost_unchanged == ["L:reg.9"]
  end

  test "an enriched row whose text is gone is removed, not lost-unchanged" do
    plan = LatMerge.plan([old("L:reg.7", "Repealed words.", 7)], [new("L:reg.8", "Other.", 8)])

    assert plan.removed == ["L:reg.7"]
    assert plan.lost_unchanged == []
  end

  test "unenriched rows never fail the gate; empty-text rows only match by id" do
    plan =
      LatMerge.plan(
        [old("L:pt.1", nil, 1, false), old("L:x", "Text.", 2, false)],
        [new("L:part.1", nil, 1), new("L:y", "Other.", 2)]
      )

    assert plan.carry == %{}
    assert plan.lost_unchanged == []
    assert Enum.sort(plan.removed) == ["L:pt.1", "L:x"]
  end

  describe "parser-generation formatting differences" do
    test "a leading enumerator the old parser kept in the text still matches: (11), 27, [F345 59ZA" do
      plan =
        LatMerge.plan(
          [
            old("L:s.34CA(11)", "(11) The authority may provide grants.", 1),
            old("L:s.115", "115 Powers of entry.", 2),
            old("L:s.59ZA(1)", "[F345 (1) The owner must comply.", 3)
          ],
          [
            new("L:s.34CA(11)", "The authority may provide grants.", 1),
            new("L:s.115", "Powers of entry.", 2),
            new("L:s.59ZA(1)", "The owner must comply.", 3)
          ]
        )

      assert map_size(plan.carry) == 3
      assert plan.changed == []
    end

    test "same id whose text moved out (new text empty) keeps its enrichment" do
      plan =
        LatMerge.plan(
          [old("L:s.27", "27 Power of chief inspector to remedy harm.", 1)],
          [new("L:s.27", "", 1)]
        )

      assert plan.carry == %{"L:s.27" => "L:s.27"}
      assert plan.changed == []
    end

    test "same id where the old text aggregated children or a heading (contains the new) carries" do
      plan =
        LatMerge.plan(
          [
            old(
              "L:s.137E(9)",
              "(9) An order may make different provision, including— (a) times, (b) methods",
              1
            ),
            old(
              "L:s.256",
              "256 Power to require name and address Where an officer believes an offence was committed.",
              2
            ),
            old("L:s.293(2)", "(2) In subsection (1) — (a) after “x” insert “y”;", 3)
          ],
          [
            new("L:s.137E(9)", "An order may make different provision, including—", 1),
            new("L:s.256", "Where an officer believes an offence was committed.", 2),
            new("L:s.293(2)", "In subsection (1)—", 3)
          ]
        )

      assert map_size(plan.carry) == 3
      assert plan.changed == []
    end

    test "repealed dots are a real change, not containment" do
      plan =
        LatMerge.plan(
          [old("L:s.12(4)", "(4) The generating station must have a capacity such that…", 1)],
          [new("L:s.12(4)", ". . . . . . . .", 1)]
        )

      assert plan.changed == ["L:s.12(4)"]
    end

    test "short texts do not match by containment" do
      plan = LatMerge.plan([old("L:s.9", "(9) Omit “and”.", 1)], [new("L:s.9", "and", 1)])
      assert plan.changed == ["L:s.9"]
    end

    test "a genuinely different text under the same id is still changed" do
      plan =
        LatMerge.plan([old("L:s.5", "(1) Old duty.", 1)], [new("L:s.5", "A different duty.", 1)])

      assert plan.changed == ["L:s.5"]
    end
  end

  describe "extent-tag id changes" do
    test "an id that only gained or lost its [extent] tag is a rename, with the same-row text rules" do
      plan =
        LatMerge.plan(
          [
            old("L:s.71", "71 Obtaining of information.", 1),
            old(
              "L:s.78N(4)[S]",
              "(4) Subject to section 78E(4) and (5) above, the things are—",
              2
            )
          ],
          [
            new("L:s.71[E+W+S+NI]", "", 1),
            new("L:s.78N(4)", "Subject to section 78E(4) and (5) above, the things are—", 2)
          ]
        )

      assert plan.carry == %{
               "L:s.71[E+W+S+NI]" => "L:s.71",
               "L:s.78N(4)" => "L:s.78N(4)[S]"
             }

      assert Enum.all?(plan.renames, &(&1.match == "extent_tag"))
    end

    test "an extent-tag stem shared by several new rows is not guessed" do
      plan =
        LatMerge.plan(
          [old("L:s.5", "5 Heading.", 1)],
          [new("L:s.5[E+W]", "", 1), new("L:s.5[S]", "", 2)]
        )

      assert plan.carry == %{}
    end
  end
end
