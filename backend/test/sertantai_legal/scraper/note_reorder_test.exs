defmodule SertantaiLegal.Scraper.NoteReorderTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.NoteReorder

  defp note(id, code, text), do: %{id: id, code_type: "amendment", code: code, text: text}
  defp pair(code, old, new), do: {"amendment", code, old, new}

  describe "plan/2" do
    test "a stored note whose text is the old extraction gets the ordered text" do
      assert NoteReorder.plan(
               [note("L:amendment:1", "F1", "repealed by , s. 3 Act 1999")],
               [pair("F1", "repealed by , s. 3 Act 1999", "repealed by Act 1999, s. 3")]
             ) == %{updates: [{"L:amendment:1", "repealed by Act 1999, s. 3"}], unmatched: 0}
    end

    test "already-ordered text (no inline markup) is left alone, not counted unmatched" do
      assert NoteReorder.plan([note("L:amendment:1", "F1", "S. 2 repealed.")], [
               pair("F1", "S. 2 repealed.", "S. 2 repealed.")
             ]) == %{updates: [], unmatched: 0}
    end

    test "a note already in ordered text (a re-run) is left alone, not unmatched" do
      assert NoteReorder.plan([note("L:amendment:1", "F1", "repealed by Act 1999, s. 3")], [
               pair("F1", "repealed by , s. 3 Act 1999", "repealed by Act 1999, s. 3")
             ]) == %{updates: [], unmatched: 0}
    end

    test "a note whose text no longer matches the source (drift) is unmatched" do
      assert NoteReorder.plan([note("L:amendment:1", "F1", "old wording")], [
               pair("F1", "new wording", "new wording")
             ]) == %{updates: [], unmatched: 1}
    end

    test "the same code and old text in two fragments with different ordered text is ambiguous" do
      stored = [note("L:amendment:1", "F1", "x by , y")]
      pairs = [pair("F1", "x by , y", "x by y,"), pair("F1", "x by , y", "x by , y")]
      assert NoteReorder.plan(stored, pairs) == %{updates: [], unmatched: 1}
    end

    test "duplicate pairs that agree are fine" do
      stored = [note("L:amendment:1", "F1", "x by , y")]
      pairs = [pair("F1", "x by , y", "x by y,"), pair("F1", "x by , y", "x by y,")]

      assert NoteReorder.plan(stored, pairs) == %{
               updates: [{"L:amendment:1", "x by y,"}],
               unmatched: 0
             }
    end
  end

  describe "rekey/2" do
    test "maps old change ids to new, leaving unknown ids" do
      assert NoteReorder.rekey(["a", "b", "z"], %{"a" => "A", "b" => "B"}) == ["A", "B", "z"]
    end
  end
end
