---
session: 'LR-19: Effect Joins'
status: closed
opened: 2026-10-12
closed: 2026-10-13
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  Provision labels now come from the right effects: the orphan join no longer takes another
  change's or another law's effect (D2), legacy notes point rows to their provision's effect by
  the cited law (D1), and an undated changed_by needs a single law (D3a). Applied to 283 laws
  offline (NAS backup first): note-sourced row labels 21,276 → 14,709, 0 errors, no enrichment dropped.

decisions:
  - what: "Purpose is high-quality provision labels; note enrichment (note-level fact columns) parked"
    why: "Jason: 'We're not labelling Notes. We might use Notes to help label provisions.' — the first framing filled facts for notes"
    result: "decisions restated for rows and re-measured at row level; LR-00 meta and memory record the parking"
  - what: "D1 — a row takes, for an unjoined legacy note on it, the effect on its provision by the law the note cites, of its kind, held by no other note"
    why: "legacy notes (bare CommentaryRef, no change element) had no join; the note is only the pointer, the fact comes from the effect"
    result: "6,328 rows keep their label but now from an effect; 144 gain one"
  - what: "D2 — an orphan change id never takes an effect owned by other markup or another note, and only one by the law its note cites"
    why: "1,095 wrong picks came from with_orphans taking 'the one effect of its kind on the provision' (1968/47 s.1(1); 1991/56 blanket M_F_ note collected 20 effects)"
    result: "1,569 rows lost a changed_by whose law has no effect on them; statuses and territory corrected in 69 laws"
  - what: "D3 option a — a row's label is its latest dated effect; with none dated, a changed_by only when one law made the undated changes"
    why: "the old fallback took the first law by name among several undated — arbitrary"
    result: "1,246 rows have no label instead of an arbitrary law"

metrics:
  missed_joins_notes: { exact_provision: 6883, ancestor: 913, descendant: 201, elsewhere_by_law: 2321, no_effect_by_law: 5943 }
  wrong_picks_notes: { total: 1719, orphan_join_fault: 1095, feed_as_substituted: 601, latest_of_several: 12, other: 11 }
  corpus_diff: { field_diffs: 55997, laws: 283, rows_touched: 15192, row_laws: 244, from_note_to_effect: 6328, other_law_or_date: 2952, d3a_undated_none: 1246, emptied: 340, gained: 144, effect_to_note: 80, status_changes: 81, territory_laws: 69 }
  wave: { laws: 283, rows: 210362, errors: 0, renamed: 0, dropped: 0, ambiguous: 0, orphaned_mappings: 0, enriched_before: 169750, enriched_after: 169729, text_changed_enriched: 21 }
  row_labels_after: { from_effects: 224417, from_notes: 14709, from_notes_before: 21276 }

lessons:
  - title: "Frame data-quality work on the thing customers see — provision labels — not on notes"
    detail: "I measured and proposed note-level facts (a note's changed_by) until Jason corrected it. Re-measured by row, D1's value was ~2,000 labels, not the ~10,000 notes the note view suggested: a row's label is its latest dated change and pointed effects are usually older or undated."
    tag: data
  - title: "A simulation that drops all notes overstates the loss: note placement legitimately carries joined effects"
    detail: "The first row simulation passed notes=[] and showed thousands of effect-labelled rows going empty. Notes joined to effects (by markup or own id) must stay as carriers with their text facts blanked; only unjoined notes' text is removed."
    tag: tooling
  - title: "Orphan joins need ownership and the cited law, or one blanket note spreads facts across an Act"
    detail: "with_orphans picked 'the one applied effect of the kind on the provision' with no check that the effect had its own markup/note or was by the cited law. One M_F_ blanket note in 1991/56 joined 20 effects and gave every row it marks 2025 by 2024/13. Both checks are cheap: held ids and Commentary Citation URIs are in the document."
    tag: data
  - title: "Validate a corpus diff against the feed, then sample the residue by hand"
    detail: "Checking 'does the old/new law have an effect on the row?' split 4,374 changed_by changes; the suspicious 443 turned out to be the checker counting Act-wide effects ('power to amend conferred | Act') and more wrong joins removed. Hand-sampling with fetch_changes + the baseline .etf (term_to_binary compressed, not gzip) settled each class."
    tag: tooling

