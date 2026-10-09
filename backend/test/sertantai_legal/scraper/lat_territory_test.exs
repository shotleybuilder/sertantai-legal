defmodule SertantaiLegal.Scraper.LatTerritoryTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatTerritory
  alias SertantaiLegal.Scraper.LatTerritory.Change

  # Territory comes from the change markup's Extent attribute only; notes are
  # never a source (LR-02; effects arrive in LR-03).
  defp keep(attr, inner), do: {:words, %Change{kind: :keep, attribute: attr}, inner}
  defp ins(attr, inner), do: {:words, %Change{kind: :ins, attribute: attr}, inner}

  defp t(s), do: {:text, s}

  defp render(segs, extent \\ "E+W+S", excluded \\ nil),
    do: LatTerritory.render(segs, extent, excluded)

  describe "territory/1" do
    test "the Extent attribute, normalised; nil when the markup names none" do
      assert LatTerritory.territory(%Change{kind: :keep, attribute: "S"}) == "S"
      assert LatTerritory.territory(%Change{kind: :ins, attribute: "E.W."}) == "E+W"
      assert LatTerritory.territory(%Change{kind: :keep, ref: "a-note"}) == nil
    end
  end

  describe "render/4: words" do
    test "retained words: bracketed with where they still apply; plain when the markup names no territory" do
      assert render([t("A duty "), keep("S", [t("to report")]), t(" applies.")]) ==
               "A duty [E+W: to report] applies."

      assert render([t("A "), keep(nil, [t("duty")])]) == "A duty"
    end

    test "inserted words: bracketed when narrower; plain when covering, outside or no territory" do
      segs = [t("The "), ins("W", [t("regulator ")]), t("may act.")]
      assert render(segs, "E+W") == "The [W: regulator] may act."
      assert render(segs, "W") == "The regulator may act."
      assert render(segs, "S") == "The regulator may act."

      assert render([t("The "), ins(nil, [t("regulator ")]), t("acts.")]) ==
               "The regulator acts."
    end

    test "a whole-row change (excluded set) reads plain" do
      assert render([keep("S", [t("All of it.")])], "E+W+S", "S") == "All of it."
    end

    test "a whole-row change reads plain, its inner changes still within its territory (1986/14 s.29(5A))" do
      inner_pair =
        {:pair, %Change{kind: :pair, attribute: "NI"}, [t("the 2011 Act")], [t("the 1972 Act")]}

      assert render([ins("E+W", [t("a reference to "), inner_pair])], "E+W+S+NI", "S+NI") ==
               "a reference to the 1972 Act"
    end

    test "nested: a narrower insertion keeps its bracket; one within the live territory needs none" do
      assert render([
               t("The "),
               ins("E+W", [t("regulator "), ins("E", [t("or the Agency ")]), t("or the ")]),
               t("council")
             ]) ==
               "The [E+W: regulator [E: or the Agency] or the] council"

      assert render([
               t("A "),
               keep("S", [t("duty "), ins("E+W", [t("to report ")]), t("promptly")]),
               t(" applies.")
             ]) ==
               "A [E+W: duty to report promptly] applies."
    end

    test "a non-breaking space is text, not whitespace to collapse (EU 2016/425 \"point\u00A0(a)\")" do
      assert render([t("point\u00A0(a)  and")]) == "point\u00A0(a) and"
    end

    test "a bracket names only territories within the row (1968/73 s.10(1)[E+W+NI])" do
      assert render([t("or"), ins("E+W+S", [t(" passenger transport")])], "E+W+NI") ==
               "or [E+W: passenger transport]"
    end

    test "adjacent brackets for the same territories merge; whitespace collapses" do
      assert render([
               t("police "),
               keep("S", [t("or ")]),
               keep("S", [t("fire")]),
               t("  purposes")
             ]) ==
               "police [E+W: or fire] purposes"
    end
  end

  describe "render/4: pairs" do
    defp pair(attr),
      do: {:pair, %Change{kind: :pair, attribute: attr}, [t("the service")], [t("the brigade")]}

    test "both versions, new first; extremes; no territory keeps both apart in document order" do
      assert render([t("by "), pair("S"), t(" now")]) ==
               "by [S: the service] [E+W: the brigade] now"

      assert render([t("by "), pair("E+W+S")]) == "by the service"
      assert render([t("by "), pair("NI")]) == "by the brigade"
      assert render([t("by "), pair(nil)]) == "by the brigade the service"
    end

    test "a pair inside retained words renders within their live territory (1968/73 s.102(4))" do
      segs = [
        t("police "),
        keep("S", [t("or ")]),
        keep("S", [
          {:pair, %Change{kind: :keep, attribute: "E+W"}, [t("fire and rescue authority")],
           [t("fire brigade")]}
        ]),
        t(" purposes")
      ]

      assert render(segs) == "police [E+W: or fire and rescue authority] purposes"
    end
  end

  describe "pair_up/1: halves that are not siblings" do
    test "the old half takes the first later new half with its id; the new half leaves its place" do
      old = %Change{kind: :keep, attribute: "W"}
      new = %Change{kind: :ins, attribute: "W"}

      segs = [
        t("within 22 "),
        {:words, %Change{kind: :ins}, [{:pair_old, "X", old, [t("or 24")]}]},
        t(" "),
        {:words, %Change{kind: :ins}, [{:pair_new, "X", new, [t(", 24 or 24ZA")]}]},
        t(" of Sch 13")
      ]

      paired = LatTerritory.pair_up(segs)

      assert render(paired, "E+W") == "within 22 [W: , 24 or 24ZA] [E: or 24] of Sch 13"
    end

    test "an old version split over several pieces, the new one nested in the last (1962/58 s.1(5))" do
      old = %Change{kind: :keep, attribute: "E+W"}
      new = %Change{kind: :ins, attribute: "E+W"}

      segs = [
        t("given to "),
        {:pair_old, "X", old, [t("every owner, lessee ")]},
        {:pair_old, "X", old, [t("of the land")]},
        {:pair_old, "X", old, [{:pair_new, "X", new, [t("every person within (6)")]}]},
        t(" and that")
      ]

      assert render(LatTerritory.pair_up(segs)) ==
               "given to [E+W: every person within (6)] [S: every owner, lessee of the land] and that"
    end

    test "the space before a new half that moved into the pair goes with it (1990/8 s.61W(6)(a) \"293B , or\")" do
      old = %Change{kind: :keep, attribute: "W"}
      new = %Change{kind: :ins, attribute: "W"}

      segs = [
        t("293"),
        {:words, %Change{kind: :ins}, [{:pair_old, "X", old, [t("A")]}]},
        t(" "),
        {:words, %Change{kind: :ins}, [{:pair_new, "X", new, [t("B")]}]},
        t(", or")
      ]

      assert render(LatTerritory.pair_up(segs), "E+W") == "293[W: B] [E: A], or"
    end

    test "a SubstitutionRef naming its own enclosing change is no pair: plain retained words (1996/18 s.75A(1A)(c))" do
      old = %Change{kind: :keep, attribute: "E+W"}

      segs = [
        {:pair_new, "X", %Change{kind: :ins}, [{:pair_old, "X", old, [t("being notified—")]}]}
      ]

      assert render(LatTerritory.pair_up(segs)) == "[S: being notified—]"
    end

    test "a SubstitutionRef naming its own enclosing change: no pair, even with sibling pieces of that change (1968/73 s.113(5))" do
      old = %Change{kind: :keep, attribute: "S"}
      enclosing = %Change{kind: :ins}

      segs = [
        {:pair_new, "D", enclosing, [t("means ")]},
        {:pair_new, "D", enclosing, [{:pair_old, "D", old, [t("any local authority")]}]}
      ]

      assert render(LatTerritory.pair_up(segs)) == "means [E+W: any local authority]"
    end

    test "an unmatched half reads as ordinary words" do
      segs = [
        {:pair_old, "Z", %Change{kind: :keep, attribute: "W"}, [t("old")]},
        t(" "),
        {:pair_new, "Y", %Change{kind: :ins, attribute: "W"}, [t("new")]}
      ]

      assert render(LatTerritory.pair_up(segs), "E+W") == "[E: old] [W: new]"
    end
  end

  describe "excluded/3: whole-row territory" do
    test "all retained: the repeals' territories; no territory in the markup → no claim" do
      assert LatTerritory.excluded([keep("S", [t("All.")])], "E+W+S") == "S"
      assert LatTerritory.excluded([keep(nil, [t("All.")])], "E+W+S") == nil
    end

    test "all inserted for a narrower territory: the rest of the extent; none when covering" do
      assert LatTerritory.excluded([ins("W", [t("New.")])], "E+W") == "E"
      assert LatTerritory.excluded([ins("E+W", [t("New.")])], "E+W") == nil
    end

    test "the outermost change decides (Q3: an insertion inside retained words)" do
      segs = [
        keep("S", [t("Nothing applies to "), ins("E+W", [t("Schedule 23")]), t("; but—")])
      ]

      assert LatTerritory.excluded(segs, "E+W+S") == "S"
    end

    test "insertions without a territory are transparent; marks and blanks don't count" do
      segs = [{:mark, "(a) "}, ins(nil, [keep("S", [t("Kept.")])]), t("  ")]
      assert LatTerritory.excluded(segs, "E+W+S") == "S"
    end

    test "nested changes compose: repeals for E+W and S around the same words → both (2004/20 s.75)" do
      assert LatTerritory.excluded(
               [keep("E+W", [keep("S", [t("Schedule 15 has effect.")])])],
               "E+W+S"
             ) ==
               "E+W+S"
    end

    test "nested changes compose: inserted for E, then repealed for E → live nowhere (1990/8 s.61A(1))" do
      assert LatTerritory.excluded(
               [ins("E", [keep("E", [t("A local planning authority may—")])])],
               "E+W"
             ) ==
               "E+W"
    end

    test "asides (a quoted provision's number or title) render but don't count (1974/37 s.78)" do
      segs = [
        keep("S", [t("Insert—")]),
        {:mark, "«"},
        {:aside, [t("(f)")]},
        keep("S", [t("use of place of work.")]),
        {:mark, "»"}
      ]

      assert LatTerritory.excluded(segs, "E+W+S") == "S"
      assert render([{:aside, [t("(f) ")]}, t("words")]) == "(f) words"
    end

    test "a row judged on its subtree is live wherever any of it is (1996/1527 reg.33, 1970/40 pt.II)" do
      segs = [keep("S", [t("Most of it.")]), keep("S", [ins("E", [t("A narrow part.")])])]
      assert LatTerritory.excluded(segs, "E+W+S") == "S"

      assert LatTerritory.excluded(
               [t("Plain."), keep("S", [t("Kept.")])],
               "E+W+S"
             ) == nil
    end

    test "punctuation alone is not the row's own words (2018/482 reg.4(2)(b))" do
      assert LatTerritory.excluded([ins("NI", [t("New words")]), t(".")], "E+W+S+NI") ==
               "E+W+S"
    end

    test "a narrower insertion inside a retained repeal doesn't narrow the row; it is bracketed (1967/10 s.29(1)(a))" do
      segs = [keep("S", [t("section 11"), ins("W", [t(", 26, 26D")]), t(" of this Act")])]
      assert LatTerritory.excluded(segs, "E+W+S") == "S"
      assert render(segs, "E+W+S", "S") == "section 11[W: , 26, 26D] of this Act"
    end

    test "an insertion inside a retained repeal but outside its live territory: live nowhere (1990/43 s.6(6A)(c))" do
      segs = [keep("S", [ins(nil, [ins("S", [t("a solvent emission activity, or")])])])]
      assert LatTerritory.excluded(segs, "E+W+S") == "E+W+S"
    end

    test "excluded = where none of the row's words is live; narrower inner changes keep their brackets (1993/12 s.47(1))" do
      segs = [
        keep("E+W", [
          t("Defined: "),
          ins("S", [t("the appropriate Agency")]),
          t(" and "),
          keep("NI", [t("the HASS Directive")])
        ])
      ]

      assert LatTerritory.excluded(segs, "E+W+S+NI") == "E+W"

      assert render(segs, "E+W+S+NI", "E+W") ==
               "Defined: [S: the appropriate Agency] and [S: the HASS Directive]"
    end

    test "dots inside a retained repeal are the row (the repeal marker: 1967/10 s.1(2A))" do
      dots = ". . . . . . . ."
      assert LatTerritory.excluded([keep("S", [t(dots)])], "E+W+S") == "S"
      assert render([keep("S", [t(dots)])], "E+W+S", "S") == dots
    end

    test "own plain words, a pair, or a mix: nil" do
      assert LatTerritory.excluded([t("Plain "), keep("S", [t("kept")])], "E+W+S") == nil
      assert LatTerritory.excluded([pair("S")], "E+W+S") == nil

      # nothing is live in S: excluded S (the brackets carry the rest)
      assert LatTerritory.excluded([keep("S", [t("a")]), ins("E", [t("b")])], "E+W+S") ==
               "S"

      assert LatTerritory.excluded([], "E+W+S") == nil
    end
  end

  describe "resolve/2 and provenance/1: territory from the effects layer (LR-03)" do
    alias SertantaiLegal.Scraper.EffectIndex
    alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

    defp fx(fields),
      do:
        struct!(
          Effect,
          Keyword.merge(
            [type: "words inserted", affecting: "UK_x", applied: true, affected_refs: []],
            fields
          )
        )

    test "a change joined to its effect takes the effect's territory; the source is recorded" do
      index = EffectIndex.new([fx(effect_id: "key-a", territorial_application: "W")])
      change = %Change{kind: :ins, change_id: "key-a-1460361019464"}

      segs =
        LatTerritory.resolve(
          [t("The "), {:words, change, [t("regulator ")]}, t("may act.")],
          index
        )

      assert LatTerritory.render(segs, "E+W") == "The [W: regulator] may act."

      assert LatTerritory.provenance(segs) == [
               %{
                 source: :effect_application,
                 territory: "W",
                 change_id: "key-a-1460361019464",
                 effect_id: "key-a"
               }
             ]
    end

    test "markup Extent when the effect names none; no claim when neither does" do
      index = EffectIndex.new([fx(effect_id: "key-b")])
      marked = %Change{kind: :ins, attribute: "E", change_id: "key-b-1"}
      silent = %Change{kind: :ins, change_id: "key-b-2"}

      assert [{:words, %Change{territory: "E", source: :markup}, _}] =
               LatTerritory.resolve([{:words, marked, [t("x")]}], index)

      assert [{:words, %Change{territory: nil, source: nil}, _}] =
               LatTerritory.resolve([{:words, silent, [t("x")]}], index)
    end

    test "a synthetic whole-provision change carries its effect id (rule 3: 1974/40 s.101)" do
      index =
        EffectIndex.new([
          fx(
            effect_id: "key-s101",
            type: "repealed",
            effect_extent: "S",
            affected_extent: "E+W+S+N.I."
          )
        ])

      segs =
        LatTerritory.resolve(
          [
            {:words, %Change{kind: :keep, effect_id: "key-s101"},
             [t("The Authority shall have power—")]}
          ],
          index
        )

      assert LatTerritory.excluded(segs, "E+W+S+NI") == "S"

      assert [%{source: :effect_extent, effect_id: "key-s101", territory: "S"}] =
               LatTerritory.provenance(segs)
    end

    test "a markup Extent disjoint from the effect's application: the markup is used and reported (Jason 2026-10-09)" do
      index = EffectIndex.new([fx(effect_id: "key-c", territorial_application: "S")])
      change = %Change{kind: :ins, attribute: "E+W", change_id: "key-c-1"}
      segs = LatTerritory.resolve([{:words, change, [t("x")]}], index)

      assert [%{source: :markup, territory: "E+W", conflict_markup: "E+W"}] =
               LatTerritory.provenance(segs)
    end

    test "an insertion inside a retained repeal narrows where its words are live: text and excluded agree (1990/43 s.153(1)(z6)(i))" do
      segs = [
        {:words, %Change{kind: :keep, attribute: "E+W"},
         [{:words, %Change{kind: :ins, attribute: "S"}, [t("biodiversity supported by land,")]}]}
      ]

      resolved = LatTerritory.resolve(segs, EffectIndex.empty())
      assert LatTerritory.excluded(resolved, "E+W+S+NI") == "E+W+NI"
    end

    test "a substitution's new words with no old words in the markup bracket but don't exclude the row (2013/32 s.89(8)(h))" do
      change = %Change{kind: :ins, attribute: "E+W+S", substitution: true}

      resolved =
        LatTerritory.resolve(
          [{:words, change, [t("the Office of Rail and Road")]}],
          EffectIndex.empty()
        )

      assert LatTerritory.excluded(resolved, "E+W+S+NI") == nil
      assert LatTerritory.render(resolved, "E+W+S+NI") == "[E+W+S: the Office of Rail and Road]"
    end

    test "an effect with no AffectedExtent is measured against the law's own extent (an SSI amended by an SSI)" do
      index = EffectIndex.new([fx(effect_id: "key-ss", effect_extent: "S")], [], "S")

      segs =
        LatTerritory.resolve(
          [{:words, %Change{kind: :ins, change_id: "key-ss-1"}, [t("x")]}],
          index
        )

      assert LatTerritory.provenance(segs) == []
    end
  end
end
