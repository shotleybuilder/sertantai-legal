defmodule SertantaiLegal.Scraper.StepProcedures.ExtentDiffTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.StepProcedures.ExtentDiff

  defp row(kind, ref, items, place \\ nil),
    do: %{kind: kind, place: place, items: items, source_ref: ref, amends: nil}

  test "the same rows, in any order: no change" do
    rows = [row("default", "s.9", ["E", "W"]), row("only", "s.9(2)", ["S"])]
    d = ExtentDiff.diff(rows, Enum.reverse(rows))
    assert ExtentDiff.same?(d)
    assert d.changes == []
  end

  test "a row on the same provision paired and named by the fields that differ" do
    d =
      ExtentDiff.diff([row("only", "s.9(2)", ["S"])], [
        row("only", "s.9(2)", ["S", "NI"], "sch.1")
      ])

    refute ExtentDiff.same?(d)
    assert [%{fields: [:items, :place]}] = d.changes
    assert ExtentDiff.by_field(d.changes) == %{"items+place" => 1}
  end

  test "rows with no partner are added or gone; a repeated row counts each time" do
    stored = [row("default", "s.9", ["E"]), row("default", "s.9", ["E"])]
    fresh = [row("default", "s.9", ["E"]), row("same", "s.10", [])]
    d = ExtentDiff.diff(stored, fresh)
    assert d.gone == [row("default", "s.9", ["E"])]
    assert d.added == [row("same", "s.10", [])]
    assert ExtentDiff.by_field(d.changes) == %{"added" => 1, "gone" => 1}
  end
end