bugs:
  - pattern: "A note's changed_by comes from the latest-dated effect joined to it, not the law the note itself cites (its Citation): later changes to the same words replace the note's own amender"
    category: lat-change-facts
    module: "scraper/change_facts.ex (note/3, changed_by = last.affecting)"
    affected: 1716 notes / 176 laws
    fix: "D1/D3 (Jason 2026-10-12): rows labelled from effects; the 601 keep the feed's affecting law; the rest were the orphan-join fault (D2)"
    status: fixed
  - pattern: "Orphan join takes an effect that has its own note and markup, by a law other than the one the change's note cites (legacy d30p ids)"
    category: lat-change-facts
    module: "scraper/effect_index.ex (with_orphans/2, on_provision/3)"
    affected: 1095 notes
    fix: "EffectIndex.with_orphans/3 held: / cited: (D2), applied in the lr19 wave"
    status: fixed
  - pattern: "Legacy notes (bare CommentaryRef, no change element) never join the effect on their provision by the law they cite"
    category: lat-change-facts
    module: "scraper/commentary_parser.ex (with_effects/3)"
    affected: ~10000 notes
    fix: "CommentaryParser.with_effects/3 pointer join (D1), applied in the lr19 wave"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/effect_index.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/effects.ex
  - backend/lib/sertantai_legal/scraper/commentary_parser.ex
  - backend/lib/sertantai_legal/scraper/amendment_note.ex
  - backend/lib/sertantai_legal/scraper/lat_staged_parser.ex
  - backend/lib/sertantai_legal/scraper/staged_parser.ex
  - backend/lib/sertantai_legal/scraper/CLAUDE.md
  - backend/test/sertantai_legal/scraper/effect_territory_test.exs
  - backend/test/sertantai_legal/scraper/commentary_parser_test.exs
  - backend/test/sertantai_legal/scraper/amendment_note_test.exs
  - backend/data/reports/lat-refactor/lr19-snapshot.compare.csv
  - backend/data/reports/lat-reparse/lr19_preview.csv
  - backend/data/reports/lat-reparse/lr19.csv
  - backend/data/reports/lat-reparse/lr19_wave_laws.txt

depends_on:
  - 2026-10-12-lr-20-no-facts-from-notes
  - 2026-10-09-lr-07-change-metadata-from-effects

enables:
  - "LR-08 amending law as a source (A3)"
  - "LR-21 note fallback removal (A4): 14,709 note-sourced labels left"
  - "LH-05: LR-19 label changes and 21 rows to re-enrich recorded there"
---

# Session: LR-19 Effect Joins (CLOSED)

## Problem

Found in LR-15 (2026-10-12). 2,849 notes in 206 laws have a `changed_by` different from the law the note itself cites (`citation_law`, from its `<Citation>` markup). 1,133 are the expected Welsh SI twins (uksi URI, wsi law). **1,716 notes in 176 laws** name a different law: when a note joins effects, `ChangeFacts.note/3` takes `changed_by` from the latest-dated joined effect (`last.affecting`); `citation_law` is used only when no effect joins. Examples: 1981/69 "Words substituted by Local Government Act 1985 (c. 51)" → changed_by 2006/16; eur 2008/1272 Art. 49(3) "inserted by S.I. 2019/720" → 2020/1567; 2015/310 reg.6 "substituted (N.I.) by S.I. 2019/583" → 2020/1616.

Widened 2026-10-12 (architecture track): every fact a row or note gets must come from the right effect. Two join faults: the wrong effect chosen (above), and an effect that exists but isn't joined (LR-15: 1995/21 "by 2002/794" — the feed has the effect by 2002/794 on s.15(6)(a); the row has it, the note doesn't). LR-20's inventory sizes the second.

## Todo

- ✅ Missed joins measured (2026-10-12, offline; `lr19_joins` script in scratchpad) — see Missed joins
- ✅ The 1,716 classified (2026-10-12; `lr19_wrong`) — see Wrong picks
- ✅ Checked against LR-05 (citation_law precedence: only where no effect joins) and the rule (LR-20: effects over notes; the note names where to look)
- ✅ Re-measured at row level (Jason: rows are labelled, not notes) — see Rows
- ✅ Jason decided D1, D2, D3a (2026-10-12)
- ✅ Tests first, then build (2026-10-12): 4 new tests red → green; full suite 2,623 passed — see Build
- ✅ Classified diff of the offline whole-corpus parse (2026-10-12, `mix lat.parse_snapshot` baseline on the pre-change code → `--compare`) — see Diff
- ✅ Re-parse dry run (2026-10-12, `mix lat.reparse --laws <283> --store only --dry-run --tag lr19_preview`, `lat-reparse/lr19_preview.csv`, law list `lr19_wave_laws.txt`): 0 errors, 0 gate failures; enriched 169,750: carried 169,729, changed 21 (territory brackets in text: eur 2016/2031 5, 1968/73 8, 1990/43 3, 1984/55 2, 1982/16, 2010/15, uksi 2010/2214), dropped 0, ambiguous 0; no renames, row counts unchanged
- ✅ Jason approved ("Go", 2026-10-12) → NAS backup (snapshots/latest) → applied (`mix lat.reparse --laws <283> --store only --tag lr19`, `lat-reparse/lr19.csv`): 0 errors; rows 210,362 → 210,362; renamed 0, dropped 0, ambiguous 0, orphaned mappings 0; enriched 169,750 → 169,729 (the 21 rows whose territory brackets changed await fractalaw re-enrichment); `mix lat.status` dry run: 0 to update. LAT 374,866 rows / 1,066 laws; labelled rows from effects 224,417, from notes 14,709 (was 21,276)

