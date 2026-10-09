---
session: 'LR-02: LatTerritory Module'
status: active
opened: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-02 LatTerritory Module (ACTIVE)

## Problem

Territory is decided in five places with three rules, and carried through the text pipeline as private-use placeholder characters re-parsed by regex (`with_territories`); `excluded_extent` comes from a second XML walk (`retained_segments`). LR-02 puts one rule (attribute ∪ note) in one pure module and builds row text as segments, so the 9 `pending: "LR-02"` fixtures go green with the 18 already green unchanged.

## Todo

- ✅ `LatSegments` (pure): segment type — text, marks (labels, separators, «», …), words/pair changes; join, trim, blank?, plain (tests first)
- ✅ `LatTerritory` (pure): `%Change{}`, `territory/2` (attribute ∪ note), `pair_up/1` (non-sibling halves), `render/4`, `excluded/3` (tests first)
- ✅ `Territory.from_note`: spelled-out names after a change verb ("disapplied in relation to Wales") (Q1)
- ✅ Parser: text producers return segments; delete placeholders, `with_territories`, `plain_text`, `merge` round trip, `retained_segments`
- ✅ Fixtures: 9 LR-02 pending → green; 18 stay green; full suite green
- ⬜ Classified corpus diff vs DB with an expect file; every class explained; 0 unexpected
- ⬜ Gemini acceptance review of the result

## Dependencies

- ✅ LR-01 fixtures + classified diff (baseline 0)

## Work (2026-10-09)

