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

    assert [%{check: :markup_effect_conflict, detail: "markup E+W, effect S (key-a)"}] =
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
end
