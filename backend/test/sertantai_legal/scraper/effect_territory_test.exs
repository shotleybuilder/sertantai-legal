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

    test "a change with an unjoinable id joins by its key- commentary ref (an M_F_ ChangeId: 1993/11 s.20)" do
      e = effect(effect_id: "key-99")
      index = EffectIndex.new([e])
      assert EffectIndex.for(index, "M_F_1e9a", "key-99") == e
      assert EffectIndex.for(index, "key-99-123", nil) == e
      assert EffectIndex.for(index, "d29p1", "c123") == nil
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

    test "a range uses each id's first occurrence: a version repeating ids later doesn't stretch it (1990/43 \"Ss. 1-28\")" do
      e = effect(effect_id: "k", affected_ranges: [{"section-1", "section-28"}])
      order = ["section-1", "section-28", "section-29", "section-164", "section-28"]
      index = EffectIndex.new([e], order)

      assert EffectIndex.on(index, "section-28") == [e]
      assert EffectIndex.on(index, "section-29") == []
    end

    test "a range takes the smallest span: an end id repeated in a later version doesn't stretch it (1990/43 s.34(2A)-(2D), s.146(6)(b))" do
      e = effect(effect_id: "k", affected_ranges: [{"section-34-2A", "section-34-2D"}])

      order = [
        "section-34-2A",
        "section-146-6-b",
        "section-34-2A",
        "section-34-2B",
        "section-34-2D"
      ]

      index = EffectIndex.new([e], order)

      assert EffectIndex.on(index, "section-34-2B") == [e]
      assert EffectIndex.on(index, "section-146-6-b") == []
    end

    test "parallel/2: whole-instrument effects (no refs) match by their affected provisions (uksi 1996/972 revoked for E and for W)" do
      e = effect(effect_id: "k1", type: "revoked", affected_provisions: "Regulations")
      w = effect(effect_id: "k2", type: "revoked", affected_provisions: "Regulations")
      other = effect(effect_id: "k3", type: "revoked", affected_provisions: "reg. 2")
      index = EffectIndex.new([e, w, other])

      assert EffectIndex.parallel(index, e) |> Enum.map(& &1.effect_id) == ["k1", "k2"]
    end

    test "on_provision/3: the provision's one applied effect of the change's kind" do
      subst = effect(effect_id: "k1", type: "words substituted", affected_refs: ["s-1"])
      repeal = effect(effect_id: "k2", type: "words repealed", affected_refs: ["s-1"])
      index = EffectIndex.new([subst, repeal])

      assert EffectIndex.on_provision(index, "s-1", :ins) == subst
      assert EffectIndex.on_provision(index, "s-1", :keep) == repeal
      assert EffectIndex.on_provision(index, "s-2", :ins) == nil
      assert EffectIndex.on_provision(index, nil, :ins) == nil

      two =
        EffectIndex.new([
          subst,
          effect(effect_id: "k3", type: "words inserted", affected_refs: ["s-1"])
        ])

      assert EffectIndex.on_provision(two, "s-1", :ins) == nil
    end

    test "parallel/2: applied effects of the same type naming the same provision" do
      a =
        effect(
          effect_id: "k1",
          type: "substituted",
          affected_provisions: "reg. 11(3)",
          affected_refs: ["regulation-11-3"]
        )

      b =
        effect(
          effect_id: "k2",
          type: "substituted",
          affected_provisions: "reg. 11(3)",
          affected_refs: ["regulation-11-3"]
        )

      c =
        effect(
          effect_id: "k3",
          type: "words inserted",
          affected_provisions: "reg. 11(3)",
          affected_refs: ["regulation-11-3"]
        )

      index = EffectIndex.new([a, b, c])
      assert EffectIndex.parallel(index, a) |> Enum.map(& &1.effect_id) == ["k1", "k2"]
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

    test "a qualifier naming more than a territory is unusable (2000/37 \"for E. in relation to the pilot areas\"); \"in so far as not already in force\" is fine" do
      pilot =
        effect(
          in_force_qualifications: [
            "for E. in relation to the pilot areas",
            "for E. for specified purposes"
          ]
        )

      assert EffectTerritory.claim(pilot, :keep, nil) == {nil, nil}

      ok =
        effect(
          in_force_qualifications: [
            "(being the date on which S.I. 2007/739 came into force) for W. in so far as not already in force",
            "for E."
          ]
        )

      assert EffectTerritory.claim(ok, :keep, nil) == {"E+W", :effect_in_force}

      insertion = effect(in_force_qualifications: ["for W. for the insertion of s. 53B"])
      assert EffectTerritory.claim(insertion, :keep, nil) == {nil, nil}
    end

    test "an except-clause makes a qualifier unusable (1984/22 \"for E. except in relation to ss. 13-15\")" do
      e =
        effect(
          in_force_qualifications: [
            "for E. except in relation to ss. 13-15, 76",
            "for W. except in relation to ss. 13-15, 76"
          ]
        )

      assert EffectTerritory.claim(e, :keep, nil) == {nil, nil}
    end

    test "4. the effect's extent only when narrower than the affected extent (1974/40 s.101)" do
      s101 = effect(effect_extent: "S", affected_extent: "E+W+S+N.I.")
      assert EffectTerritory.claim(s101, :keep, nil) == {"S", :effect_extent}

      wide = effect(effect_extent: "E+W+S+N.I.", affected_extent: "E+W+S")
      assert EffectTerritory.claim(wide, :ins, nil) == {nil, nil}

      same = effect(effect_extent: "S+A+M+E+A+S+A+F+F+E+C+T+E+D", affected_extent: "S")
      assert EffectTerritory.claim(same, :ins, nil) == {nil, nil}
    end

    test "4. the extent is measured against the row's own extent when given (1986/62 s.21: an asp repeal on an E+S row; 2000/37 s.1(4)(a))" do
      asp = effect(effect_extent: "S", affected_extent: "S")
      assert EffectTerritory.claim(asp, :keep, nil, "E+S") == {"S", :effect_extent}

      ew = effect(effect_extent: "E+W", affected_extent: nil)
      assert EffectTerritory.claim(ew, :keep, nil, "E+W") == {nil, nil}
    end

    test "5. nothing names one: no claim" do
      assert EffectTerritory.claim(nil, :ins, nil) == {nil, nil}
      assert EffectTerritory.claim(effect([]), :ins, nil) == {nil, nil}
    end

    test "parallel effects (same type, same provision) union their applications (Jason 2026-10-09)" do
      e = effect(effect_id: "k1", type: "substituted", territorial_application: "E")
      w = effect(effect_id: "k2", type: "substituted", territorial_application: "W")
      assert EffectTerritory.claim([e, w], :ins, nil) == {"E+W", :effect_application}
    end

    test "markup disjoint from the application: the markup wins, reported as a conflict (uksi 2000/1043 reg.11(3))" do
      e = effect(territorial_application: "E")
      assert EffectTerritory.claim(e, :ins, "W") == {"W", :markup}
      assert EffectTerritory.conflict?(e, "W")
      refute EffectTerritory.conflict?(e, "E+W")
      refute EffectTerritory.conflict?(effect([]), "E+W")
    end
  end
end
