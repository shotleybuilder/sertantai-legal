defmodule SertantaiLegal.Scraper.LatChangeLogTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.{AmendmentNote, LatChangeLog}

  @law "UK_ukpga_2018_12"

  defp id(x), do: "#{@law}:#{x}"

  defp note(target, text),
    do: %{target: id(target), text: text, parsed: AmendmentNote.parse(text, "amendment", @law)}

  defp plan(overrides \\ []) do
    Map.merge(%{changed: [], inserted: [], removed: [], renames: []}, Map.new(overrides))
  end

  describe "renumber_pair/2" do
    test "whole-provision renumbering notes give an {old, new} pair" do
      assert LatChangeLog.renumber_pair(
               "S. 23 renumbered as s. 24 (1.4.2010) by S.I. 2010/1",
               @law
             ) ==
               {id("s.23"), id("s.24")}

      assert LatChangeLog.renumber_pair(
               "Art. 10 renumbered as art. 10(1) (1.4.2013) by , (with ) The Natural Resources Body for Wales (Functions) Order 2013 (S.I. 2013/755)",
               "UK_uksi_2013_755"
             ) ==
               {"UK_uksi_2013_755:reg.10", "UK_uksi_2013_755:reg.10(1)"}
    end

    test "words moved within a provision, or any other note → nil" do
      assert LatChangeLog.renumber_pair(
               "Words in s. 39(3)(a) renumbered as s. 39(3)(a)(i) (3.7.2000) by 1999 c. 29",
               @law
             ) == nil

      assert LatChangeLog.renumber_pair("S. 4 substituted (1.1.2020) by S.I. 2020/1", @law) == nil
    end
  end

  describe "entries/2" do
    test "an initial parse logs nothing (version 1, not a change)" do
      assert LatChangeLog.entries(plan(inserted: [id("s.1")]), %{
               cause: "initial",
               new_notes: [],
               status_changes: []
             }) == []
    end

    test "parser / scope / correction: every changed row takes the operation's cause" do
      entries =
        LatChangeLog.entries(
          plan(
            changed: [id("s.1")],
            inserted: [id("s.2")],
            removed: [id("s.3")],
            renames: [%{old: id("s.4"), new: id("s.4A"), match: "unique_text"}]
          ),
          %{cause: "parser", new_notes: [], status_changes: []}
        )

      assert Enum.map(entries, &{&1.change, &1.section_id, &1.old_section_id, &1.cause}) == [
               {"text_changed", id("s.1"), nil, "parser"},
               {"inserted", id("s.2"), nil, "parser"},
               {"removed", nil, id("s.3"), "parser"},
               {"renamed", id("s.4A"), id("s.4"), "parser"}
             ]
    end

    test "source changed: legislative only with the row's own evidence, else unattributed" do
      n = note("s.1", "S. 1 substituted (1.4.2024) by S.I. 2024/9")

      entries =
        LatChangeLog.entries(
          plan(changed: [id("s.1(2)"), id("s.5")]),
          %{cause: "legislative", new_notes: [n], status_changes: []}
        )

      assert [
               %{
                 section_id: s12,
                 change: "text_changed",
                 cause: "legislative",
                 change_ids: [cid]
               },
               %{section_id: s5, change: "text_changed", cause: "unattributed", change_ids: []}
             ] = entries

      assert {s12, s5} == {id("s.1(2)"), id("s.5")}
      assert cid == n.parsed.change_id
    end

    test "a status-only change is logged and is legislative evidence in itself" do
      assert [%{change: "status_changed", section_id: sid, cause: "legislative"}] =
               LatChangeLog.entries(plan(), %{
                 cause: "unattributed",
                 new_notes: [],
                 status_changes: [{id("s.9"), "in_force", "repealed"}]
               })

      assert sid == id("s.9")
    end

    test "a renumbering note pairs a removed and an inserted row into one legislative rename" do
      n = note("s.24", "S. 23 renumbered as s. 24 (1.4.2010) by S.I. 2010/1")

      assert [
               %{
                 change: "renamed",
                 old_section_id: old,
                 section_id: new,
                 cause: "legislative",
                 change_ids: [_]
               }
             ] =
               LatChangeLog.entries(
                 plan(removed: [id("s.23")], inserted: [id("s.24")]),
                 %{cause: "legislative", new_notes: [n], status_changes: []}
               )

      assert {old, new} == {id("s.23"), id("s.24")}
    end
  end

  describe "plan/3" do
    # Repealed placeholders (". . .") share their text, so LatMerge calls a
    # vanished one ambiguous; an id gone from the parse is still removed
    # (#166: narrowing the Companies Act left 224 unlogged).
    test "ambiguous ids missing from the new parse are removed; ones still present are not" do
      merge = %{
        changed: [id("s.2")],
        removed: [id("s.3")],
        ambiguous: [id("s.4"), id("s.5")],
        renames: [%{old: id("s.6"), new: id("s.7"), match: :unique_text}]
      }

      existing = [id("s.1"), id("s.2"), id("s.3"), id("s.4"), id("s.5"), id("s.6")]
      new_ids = [id("s.1"), id("s.2"), id("s.5"), id("s.7"), id("s.8")]

      plan = LatChangeLog.plan(merge, existing, new_ids)

      assert plan.changed == [id("s.2")]
      assert plan.removed == [id("s.3"), id("s.4")]
      assert plan.inserted == [id("s.8")]
      assert plan.renames == merge.renames
    end
  end
end