## Dependencies

- ✅ LR-07, LR-05 closed

## Missed joins (2026-10-12)

16,261 notes have note-sourced facts and name a law (by Citation URI or "S.I. y/n" / "y c. n" after " by "). Against the feed's effects by that law:

| Match to the provision the note sits on | Notes | |
|---|---|---|
| exact provision | 6,883 | F 4,230, C 2,300, I 353 |
| effect on an ancestor (s.5 for a note on s.5(2)) | 913 | |
| effect on a descendant | 201 | |
| an effect by that law, elsewhere | 2,321 | mostly ranges ("Ss. 1-59 applied") the rough matcher doesn't expand; EffectIndex does |
| no effect by that law | 5,943 | LR-08 / empty |

Exact matches: one candidate of the note's kind 5,268; 2+ candidates 1,479; none of its kind 136. Undated effects (no dated InForce): 3,131 — the join gives changed_by but no date (the note's own dates are LR-21's fallback #3).

**Why they didn't join**: legacy notes (ids `c1981…`). The markup is a bare `<CommentaryRef>` beside dots or the words, with no change element or ChangeId (1991/56 s.98(5): "Words in s. 98(5) repealed by Water Act 2003" — the feed has the effect by 2003/37 on s. 98(5), "words repealed", 28.5.2004). Joins come only from change markup (`note_effects`) or a note id equal to an effect id (`CommentaryParser.with_effects/3`); rows also take effects naming their provision, notes don't.

## Wrong picks (2026-10-12)

1,719 notes joined effects and have changed_by ≠ their Citation's law (Welsh twins excluded):

