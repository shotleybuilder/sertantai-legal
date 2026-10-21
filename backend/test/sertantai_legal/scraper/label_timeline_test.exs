defmodule SertantaiLegal.Scraper.LabelTimelineTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelTimeline

  test "undated_markup/1: markup explained by a dated law record pointing to the same note isn't undated" do
    changes = [
      %{section_id: "L:s.15A", source: "markup", pointer: "c950488", effective_from: nil},
      %{
        section_id: "L:s.15A",
        source: "law",
        pointer: "F:c950488",
        effective_from: ~D[2000-07-28]
      },
      # another note's markup on the row: still undated
      %{section_id: "L:s.16", source: "markup", pointer: "c1", effective_from: nil},
      %{section_id: "L:s.16", source: "law", pointer: "F:c2", effective_from: ~D[2000-07-28]},
      # the law record undated: the markup stays undated
      %{section_id: "L:s.17", source: "markup", pointer: "c3", effective_from: nil},
      %{section_id: "L:s.17", source: "law", pointer: "F:c3", effective_from: nil}
    ]

    assert LabelTimeline.undated_markup(changes) == MapSet.new(["L:s.16", "L:s.17"])
  end

  test "j2_markup/1: only a repealed or prospective reading of the revised text is J2's input (LR-25)" do
    assert LabelTimeline.j2_markup("repealed") == "repealed"
    assert LabelTimeline.j2_markup("prospective") == "prospective"
    assert LabelTimeline.j2_markup("repealed_saved") == nil
    assert LabelTimeline.j2_markup("in_force") == nil
    assert LabelTimeline.j2_markup(nil) == nil
  end

  test "require_markup!/2: a law parsed before markup_status existed can't be built (re-parse first)" do
    assert LabelTimeline.require_markup!("L", [["L:s.1", "in_force"], ["L:s.2", "repealed"]]) ==
             :ok

    assert_raise ArgumentError, ~r/L: 1 of 2 rows have no markup_status/, fn ->
      LabelTimeline.require_markup!("L", [["L:s.1", "in_force"], ["L:s.2", nil]])
    end
  end

  test "J5: a note on a whole provision inserted or substituted is a pointer" do
    assert LabelTimeline.whole_insertion_note?(
             "Art. 18(1A)(1B) inserted (15.4.2017) by S.I. 2017/402"
           )

    assert LabelTimeline.whole_insertion_note?("S. 58B inserted (1.4.1996) by 1995 c. 25")

    assert LabelTimeline.whole_insertion_note?(
             "Reg. 12(2) substituted (6.4.2009) by S.I. 2009/507"
           )
  end

  test "J5: a words note is never a pointer, the place's abbreviation aside (\"Words in art. 18(1) inserted\": SI 2015/595)" do
    refute LabelTimeline.whole_insertion_note?(
             "Words in art. 18(1) inserted (15.4.2017) by S.I. 2017/402"
           )

    refute LabelTimeline.whole_insertion_note?(
             "Words in art. 40 heading inserted (12.2.2024) by S.I. 2024/50"
           )

    refute LabelTimeline.whole_insertion_note?(
             "Words in s. 3(1)(a) substituted (1.4.1996) by 1995 c. 25"
           )

    refute LabelTimeline.whole_insertion_note?("Word in reg. 5 substituted by S.I. 2009/507")
    refute LabelTimeline.whole_insertion_note?("S. 5 repealed (1.4.1996) by 1995 c. 25")
  end
end