- **`LatSegments`** (pure, 6 tests): `{:text}`, `{:mark}` (labels, separators, «», …: never the row's own words), `{:words, change, inner}`, `{:pair, change, new, old}`, transient `{:pair_old}` / `{:pair_new}`.
- **`LatTerritory`** (pure, 15 tests): `%Change{kind, attribute, ref}`; `territory/2` = attribute ∪ note (Q1); `pair_up/1` joins non-sibling substitution halves; `render/4` (nested changes rendered within the outer change's live territory: a narrower insertion keeps its bracket, nested repeals vanish where all repealed); `excluded/3` (outermost change decides — Q3; insertions without territory transparent; marks ignored).
- **`Territory.from_note`**: spelled-out territories straight after a change verb ("disapplied in relation to Wales"); titles / "Functions in relation to Wales" excluded (2 tests).
- **Parser**: every text producer returns segments (inline, lists, tables, quotes, #174 trailing, AppendText); `excluded_extent` from the same segments (own text, else subtree). Deleted: 7 placeholder characters, `with_territories`, `plain_text`, `pair_label`, `words_label`, `inserted_label`, `placeholder`, `render_pair`, `pair_territory`, `retained_segments`/`retained_child`/`retained_territory`, `@not_retained_text`. A change element wrapping whole blocks (`<Repeal><Text>…</Text></Repeal>`) wraps each block (caught by an existing test).
- **Tests**: fixtures 27/30 (all 9 LR-02 green; 3 LR-03 pending); one existing test changed by decision Q1 ("Extent wins over the note" → union). Diff classifier gained `text: whitespace`.

## Corpus diff review (2026-10-09)

Run 1 (`data/reports/lat-refactor/lr02-diff.csv`): 8,035 rows changed in 40+ classes. Findings, each fixed test-first before run 2:
- **An `<Addition>` citing a repeal note** ("S. 5 repealed (16.12.1996 for E.W. …)", 1974/37 s.5; 1875/17 s.115; 1883/3 s.4(2)): the note's territory was taken as an insertion's. Rule: a note counts only for a change of its kind (`:ins` ← inserted/substituted/amended notes; `:keep` ← any other; `:pair` ← any). Lookup now `{territory, effect}` (`AmendmentNote.effect_of/1`).
  - Open finding (not changed): such Additions mark text repealed for some territories — arguably retained repeals. DB has nil today; candidate for LR-03 / later.
- **`Territory.from_note` read only the first "for X."** of a note in force on different dates per territory ("inserted (1.10.2017 for E., 1.4.2019 for W.)" → E, so W wrongly excluded): latent since notes never fed insertions before. Now every "for X." in the bracket counts (1991/56 s.104(5A), 1990/43 s.62ZA, 1984/22 Pt. 2A).

Run 2: 5,658 rows. Findings, each fixed test-first before run 3:
- **Q1 refined — attribute vs note**: a union of all note clauses wiped a precise attribute (2004/21 s.21A: Addition Extent="W", note "inserted (E.W.)" — the amending Act's extent; s.21A is Welsh-only). Rule now: the attribute, plus each note clause whose territory is **disjoint** from it (a separate change); an overlapping clause is the amending law's extent. Gives 1996/1527 W+S, 1981/29 s.22(3) E+W+S ("repealed (E.W.) … and … repealed (S.)", Extent="S"), 2004/21 W. `Territory.note_territories/1` (per clause), `disjoint?/2`. **For Jason: refines his Q1 "union".**
- **Quoted numbers and titles counted as words** (1974/37 s.78: «(f) …» made a wholly retained row "mixed"): now `{:aside, …}` — shown, never the row's own words (as the old walk's Pnumber/Title rule).
- **Non-breaking spaces collapsed** by the new renderer (~r/\s+/u): EU "point (a)" → most of the 872 `text: whitespace` rows. Restored the old ASCII-only collapse (fractalaw would re-enrich for nothing).
- **Nested changes in `excluded`**: "outermost decides" was wrong both ways (2004/20 s.75: repeal E+W around repeal S → E+W+S, not E+W; 1990/8 s.61A(1): inserted for E around repealed for E → live nowhere). Now composed outside-in exactly as rendering does: insertion narrows the live territory, retained repeal removes its territory.
- Confirmed improvements (not defects): 1968/27 s.24(4)(b) non-sibling pair now "[S: new] [E+W: old]" (old words were glued unbracketed); 1965/57 s.24A(1) "the Executive mayONR" → new words only; 1995/25 s.102(1) "repealed (1.4.2010 for W., 1.4.2011 for E.)" → E+W; EU 2016/425 "[E+W+S: United Kingdom]" (GB-only substitution).
- Known edge (not changed): 1883/3 s.6(2) legacy markup tags the *old* word "himself" as an Addition citing the substitution note → "[E+W: himselfthat witness…]" (was glued before too).

Run 3: 4,855 rows. Findings, fixed test-first before run 4:
- **Edge whitespace inside a change** wasn't trimmed at block edges ("registration. . »" in EU 2006/1907; "driving ; Section 3" in a 1988/52 table): `LatSegments.trim` now reaches into an edge change/aside; `join_blocks` trims (as the old string pipeline did).
- **Old version split over several pieces, the new nested inside the last** (1962/58 s.1(5), 1984/27 s.99(1)(c)): `pair_up` now joins every old piece with the id into one old version and finds new pieces nested in old ones.
- Confirmed improvements: composition removes `excluded_extent` naming territories outside the row (1967/10 s.10A is W-only; old said S) and version rows (1996/1527 [E+W+NI] → W; 1990/43 [S+NI] → nil); whole-row bracketed rows → plain + excluded (1967/10 s.1(3A)(a), 1981/69 s.41(5), 1993/11, 1996/972); non-sibling pairs now "[T: new] [rest: old]" (1974/37 s.15(3B), 1981/69 s.27AA(2)(b), 1982/16 s.78(9)(ii), 1984/55 s.84(1), 1986/14 s.29(5)); note-only word territory bracketed (1981/69 s.17 "[S: or 16AA]"; 1970/44 s.20(2) "the Highways Act 1980" — "1980or" is glued in the source).
- Known edge (source contradiction, not changed): 1996/37 s.10(4)(a) Addition Extent="N.I." but note "inserted (E.W.)" by an E+W Act → disjoint clause unions to the whole extent → plain (old "[NI: …]" was wrong too).

Run 4: 4,841 rows in 40 classes. Agent review of 167 rows sampled per class (`data/reports/lat-refactor/lr02-review/`, brief + 4 slices), each claim checked against the XML before acting:
- **Fixed** (test-first, code bugs): a note's dates bracket cut at a nested ")" (1991/56 s.51CF(8)); only the first "(X.)" of a clause read (1996/18 s.50); "(E.W.N.I)" without its final dot (2007/19); a dated part naming no territory — "for specified purposes", "otherwise <date>" — means everywhere (1990/9 s.20A, 1990/18 s.3A, 1990/43 s.78X); a retained Repeal citing a *substitution* note keeps its territory (its new words are another row: 1998/494, 2015/1640, 1998/30, 1999/29); signatures built as segments so a retained repeal around them counts (1989/1263 signed.72 — a regression vs the old walk; an attribute-only date is a mark); a whole-row change renders plain but its inner changes within its territory (1986/14 s.29(5A)).
- **Stopped — design question for Jason**: most remaining wrong rows come from reading **commencement-by-territory notes** ("inserted (6.4.2012 for E.)", "(21.3.2000 for E.W., 1.4.2015 for S.)") as where the words *apply*. They say where the words are *in force*. That belongs to `status` (`in_force_partial` / prospective), not `excluded_extent` / brackets. Every interpretation fix moves the edge rather than closing it — the piecemeal pattern this refactor exists to stop.
- Other rule questions raised by the review (not acted on): "extended (S. and N.I.)" notes; "(E.W. with application in relation to E.)"; a retained Repeal + Substitution citing the same note with no SubstitutionRef (an unlinked pair, 2004/20 s.37(7)); punctuation-only text outside a change blocking the whole-row rule (2018/482 reg.4(2)(b)); bracket labels not clipped to the row extent (1968/73 s.10(1)[E+W+NI]); heading/structural rows judged on their subtree intersect differing territories (1993/12 s.47, 1996/972 reg.5, 1996/1527 pt.VII).
- Slice 3 (38 rows) adds code bugs independent of the design question: whitespace between pair halves emitted after the merged pair ("293B , or"); a `SubstitutionRef` naming its own enclosing Addition (1996/18 s.75A(1A)(c), 2003/21 s.402(2)(aa)) → treat as a plain retained repeal; rows judged on their subtree should take the **union** of live territories, not the intersection (1996/1527 reg.33, 1970/40 pt.II). More commencement-as-territory cases ("1.9.2006 for E.S., 1.1.2007 in so far as not already in force"; "for E. for specified purposes").
- Review totals (167 sampled rows, 8 per class): ~33 wrong (~20%), ~10 since fixed; the large classes (nil → W 1,720 rows: 7/8 right) are mostly right. Paused for Jason's decision on commencement vs territory.

## Notes grounded (2026-10-09)

Jason asked for the research, not a guess: `docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md` (official sources + corpus). Bare "(X.)" in an F note = where the change applies (= Extent attribute, 97.8% agreement); dated "date for X." = where it is in force. Jason: "clean up code built on mistaken model of Notes. Go LR-02".
- **New `NoteTerritory`** (pure, grounded): `applies/1` (bare / spelled-out), `in_force/1` (dated qualifiers; purposes ignored; catch-alls everywhere; except X → all but X). The old `from_note` cases migrated into its tests.
- **`Territory` cleaned** to set operations only: `from_note`, `note_territories`, clause/dated-part/bracket heuristics deleted (they mixed the two forms).
- **`LatTerritory.territory/2`**: attribute (+ disjoint bare clauses) → bare clauses → in-force territory only for changes that remove text (retained repeal, substitution pair). Insertions never take a dated territory (commencement → status).
- **Fixture changed by the grounding**: 1990/8 s.202D "inserted (6.4.2012 for E.)" → no exclusion (commencement).
- **Review code bugs fixed** (test-first): whitespace left by a new half that moved into its pair; a SubstitutionRef naming its own enclosing change is no pair; rows judged on their subtree are live wherever any of it is (union); bracket labels clipped to the row; punctuation alone isn't the row's words.
- Suite 2,398 passed; fixtures 28/31 (3 LR-03).

## Principle change (2026-10-09)

Jason: notes are hints, not facts ("we're going the wrong way in the chain"). LR-02 finishes as is — its note-text territory fallback reads the same fact the effect holds (bare "(X.)" = territorial application, 98% agreement with Extent) and is marked **interim**: LR-03 replaces it with the effects layer where an effect exists. Diff run 6: 3,504 rows (punctuation fix restored repeal-marker rows).