| Class | Notes | Cause |
|---|---|---|
| The note's own effect, by another law | 601 | the feed's affecting law amended the cited amender before it came into force: eur 2012/649 Art. 14(6), effect by 2020/1567, type "words inserted by S.I. 2019/720 … (as substituted)". Effect data; no join fault |
| An effect by another law, joined through markup | 1,095 | **orphan join fault**: a legacy change id (`d30p67`) joins no effect, so `EffectIndex.with_orphans/2` takes "the one applied effect on the provision of the right kind" — one with its own note and markup (1968/47 s.1(1): a 2002 substitution joined asp 2003/3's insertion, `key-8ac6…`). Of 986 legacy-coded: 673 took another note's own effect, 248 an effect another note also holds, 65 neither |
| The cited law's effect and others, latest wins | 12 | the note's change markup carries two effects (2001/1701 reg. 18(a): 2025/407 and 2025/1073) |
| Other | 11 | multi-provision notes |

## Reframe (Jason, 2026-10-12)

"We're not labelling Notes. We might use Notes to help label provisions." The subject is the **row**: its effective_from, changed_by, status and territory come from the effects on it. A note is at most a pointer to which effect belongs to the row (its placement + the law it cites). The note-level counts above size the problem; the decisions are about rows, re-measured at row level (LR-20: 21,276 rows with note-sourced change facts, 13,019 with an effect naming them). Jason: "What our purpose is, is high quality provision labels." Note enrichment (the note-level fact columns on `amendment_annotations`) is **parked** — it may have value, a separate question; this session neither fills nor drops it.

## Rows (2026-10-12, offline simulation; `lr19_rows` script in scratchpad)

Each row's effective_from / changed_by recomputed with `ChangeFacts.resolve` from effects alone (notes carry only their joined effects, via their placement; no note text, no Citation), then with D1's pointer joins. Against what the row holds now:

| Row now | Rows | Effects only | + D1 pointer join |
|---|---|---|---|
| from effects | 219,292 | 219,141 unchanged; 151 a different law (the note's date was deciding: nisi 2003/419 reg.53(2)(a) 2009 by nisr 2009/35 → 2005 by nisr 2005/31) | same |
| from notes | 21,276 | same 3,788 · law kept, no date 2,734 · other law, no date 1,948 · other dated law 862 · same law, other date 66 · **empty 11,757** | +682 back to today's value from an effect · +1,274 a law with no date · **empty 11,075** |
| none | 134,298 | unchanged | unchanged |

Reading:
- D1 joins pointed effects to 9,545 rows, but changes the label on ~2,000: a row's label is its latest dated change, and the pointed effect is usually older or undated.
- 862 "other dated law": the note shows a later change (asp 2016/2 s.2(7): 2024 by asp 2024/5) that the feed doesn't date; the label falls back to an older effect. LR-08 / known limit.
- Undated: 10,279 rows end with a changed_by and no date. When several undated effects apply, `AmendmentNote.row_effective/1` picks the first by law name — arbitrary.
- 11,075 rows end empty: LR-08 (class b), else empty.
- D2 (orphan join) can't be simulated without the code; it shows in the build's diff (territory and the effect a legacy change carries).

## Decisions for Jason (rows)

**Decided 2026-10-12:** D1 approved, D2 approved, D3 option (a).


- **D1 — A row takes the effects on its provision** (as now: change markup, whole-provision effects, effects naming it) **and, for words-level effects that join only through markup, the effect a note on the row points at**: by the law the note cites, on the row's provision, of the note's kind, not another row's. Recommended.
- **D2 — Fix the orphan join** (`EffectIndex.with_orphans/2`): a legacy change id never takes an effect that has its own note or markup; where its note cites a law, only an effect by that law; else none. Rows stop taking other changes' effects (changed_by, territory). Recommended.
- **D3 — A row's changed_by / effective_from**: from its latest dated effect (the feed's affecting law, e.g. 2020/1567 "as substituted"). With no dated effect: (a) one undated effect → its law, no date; several → empty (recommended: one is unambiguous, "first by name" isn't) — or (b) empty — or (c) as now (first by law name).

## Build (2026-10-12)

- **D2** `EffectIndex.with_orphans/3` (`held:`, `cited:`) and `on_provision/4` (a keep predicate): an orphan change id never takes an effect joined by its own markup or with its own note, and with a cited law only that law's effect. `LatParser.Effects.index/3` collects both from the document (`CommentaryParser.cited_laws/1`: Commentary id → its Citation's law).
- **D1** `CommentaryParser.with_effects/3` takes the law's effects (was their ids): a note neither markup nor its own id joins takes the effects on its rows' provisions (`EffectIndex.on/2`: refs and ranges) by the law it cites (Citation, else the instrument after " by "), of its kind (F amendment verbs, C "other", I commenced), held by no other note. Callers pass effects; `LatStagedParser.effect_ids/1` removed.
- **D3a** `AmendmentNote.row_effective/1`: with no dated change, the law only when one law made the undated changes; several → none.
- Tests: `effect_territory_test` (orphan held / cited / Welsh twin), `commentary_parser_test` (pointer join: Citation, text pointer, held, no law, sub-provision only; several → all), `amendment_note_test` (undated one law / two laws).

## Diff (2026-10-12)

`data/reports/lat-refactor/lr19-snapshot.compare.csv`: 55,997 field differences in 283 laws; rows in 244 laws, 15,192 rows touched (the rest are note-level fields: parked).

| Row change | Rows | Reading |
|---|---|---|
| same label, now from an effect (was note) | 6,328 | D1: the pointed effect supplies today's value |
| same label, now from a note (was effect) | 80 | a wrong effect join removed (D2); the note-text fallback stands until LR-21 |
| other law and/or date | 2,952 | mostly wrong joins removed (below) |
| no label: several laws, none dated (D3a) | 1,246 | as decided |
| label emptied | 340 | a leak removed (2017/1013 reg.38(14)(a): a words change in (14)'s own text no longer dates (a)) |
| gains a label | 144 | D1 |
| status only | 147 | |

changed_by checked against the feed (does the law have an effect on the row's provision?), 4,374 rows: 1,569 where the old law had none (leaks fixed); 1,190 both have one; 620 old law had one, new empty (mostly D3a); 552 neither; 443 old had one, new hasn't — sampled: Act-wide effects ("power to amend conferred | Act") counted by the checker, and wrong joins removed.

Wrong joins removed (D2), examples:
- 1991/56: a blanket note "Words in Act substituted by virtue of Water Act 2003" (an `M_F_` change id) collected 20 effects across the Act; every row it marks took the latest (2025 by 2024/13, which has no effect on s.12I(1)). Now only Water Act 2003's.
- 1968/73 s.116(6)(c)[S]: Roads (Scotland) Act 1984 insertions (legacy ids) took 2003/1615's modification.
- 1990/43 s.6(6A): a 2000 insertion took ssi 2012/360's substitution and its savings → `repealed_saved`; now `in_force`.

Status: in_force_partial → in_force 36, in_force → in_force_partial 23, repealed_saved → in_force 21, in_force → repealed_saved 1. Territory (69 laws): excluded_extent set 368, cleared 34, changed 38; 190 rows' text brackets (mwa 2010/8 s.9(3): an insertion by Welsh SI 2019/414 now joins that law's effect and is marked W; before, ambiguous → unmarked).

