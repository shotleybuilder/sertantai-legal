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

  test "V1-03: law_key/1 — a Welsh SI and its uksi URI are one law for T1 (SI 2005/1806)" do
    assert LabelTimeline.law_key("UK_wsi_2011_971") == LabelTimeline.law_key("UK_uksi_2011_971")
    assert LabelTimeline.law_key("UK_ukpga_1990_43") == "UK_ukpga_1990_43"
  end

  test "V1-03: undated_markup/1 — a dated feed effect joined to the same note explains the markup (2004 c.20 s.10(2)(b), SI 2010/675)" do
    changes = [
      %{
        section_id: "L:s.10(2)(b)",
        source: "markup",
        pointer: "M_F_4106b082",
        effective_from: nil
      },
      %{
        section_id: "L:s.10(2)(b)",
        source: "effect",
        pointer: "F:M_F_4106b082",
        effective_from: ~D[2010-04-06]
      }
    ]

    assert LabelTimeline.undated_markup(changes) == MapSet.new()
  end

  test "V1-03: undated_change/2 — a dated change joined to the note explains it, whichever law it names (SI 2019/465 as substituted by SI 2020/1359)" do
    changes = [
      %{
        section_id: "L:reg.3(1)",
        source: "effect",
        operation: "repealed",
        affecting_law: "UK_uksi_2020_1359",
        pointer: "F:key-ca00",
        effective_from: ~D[2020-12-31]
      }
    ]

    undated? =
      LabelTimeline.undated_change(changes, %{
        "L:reg.3(1)" => [{"F:key-ca00", "UK_uksi_2019_465"}]
      })

    refute undated?.("L:reg.3(1)")

    # a note no dated change joins, naming a law with none: undated
    undated? =
      LabelTimeline.undated_change(changes, %{"L:reg.3(1)" => [{"F:other", "UK_uksi_2019_465"}]})

    assert undated?.("L:reg.3(1)")

    # a Welsh SI's uksi URI is the wsi law's change
    wsi = [
      %{
        section_id: "L:reg.2",
        source: "effect",
        operation: "substituted",
        affecting_law: "UK_wsi_2011_971",
        pointer: nil,
        effective_from: ~D[2011-03-29]
      }
    ]

    refute LabelTimeline.undated_change(wsi, %{"L:reg.2(1)" => [{"F:x", "UK_uksi_2011_971"}]}).(
             "L:reg.2(1)"
           )
  end
end
