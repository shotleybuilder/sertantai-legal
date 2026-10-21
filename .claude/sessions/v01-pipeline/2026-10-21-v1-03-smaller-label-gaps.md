---
session: 'V1-03: Smaller Label Gaps on Laws from 2002'
status: active
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
bugs:
  - pattern: 'A row id with a duplicate disambiguator ("s.1(2)n1") has no ancestors (LatStatus.ancestors), so it never inherits an ancestor''s change or commencement'
    category: label projection
    module: LatStatus.ancestors
    affected: '552 rows / 90 laws (141 / 36 from 2002)'
    fix: LatRef.ancestors/1 reads past the disambiguator; the label-side callers use it (LatStatus.ancestors stays the parser's)
    status: fixed
  - pattern: 'A row commenced only through some of the children it is above (SI 2026/318 reg.11(1): (1)(a)-(b) from 2026-09-19, (c)-(i) from 2027-01-19) reads in force, not in force partly'
    category: label projection
    module: LabelProjection (commencement reaching rows above a member, V1-01)
    affected: 'unknown; found in the V1-01 preview'
    fix: a commencement reaching the row only from above a member is partial unless every child it holds is commenced
    status: open
  - pattern: 'T1 compared a note''s law with the feed''s by exact name: a Welsh SI''s note cites its uksi URI ("UK_uksi_2011_971"), the feed records "UK_wsi_2011_971"'
    category: label timeline (T1)
    module: LabelTimeline.undated_change/law_key
    affected: '~200 rows (SI 2005/1806 uksi + wsi, 2004/1490 …)'
    fix: law_key/1 treats wsi and its uksi URI as one law
    status: fixed
  - pattern: 'T1 flagged a note whose law isn''t the dated record''s even when that dated record is joined to the very note ("inserted by S.I. 2019/465 … (as substituted) by S.I. 2020/1359", fed as 2020/1359)'
    category: label timeline (T1)
    module: LabelTimeline.undated_change
    affected: 'part of 321 note-named rows ≥2002'
    fix: a dated text change whose pointer is the note's code explains the note
    status: fixed
  - pattern: 'T1 undated_markup let only amending-law records explain markup: legacy M_F_ markup with a dated feed effect joined through the same note stayed "date unknown" (2004 c.20 s.10(2)(b), SI 2010/675)'
    category: label timeline (T1)
    module: LabelTimeline.undated_markup
    affected: 'part of 588 markup rows ≥2002'
    fix: a dated feed effect with the same note pointer explains the markup
    status: fixed
  - pattern: 'An ending ("expires", "expired", "ceases to have effect") read as a modification (other): no version, no repeal, and its note left the row "date unknown" (Coronavirus Act 2020)'
    category: change kind
    module: EffectFacts.kind (label side; EffectKind, the parser's, unchanged)
    affected: '~155 rows ≥2002 (2020 c.7 150)'
    fix: an ending is a repeal (Jason 2026-10-18); "expires in part" a text change (amended)
    status: fixed
  - pattern: 'A feed effect with no territorial application took its effect extent: a Welsh law''s change read E+W, an "(England)" SI''s omission read E+W (SI 2023/911 on SI 2010/404 reg.14: repealed everywhere, still in force in Wales), "(Scotland)" laws with no extent read everywhere'
    category: territory
    module: ChangeCollector.Feed (territory option) / ChangeCollector.law_extent (title place)
    affected: 'feed records from Welsh-type, "(England)", "(Scotland)" laws with no territorial application (hundreds of repeals, thousands of insertions/substitutions)'
    fix: 'the affecting law''s territory as the amending-law records (AR-09 — devolved type, title place, narrower register extent); nil when the amended law is devolved to the same territory'
    status: fixed
  - pattern: 'LAT facts derived from legislation.gov.uk note text alone where no markup or effect supports them (AmendmentNote / LatStatus fallback kept by LR-07 against the 2026-10-09 decision)'
    category: stale (checked V1-03)
    module: scraper/change_facts.ex, amendment_note.ex
    affected: 'none today'
    fix: deleted in LR-25 step 7 (AmendmentNote → NotePointer, ChangeFacts → EffectFacts); note_read_test forbids facts from notes
    status: fixed
  - pattern: 'A note''s joined effects spread to every row the note sits on: a pointer (cited-law) join pairs every effect found with every placement row; a markup join reaches rows whose text doesn''t carry the change'
    category: stale (checked V1-03)
    module: ChangeCollector.Feed
    affected: 'none today'
    fix: Feed.note_targets — a markup join only to rows whose own markup carries the change, a cited join only to the provision the effect was found on
    status: fixed
  - pattern: 'Feed effects whose affected provision is given only as text (''Part 2B inserted'', no AffectedProvisions refs) reach no LAT row, so the rows of an inserted Part have no dated insertion'
    category: stale (checked V1-03)
    module: EffectTarget / ProvisionText
    affected: 'none today'
    fix: LR-29 lands an effect where its own AffectedProvisions text says ("Pt. 2B" parses as the Part)
    status: fixed
  - pattern: 'A title place taken from a cited law ("Forestry and Land Management (Scotland) Act 2018 (Consequential Provisions and Modifications) Order" read as Scotland); Northern Ireland titles ("Mines Act (Northern Ireland)") and "(Scotland) Amendment Regulations" missed'
    category: territory
    module: ChangeCollector.title_place
    affected: '101 affecting laws differ from the first rule; 93 LAT laws re-previewed'
    fix: the place belonging to the law''s own name (before its instrument word, or after it as NI's), never one followed by a cited Act and year (086c2ab6)
    status: fixed
  - pattern: 'T1 markup on an orphan id (a note id the feed doesn''t hold) stayed "date unknown" though its note''s law has a dated text change on the row; markup joined to a feed effect (pointer nil, evidence = its id) wasn''t explained either'
    category: label timeline (T1)
    module: LabelTimeline.undated_change / unexplained_markup
    affected: 'SI 2010/2214 210 → 48 undated rows; ~300 laws with undated changes re-previewed'
    fix: markup explained by a dated effect whose id is its ref, or by its note''s law''s dated text change on the row (086c2ab6)
    status: fixed
  - pattern: 'J5 read "definition of … inserted" / "entry … inserted" as the provision inserted, withholding the law''s start from the provision and its children (NISI 2003/419 art.2)'
    category: label timeline (J5)
    module: LabelTimeline.whole_insertion_note?
    affected: '61 laws with such notes'
    fix: a definition or entry note is words-level, like "words" (858e3b5e)
    status: fixed
---

# Session: V1-03: Smaller Label Gaps on Laws from 2002 (ACTIVE)

## Problem

After V1-01 and V1-02, the rest of the v0.1 label load on UK laws from 2002 on is a set of smaller gaps (AR measure dry run, 2026-10-21): 1,366 undated changes in 133 laws (SI 2010/2214 198, 2020 c.7 151, SI 2005/1806 and its wsi twin 103 each, 2004 c.20 82); 144 insertions not in the register; rows whose id carries a duplicate disambiguator (`s.1(2)n1`) have no ancestors, so they inherit nothing (552 rows / 90 laws, 141 / 36 ≥2002; AR-00 open bug); feed effects named only in text ("Part 2B inserted", 24 effects, LR-27); a retained repeal read as everywhere where the note names a territory (8 rows: 2010/404 reg.14, 2020/7 s.8; LR-17). Several LR open bugs look stale (fixed by LR-25 under other wording) and need checking.

## Todo

- ✅ Disambiguator ancestors: `LatRef.ancestors/1` (label side) reads past `nN`; `LatStatus.ancestors` left as the parser's (it counts toward ParserVersion, not LabelVersion) (§1)
- ✅ Undated changes ≥2002 attributed by T1 reason (§2); fixed: twins, a note joined to a dated change, markup explained by a dated effect, endings; amending-law dating needs the re-read own-clause rules
- ✅ Insertions not in the register ≥2002 (118 after the dry run): a definition/entry note read as a whole insertion fixed (J5); the rest are genuine J5 (a note says inserted, nothing dates it) — V1-04's audit lists them; text-only refs closed (stale, §4)
- ✅ LR-17's rows: the cause is wider — feed effects with no territory take the affecting law's (AR-09 rule + title places) (§3)
- ✅ Stale bugs: 3 closed (LR-20 note facts, LR-23 note spread, LR-27 text-only refs); LR-20 provenance left open for Jason (§4)
- ⏸️ A row commenced through only some of its children (V1-01 finding): known limit — a fix needs the row's children, which the projection doesn't see; a blanket "partial" would leave SI 2026/318 reg.11(1) partial after 2027
- ⬜ Preview only the affected laws, splice into `v101_final`; batch into the v0.1 relabel (V1-00)

## Dependencies

- ⬜ V1-01, V1-02 (their previews first, so splices don't overlap)
- ✅ AR measure dry run (2026-10-21)

## 1. Disambiguator ancestors (2026-10-21)

`LatStatus.ancestors("L:s.1(2)n1")` gave only the row itself, so 552 rows in 90 laws inherited nothing. In asp 2002/3 there is no `s.1(2)` row: the children `s.1(2)(a)/(b)` hang off `s.1(2)`, and the `n1` row is the provision. `LatStatus` counts toward `ParserVersion`, not `LabelVersion`, so changing it would stale every parse while the labels moved unhashed. `LatRef.ancestors/1` (a `LabelVersion` input that already knew disambiguators) now reads past `nN`, and the label-side callers use it (`LabelProjection`, `LabelTimeline`, `ChangeCollector`, `ChangeCollector.Commencement`). `LatParseLog` keeps `LatStatus`.

## 2. Undated changes ≥2002 by T1 reason

Measured on the stored register (it predates the AR and V1 changes; a guide only): 1,092 rows.

| Reason | Rows | Cause found |
|---|---|---|
| markup no record explains | 588 | legacy `M_F_` markup whose dated feed effect is joined through the same note; T1 let only amending-law records explain markup |
| note names a law with no dated change | 321 | Welsh twins (the note cites the uksi URI, the feed records the wsi law); "inserted by S.I. 2019/465 … (as substituted) by S.I. 2020/1359", fed as 2020/1359's, with the record joined to the very note |
| endings (expiry) | 155 | "expires" read as a modification (other): no text change, so its note stays undated |
| amending-law record undated | 99 | SI 2010/2214 changed by SI 2012/3119, whose stored own-clause rule was the stale `clause_unread` (V1-02 reads its Schedule table) |
| note names no law | 39 | — |

Fixed (label side; `LabelVersion` only): `LabelTimeline.undated_change/2` (twins via `law_key/1`; a dated text change joined to the note explains it), `undated_markup/1` (a dated feed effect with the note's pointer explains markup), `EffectFacts.kind/2` (an ending is a repeal, Jason 2026-10-18; "expires in part" is a text change). `EffectKind` is the parser's and is unchanged. **Re-read needed:** own-clause rules (`--read --all`) and amending laws' own clauses (`--read-amending`), so other laws' changes are dated by V1-02's readers.

## 3. Feed territory (LR-17, wider)

SI 2023/911, the Building Regulations etc. (Amendment) **(England)** Regulations 2023, omits SI 2010/404 reg.14 "(E.)". The feed gives no territorial application and an effect extent of E+W, so the row read repealed everywhere. A feed effect with no territorial application now takes its affecting law's territory, as amending-law records do (AR-09): devolved type, then title place, then a register extent narrower than the UK; nil when the amended law is devolved to the same territory. `ChangeCollector.law_extent/1` prefers the title's place over `geo_extent`, so AR-09's amending-law records take "(England)" too.

## 4. Stale open bugs

Closed: LR-20 note-text facts, LR-23 note-join spread, LR-27 text-only refs (frontmatter, with the code that fixed each). Left open for Jason: LR-20 "Provenance mislabelled or missing for note-derived values … change-log cause, renumbering renames and the manifest amended flag record none". The label provenance went with LR-25; whether the change-log cause, renames and amended flag now record provenance wasn't checked here.

## 5. The v0.1 dry run and follow-ups (2026-10-21)

**Full preview `v01_dry`** (after the rule re-reads: own clauses for 1,066 laws, own clauses of 1,467 amending laws with no LAT; 0 errors). UK ≥2002: undated_change 1,366 → 901, unknown today 326 → 300, insertion_not_in_register 144 → 118. Since `v102_final2`, 2,692 label values moved in 1,128 rows. Checked:
- **Fire Services Act 1947** now reads repealed: E+W by the 2004 Act, S by asp 2005/5 except ss.26–27A.
- **Forestry Act 1967 s.1(4)(a)** now reads in force (repealed only for S and W); today's territory stays E+W+S, the parse's.
- **SI 2010/404 reg.14** reads in force until today; today's markup (repealed-saved) wins under J2.
- **Coronavirus Act 2020 endings** now read as repeals.

**Found in the dry run, fixed (`086c2ab6`):**
- the title rule took a place from a cited Act;
- T1 left markup on orphan note ids undated when the note's law has a dated change on the row (SI 2010/2214 210 → 48).

**Preview `v103c`:** the union of laws with undated changes (299) and the laws the title rule moves (93): 324 laws, running.

**Moved to V1-04 (Jason 2026-10-21):** SI 2010/404 reg.14 still reads repealed today. The markup keeps the text; the parse's territory claim (`EffectTerritory` `:effect_everywhere`) reads the "(England)" SI's retained repeal as everywhere, and J2 holds it. The fix is at source, in the parse, with the V1-03 law-territory rule shared: `v01-pipeline/2026-10-21-v1-04-parse-territory-retained-repeals.md`.

## 6. Spliced and last items (2026-10-21)

- **`v103c` (324 laws, 0 errors)** spliced into `v01_final`. For UK laws from 2002, undated_change 1,366 (V1-03 start) → 901 (dry run) → **548**, and unknown today 300. Corpus label changes vs today's DB: 41,216 over 18,570 rows in 380 laws.
- **J5 definitions (`858e3b5e`).** "Art. 2: definition of … inserted" withheld art.2's start: a definition or entry is words-level. 61 laws affected; `v103d` is previewing them. NISI 2003/419's remaining 17 rows are genuine J5 (inserted provisions nothing dates). The residual undated insertions (~118) and notes naming no law (~39) go to V1-04's audit.
- **`v103d` (61 laws, 0 errors)** spliced into `v01_final`: unknown 3,298 → 3,268 and insertion_not_in_register 3,180 → 3,150 in those laws, mostly older ones. The Wildlife and Countryside Act 1981 loses 2 of 4,046 periods (merged history; no change to today's labels).
- **`v01_final` now:**
  - UK ≥2002: unknown today 300, undated_change 548, insertion_not_in_register 118, no_start 142 (known limits).
  - Corpus: unknown today 11,177; label changes vs today's DB 41,298 over 18,604 rows in 382 laws.
