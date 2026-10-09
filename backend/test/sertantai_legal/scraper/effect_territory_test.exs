defmodule SertantaiLegal.Scraper.EffectTerritoryTest do
  @moduledoc """
  Territory from the effects layer (LR-03; plan `docs/LAT-EFFECTS-LAYER-PLAN.md`).
  Effects are hand-built from real feed records (1974/40 s.101, s.30).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.{EffectIndex, EffectTerritory}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(fields) do
    struct!(
      Effect,
      Keyword.merge(
        [type: "repealed", affecting: "UK_x", applied: true, affected_refs: []],
        fields
      )
    )
  end

  describe "EffectIndex" do
    test "an effect id from a modern ChangeId; nil from a legacy one" do
      assert EffectIndex.effect_id("key-fixtureeffect-1460361019464") ==
               "key-fixtureeffect"

      assert EffectIndex.effect_id("d29p1769") == nil
      assert EffectIndex.effect_id(nil) == nil
    end

    test "effects by id and by ref" do
      e = effect(effect_id: "key-a", affected_refs: ["section-101"])
      index = EffectIndex.new([e])
      assert EffectIndex.get(index, "key-a") == e
      assert EffectIndex.for_change(index, "key-a-123") == e
      assert EffectIndex.for_change(index, "d29p1") == nil
      assert EffectIndex.on(index, "section-101") == [e]
      assert EffectIndex.on(index, "section-102") == []
    end

    test "a range covers every provision between its ends, in document order (1974/40 \"Ss. 1-30\")" do
      e = effect(effect_id: "k", affected_ranges: [{"section-1", "section-30"}])

      order = [
        "section-1",
        "section-1-1",
        "section-2",
        "section-30",
        "section-30-1",
        "section-31"
      ]

      index = EffectIndex.new([e], order)

      assert EffectIndex.on(index, "section-2") == [e]
      assert EffectIndex.on(index, "section-30") == [e]
      assert EffectIndex.on(index, "section-31") == []
    end

    test "whole-provision effects: applied repeals/insertions of the provision only" do
      repeal = effect(effect_id: "k1", type: "repealed", affected_refs: ["section-101"])
      words = effect(effect_id: "k2", type: "words repealed", affected_refs: ["section-101"])
      subst = effect(effect_id: "k3", type: "substituted", affected_refs: ["section-101"])
      unapplied = effect(effect_id: "k4", applied: false, affected_refs: ["section-101"])
      inserted = effect(effect_id: "k5", type: "inserted", affected_refs: ["section-101"])
      index = EffectIndex.new([repeal, words, subst, unapplied, inserted])

      assert EffectIndex.whole_provision(index, "section-101") |> Enum.map(& &1.effect_id) ==
               ["k1", "k5"]
    end
  end

  describe "EffectTerritory.claim/3 — the agreed order" do
    test "1. territorial application first" do
      e = effect(territorial_application: "W", effect_extent: "E+W")
      assert EffectTerritory.claim(e, :ins, "E+W") == {"W", :effect_application}
    end

    test "2. else the markup Extent" do
      assert EffectTerritory.claim(effect([]), :ins, "E.W.") == {"E+W", :markup}
      assert EffectTerritory.claim(nil, :keep, "S") == {"S", :markup}
    end

    test "3. a removal: where it is in force (1974/40 s.30 \"for S.\"); never for an insertion" do
      e =
        effect(
          effect_extent: "S+A+M+E+A+S+A+F+F+E+C+T+E+D",
          affected_extent: "E+W+S",
          in_force_qualifications: ["for S."]
        )

      assert EffectTerritory.claim(e, :keep, nil) == {"S", :effect_in_force}
      assert EffectTerritory.claim(e, :pair, nil) == {"S", :effect_in_force}
      assert EffectTerritory.claim(e, :ins, nil) == {nil, nil}
    end

    test "in force: every territory qualifier; purpose-limited ones don't count" do
      e = effect(in_force_qualifications: ["for E.", "for W."], affected_extent: "E+W+S")
      assert EffectTerritory.claim(e, :keep, nil) == {"E+W", :effect_in_force}

      purposes = effect(in_force_qualifications: ["for S. for specified purposes"])
      assert EffectTerritory.claim(purposes, :keep, nil) == {nil, nil}
    end

    test "4. the effect's extent only when narrower than the affected extent (1974/40 s.101)" do
      s101 = effect(effect_extent: "S", affected_extent: "E+W+S+N.I.")
      assert EffectTerritory.claim(s101, :keep, nil) == {"S", :effect_extent}

      wide = effect(effect_extent: "E+W+S+N.I.", affected_extent: "E+W+S")
      assert EffectTerritory.claim(wide, :ins, nil) == {nil, nil}

      same = effect(effect_extent: "S+A+M+E+A+S+A+F+F+E+C+T+E+D", affected_extent: "S")
      assert EffectTerritory.claim(same, :ins, nil) == {nil, nil}
    end

    test "5. nothing names one: no claim" do
      assert EffectTerritory.claim(nil, :ins, nil) == {nil, nil}
      assert EffectTerritory.claim(effect([]), :ins, nil) == {nil, nil}
    end

    test "markup and application disjoint: a conflict (application used)" do
      e = effect(territorial_application: "S")
      assert EffectTerritory.conflict?(e, "E+W")
      refute EffectTerritory.conflict?(e, "E+W+S")
      refute EffectTerritory.conflict?(effect([]), "E+W")
    end
  end
end
