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
end
