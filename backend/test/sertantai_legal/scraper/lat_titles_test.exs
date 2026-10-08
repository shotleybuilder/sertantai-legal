defmodule SertantaiLegal.Scraper.LatTitlesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatTitles

  defp r(id, title), do: %{section_id: id, title: title}

  describe "plan/2" do
    test "sets a title the stored row lacks" do
      assert LatTitles.plan([r("L:reg.2", nil)], [r("L:reg.2", "Interpretation")]) ==
               [{"L:reg.2", "Interpretation"}]
    end

    test "leaves matching titles alone" do
      assert LatTitles.plan([r("L:reg.2", "Interpretation")], [r("L:reg.2", "Interpretation")]) ==
               []
    end

    test "corrects a changed title and clears one the parse no longer gives" do
      stored = [r("L:reg.2", "Old"), r("L:reg.3", "Gone")]
      parsed = [r("L:reg.2", "New"), r("L:reg.3", nil)]
      assert LatTitles.plan(stored, parsed) == [{"L:reg.2", "New"}, {"L:reg.3", nil}]
    end

    test "never touches rows only one side has (no re-parse: ids must match)" do
      assert LatTitles.plan([r("L:reg.1", nil)], [r("L:reg.9", "New provision")]) == []
    end

    test "plans any column (repealed_extent)" do
      stored = [%{section_id: "L:reg.3", repealed_extent: nil}]
      parsed = [%{section_id: "L:reg.3", repealed_extent: "S"}]
      assert LatTitles.plan(stored, parsed, :repealed_extent) == [{"L:reg.3", "S"}]
    end
  end
end
