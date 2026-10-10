defmodule SertantaiLegal.Scraper.LatTerritoryCheckTest do
  @moduledoc "Pre-write sanity checks on parsed LAT territory (LR-03)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatTerritoryCheck

  defp row(id, fields \\ []),
    do:
      Map.merge(
        %{
          section_id: "UK_x:" <> id,
          extent_code: "E+W+S",
          excluded_extent: nil,
          territory_provenance: [],
          text: "Some words."
        },
        Map.new(fields)
      )

  test "a clean law has no findings" do
    assert LatTerritoryCheck.check([
             row("s.1", excluded_extent: "S"),
             row("s.1(1)", excluded_extent: "S")
           ]) == []
  end

  test "excluded_extent outside the row's extent" do
    assert [%{check: :excluded_outside_extent, section_id: "UK_x:s.2"}] =
             LatTerritoryCheck.check([row("s.2", extent_code: "E+W", excluded_extent: "S")])
  end

  test "a child live where its parent is excluded (versions keep their own parent)" do
    rows = [
      row("s.3", excluded_extent: "S"),
      row("s.3(1)"),
      row("s.3(1)(a)", excluded_extent: "S")
    ]

    assert [%{check: :child_live_where_parent_excluded, section_id: "UK_x:s.3(1)", detail: "S"}] =
             LatTerritoryCheck.check(rows)

    assert LatTerritoryCheck.check([row("s.4[S]", excluded_extent: "E+W"), row("s.4(1)[E+W]")]) ==
             []
  end

  test "markup and effect disagree (recorded on the provenance claim)" do
    claim = %{
      source: :effect_application,
      territory: "S",
      effect_id: "key-a",
      conflict_markup: "E+W"
    }

    assert [
             %{
               check: :markup_effect_conflict,
               detail: "markup E+W used: disjoint from the effects' application (key-a)"
             }
           ] =
             LatTerritoryCheck.check([row("s.5", territory_provenance: [claim])])
  end

  test "parent_id/1: the enclosing provision of a section id" do
    assert LatTerritoryCheck.parent_id("UK_x:s.3(1)(a)") == "UK_x:s.3(1)"
    assert LatTerritoryCheck.parent_id("UK_x:s.3(1)") == "UK_x:s.3"
    assert LatTerritoryCheck.parent_id("UK_x:s.3") == nil
    assert LatTerritoryCheck.parent_id("UK_x:reg.4(1)[E+W]") == "UK_x:reg.4[E+W]"
  end

  test "rows with no words, or a child extent outside the parent's exclusion, are not findings" do
    rows = [
      row("s.6", excluded_extent: "S", text: "Words."),
      row("s.6(1)", text: ". . . . . ."),
      row("s.6(2)", extent_code: "E+W", text: "Words.")
    ]

    assert LatTerritoryCheck.check(rows) == []
  end

  # LR-05 (LR-07 open bug): savings listed, the feed silent on territory, so
  # the effect reads as everywhere; the note names one territory. Reported,
  # never used (notes are hints).
  describe "check/2: note territory hint" do
    defp everywhere_row(id, fields \\ []),
      do:
        Map.merge(
          %{
            section_id: "UK_uksi_2010_404:" <> id,
            extent_code: "E+W",
            excluded_extent: "E+W",
            text: "Kept text.",
            territory_provenance: [%{source: :effect_everywhere, effect_id: "e1"}]
          },
          Map.new(fields)
        )

    test "excluded everywhere on effect evidence, the note naming a narrower territory: reported" do
      notes = [
        %{
          affected_sections: ["UK_uksi_2010_404:reg.14"],
          text: "Reg. 14 omitted (E.) (1.10.2020) by S.I. 2020/1"
        }
      ]

      assert [
               %{
                 check: :note_territory_hint,
                 section_id: "UK_uksi_2010_404:reg.14",
                 detail: detail
               }
             ] =
               LatTerritoryCheck.check([everywhere_row("reg.14")], notes)

      assert detail =~ "E"
    end

    test "a note covering the extent, no note territory, or other evidence: nothing" do
      covers = [
        %{
          affected_sections: ["UK_uksi_2010_404:reg.14"],
          text: "Reg. 14 omitted (E.W.) by S.I. 2020/1"
        }
      ]

      none = [
        %{affected_sections: ["UK_uksi_2010_404:reg.14"], text: "Reg. 14 omitted by S.I. 2020/1"}
      ]

      assert LatTerritoryCheck.check([everywhere_row("reg.14")], covers) == []
      assert LatTerritoryCheck.check([everywhere_row("reg.14")], none) == []

      markup = everywhere_row("reg.14", territory_provenance: [%{source: :markup}])

      notes = [
        %{
          affected_sections: ["UK_uksi_2010_404:reg.14"],
          text: "Reg. 14 omitted (E.) by S.I. 2020/1"
        }
      ]

      assert LatTerritoryCheck.check([markup], notes) == []
    end
  end
end
