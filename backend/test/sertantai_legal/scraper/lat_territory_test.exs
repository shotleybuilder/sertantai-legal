defmodule SertantaiLegal.Scraper.LatTerritoryTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatTerritory
  alias SertantaiLegal.Scraper.LatTerritory.Change

  # note id → what the note says (NoteTerritory): where its change applies
  # (bare "(X.)"), where it is in force (dated "for X."), its effect
  @lookup %{
    "n-s" => %{applies: ["S"], in_force: nil, effect: "repealed"},
    "n-w" => %{applies: ["W"], in_force: nil, effect: "inserted"},
    "n-none" => %{applies: [], in_force: nil, effect: "repealed"},
    "n-rep-ew" => %{applies: ["E+W"], in_force: nil, effect: "repealed"},
    "n-sub-s" => %{applies: ["S"], in_force: nil, effect: "substituted"},
    "n-ins-ew" => %{applies: ["E+W"], in_force: nil, effect: "inserted"},
    "n-s-and-w" => %{applies: ["S", "W"], in_force: nil, effect: "other"},
    # dated: "inserted (6.4.2012 for E.)" / "repealed (1.4.2015 for S.)"
    "n-ins-for-e" => %{applies: [], in_force: "E", effect: "inserted"},
    "n-rep-for-s" => %{applies: [], in_force: "S", effect: "repealed"},
    "n-sub-for-e" => %{applies: [], in_force: "E", effect: "substituted"}
  }

  defp keep(attr, ref \\ nil, inner),
    do: {:words, %Change{kind: :keep, attribute: attr, ref: ref}, inner}

  defp ins(attr, ref \\ nil, inner),
    do: {:words, %Change{kind: :ins, attribute: attr, ref: ref}, inner}

  defp t(s), do: {:text, s}

  defp render(segs, extent \\ "E+W+S", excluded \\ nil),
    do: LatTerritory.render(segs, extent, @lookup, excluded)

  describe "territory/2: attribute ∪ note" do
    test "attribute, note, both, neither" do
      assert LatTerritory.territory(%Change{kind: :keep, attribute: "S"}, @lookup) == "S"
      assert LatTerritory.territory(%Change{kind: :ins, ref: "n-w"}, @lookup) == "W"

      assert LatTerritory.territory(%Change{kind: :ins, attribute: "S", ref: "n-w"}, @lookup) ==
               "W+S"

      assert LatTerritory.territory(%Change{kind: :keep, ref: "n-none"}, @lookup) == nil
      assert LatTerritory.territory(%Change{kind: :keep}, @lookup) == nil
    end

    test "with an attribute, a note adds only clauses disjoint from it (a separate change); an overlapping clause is the amending law's extent" do
      # 2004/21 s.21A: Addition Extent="W", note "inserted (E.W.)"
      assert LatTerritory.territory(%Change{kind: :ins, attribute: "W", ref: "n-ins-ew"}, @lookup) ==
               "W"

      # 1996/1527: Extent="S", note "disapplied in relation to Scotland …; … Wales"
      assert LatTerritory.territory(
               %Change{kind: :keep, attribute: "S", ref: "n-s-and-w"},
               @lookup
             ) == "W+S"
    end

    test "a dated \"for X.\" (in force) is territory only for a change that removes text (typology §3)" do
      # an insertion in force in E still extends to W: commencement → status
      assert LatTerritory.territory(%Change{kind: :ins, ref: "n-ins-for-e"}, @lookup) == nil
      # a retained repeal in force for S removes the text in S
      assert LatTerritory.territory(%Change{kind: :keep, ref: "n-rep-for-s"}, @lookup) == "S"
      # a substitution in force in E: the old words go there
      assert LatTerritory.territory(%Change{kind: :pair, ref: "n-sub-for-e"}, @lookup) == "E"
      # where it applies wins over where it is in force
      assert LatTerritory.territory(
               %Change{kind: :keep, attribute: "E+W", ref: "n-rep-for-s"},
               @lookup
             ) == "E+W"
    end

    test "a note counts only for a change of its kind (1974/37 s.5: an Addition citing \"S. 5 repealed (… for E.W.)\")" do
      assert LatTerritory.territory(%Change{kind: :ins, ref: "n-rep-ew"}, @lookup) == nil
      assert LatTerritory.territory(%Change{kind: :keep, ref: "n-w"}, @lookup) == nil
      # the old words of a substitution whose new words are another row (1998/494 reg.4(3)(e))
      assert LatTerritory.territory(%Change{kind: :keep, ref: "n-sub-s"}, @lookup) == "S"
      assert LatTerritory.territory(%Change{kind: :keep, ref: "n-s"}, @lookup) == "S"
      # a substitution pair takes its note whatever the verb
      assert LatTerritory.territory(%Change{kind: :pair, ref: "n-sub-s"}, @lookup) == "S"
    end
  end

  describe "render/4: words" do
    test "retained words: bracketed with where they still apply; plain when no territory" do
      assert render([t("A duty "), keep("S", [t("to report")]), t(" applies.")]) ==
               "A duty [E+W: to report] applies."

      assert render([t("A "), keep(nil, "n-none", [t("duty")])]) == "A duty"
    end

    test "inserted words: bracketed when narrower; plain when covering, outside or no territory" do
      segs = [t("The "), ins(nil, "n-w", [t("regulator ")]), t("may act.")]
      assert render(segs, "E+W") == "The [W: regulator] may act."
      assert render(segs, "W") == "The regulator may act."
      assert render(segs, "S") == "The regulator may act."

      assert render([t("The "), ins(nil, nil, [t("regulator ")]), t("acts.")]) ==
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
    defp pair(attr, ref \\ nil),
      do:
        {:pair, %Change{kind: :keep, attribute: attr, ref: ref}, [t("the service")],
         [t("the brigade")]}

    test "both versions, new first; extremes; no territory keeps both apart in document order" do
      assert render([t("by "), pair("S"), t(" now")]) ==
               "by [S: the service] [E+W: the brigade] now"

      assert render([t("by "), pair(nil, "n-s")]) == "by [S: the service] [E+W: the brigade]"
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
      old = %Change{kind: :keep, attribute: "W", ref: "n-w"}
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
    test "all retained: the repeals' territories; no territory → the whole extent" do
      assert LatTerritory.excluded([keep("S", [t("All.")])], "E+W+S", @lookup) == "S"

      assert LatTerritory.excluded([keep(nil, "n-none", [t("All.")])], "E+W+S", @lookup) ==
               "E+W+S"
    end

    test "all inserted for a narrower territory: the rest of the extent; none when covering" do
      assert LatTerritory.excluded([ins(nil, "n-w", [t("New.")])], "E+W", @lookup) == "E"
      assert LatTerritory.excluded([ins("E+W", [t("New.")])], "E+W", @lookup) == nil
    end

    test "the outermost change decides (Q3: an insertion inside retained words)" do
      segs = [
        keep(nil, "n-s", [t("Nothing applies to "), ins("E+W", [t("Schedule 23")]), t("; but—")])
      ]

      assert LatTerritory.excluded(segs, "E+W+S", @lookup) == "S"
    end

    test "insertions without a territory are transparent; marks and blanks don't count" do
      segs = [{:mark, "(a) "}, ins(nil, nil, [keep("S", [t("Kept.")])]), t("  ")]
      assert LatTerritory.excluded(segs, "E+W+S", @lookup) == "S"
    end

    test "nested changes compose: repeals for E+W and S around the same words → both (2004/20 s.75)" do
      assert LatTerritory.excluded(
               [keep("E+W", [keep("S", [t("Schedule 15 has effect.")])])],
               "E+W+S",
               @lookup
             ) ==
               "E+W+S"
    end

    test "nested changes compose: inserted for E, then repealed for E → live nowhere (1990/8 s.61A(1))" do
      assert LatTerritory.excluded(
               [ins("E", [keep("E", [t("A local planning authority may—")])])],
               "E+W",
               @lookup
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

      assert LatTerritory.excluded(segs, "E+W+S", @lookup) == "S"
      assert render([{:aside, [t("(f) ")]}, t("words")]) == "(f) words"
    end

    test "a row judged on its subtree is live wherever any of it is (1996/1527 reg.33, 1970/40 pt.II)" do
      segs = [keep("S", [t("Most of it.")]), keep("S", [ins("E", [t("A narrow part.")])])]
      assert LatTerritory.excluded(segs, "E+W+S", @lookup) == "S"

      assert LatTerritory.excluded(
               [t("Plain."), keep("S", [t("Kept.")])],
               "E+W+S",
               @lookup
             ) == nil
    end

    test "punctuation alone is not the row's own words (2018/482 reg.4(2)(b))" do
      assert LatTerritory.excluded([ins("NI", [t("New words")]), t(".")], "E+W+S+NI", @lookup) ==
               "E+W+S"
    end

    test "a narrower insertion inside a retained repeal doesn't narrow the row; it is bracketed (1967/10 s.29(1)(a))" do
      segs = [keep("S", [t("section 11"), ins("W", [t(", 26, 26D")]), t(" of this Act")])]
      assert LatTerritory.excluded(segs, "E+W+S", @lookup) == "S"
      assert render(segs, "E+W+S", "S") == "section 11[W: , 26, 26D] of this Act"
    end

    test "an insertion inside a retained repeal but outside its live territory: live nowhere (1990/43 s.6(6A)(c))" do
      segs = [keep("S", [ins(nil, nil, [ins("S", [t("a solvent emission activity, or")])])])]
      assert LatTerritory.excluded(segs, "E+W+S", @lookup) == "E+W+S"
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

      assert LatTerritory.excluded(segs, "E+W+S+NI", @lookup) == "E+W"

      assert render(segs, "E+W+S+NI", "E+W") ==
               "Defined: [S: the appropriate Agency] and [S: the HASS Directive]"
    end

    test "dots inside a retained repeal are the row (the repeal marker: 1967/10 s.1(2A))" do
      dots = ". . . . . . . ."
      assert LatTerritory.excluded([keep("S", [t(dots)])], "E+W+S", @lookup) == "S"
      assert render([keep("S", [t(dots)])], "E+W+S", "S") == dots
    end

    test "own plain words, a pair, or a mix: nil" do
      assert LatTerritory.excluded([t("Plain "), keep("S", [t("kept")])], "E+W+S", @lookup) == nil
      assert LatTerritory.excluded([pair("S")], "E+W+S", @lookup) == nil

      # nothing is live in S: excluded S (the brackets carry the rest)
      assert LatTerritory.excluded([keep("S", [t("a")]), ins("E", [t("b")])], "E+W+S", @lookup) ==
               "S"

      assert LatTerritory.excluded([], "E+W+S", @lookup) == nil
    end
  end
end
