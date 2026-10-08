defmodule SertantaiLegal.Scraper.NotePlacementTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.NotePlacement

  defp stored(id, code, text, sections),
    do: %{id: id, code_type: "amendment", code: code, text: text, affected_sections: sections}

  defp parsed(code, text, sections),
    do: %{code_type: "amendment", code: code, text: text, affected_sections: sections}

  describe "plan/2" do
    test "places an unplaced note" do
      assert NotePlacement.plan([stored("n1", "F:c1", "Word substituted", nil)], [
               parsed("F:c1", "Word substituted", ["L:reg.2(1)"])
             ]) == %{updates: [{"n1", ["L:reg.2(1)"]}], unmatched: 0}
    end

    test "a parsed code_type atom (CommentaryParser) matches the stored string" do
      assert NotePlacement.plan([stored("n1", "F1", "x", nil)], [
               %{parsed("F1", "x", ["L:reg.2"]) | code_type: :amendment}
             ]) == %{updates: [{"n1", ["L:reg.2"]}], unmatched: 0}
    end

    test "leaves a note whose sections are unchanged" do
      assert NotePlacement.plan([stored("n1", "F1", "x", ["L:reg.2"])], [
               parsed("F1", "x", ["L:reg.2"])
             ]) == %{updates: [], unmatched: 0}
    end

    test "never unplaces a note (no sections in the parse keeps the stored ones)" do
      assert NotePlacement.plan([stored("n1", "F1", "x", ["L:reg.2"])], [parsed("F1", "x", nil)]) ==
               %{updates: [], unmatched: 0}
    end

    test "a note whose text drifted from the source is unmatched" do
      assert NotePlacement.plan([stored("n1", "F1", "old", nil)], [
               parsed("F1", "new", ["L:reg.2"])
             ]) ==
               %{updates: [], unmatched: 1}
    end

    test "duplicates of one note (scoped fragments) merge their sections" do
      assert NotePlacement.plan([stored("n1", "F1", "x", nil)], [
               parsed("F1", "x", ["L:reg.2"]),
               parsed("F1", "x", ["L:reg.3"])
             ]) == %{updates: [{"n1", ["L:reg.2", "L:reg.3"]}], unmatched: 0}
    end
  end
end
