---
session: 'LR-19: Effect Joins'
status: active
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "A note's changed_by comes from the latest-dated effect joined to it, not the law the note itself cites (its Citation): later changes to the same words replace the note's own amender"
    category: lat-change-facts
    module: "scraper/change_facts.ex (note/3, changed_by = last.affecting)"
    affected: 1716 notes / 176 laws
    fix: "decide: the note's own Citation (citation_law) wins when present, effects only date it; or keep the latest effect"
    status: open
  - pattern: "Orphan join takes an effect that has its own note and markup, by a law other than the one the change's note cites (legacy d30p ids)"
    category: lat-change-facts
    module: "scraper/effect_index.ex (with_orphans/2, on_provision/3)"
    affected: 1095 notes
    fix: "exclude effects with their own Commentary / ChangeId; require the cited law where the note cites one"
    status: open
  - pattern: "Legacy notes (bare CommentaryRef, no change element) never join the effect on their provision by the law they cite"
    category: lat-change-facts
    module: "scraper/commentary_parser.ex (with_effects/3)"
    affected: ~10000 notes
    fix: "pointer join: effects on the note's provision, by its cited law, of its kind, not held by another note"
    status: open
---

# Session: LR-19 Effect Joins (ACTIVE)

## Problem

Found in LR-15 (2026-10-12). 2,849 notes in 206 laws have a `changed_by` different from the law the note itself cites (`citation_law`, from its `<Citation>` markup). 1,133 are the expected Welsh SI twins (uksi URI, wsi law). **1,716 notes in 176 laws** name a different law: when a note joins effects, `ChangeFacts.note/3` takes `changed_by` from the latest-dated joined effect (`last.affecting`); `citation_law` is used only when no effect joins. Examples: 1981/69 "Words substituted by Local Government Act 1985 (c. 51)" → changed_by 2006/16; eur 2008/1272 Art. 49(3) "inserted by S.I. 2019/720" → 2020/1567; 2015/310 reg.6 "substituted (N.I.) by S.I. 2019/583" → 2020/1616.

Widened 2026-10-12 (architecture track): every fact a row or note gets must come from the right effect. Two join faults: the wrong effect chosen (above), and an effect that exists but isn't joined (LR-15: 1995/21 "by 2002/794" — the feed has the effect by 2002/794 on s.15(6)(a); the row has it, the note doesn't). LR-20's inventory sizes the second.

## Todo

- ✅ Missed joins measured (2026-10-12, offline; `lr19_joins` script in scratchpad) — see Missed joins
- ✅ The 1,716 classified (2026-10-12; `lr19_wrong`) — see Wrong picks
- ✅ Checked against LR-05 (citation_law precedence: only where no effect joins) and the rule (LR-20: effects over notes; the note names where to look)
- ✅ Re-measured at row level (Jason: rows are labelled, not notes) — see Rows
- ⬜ Jason decides D1–D3 (rows)
- ⬜ Tests first (EffectIndex orphan join, CommentaryParser pointer join, ChangeFacts changed_by)
- ⬜ Build; classified diff of the offline whole-corpus parse (`--store only`)
- ⬜ Re-parse dry run → Jason → NAS backup → apply

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

- **D1 — A row takes the effects on its provision** (as now: change markup, whole-provision effects, effects naming it) **and, for words-level effects that join only through markup, the effect a note on the row points at**: by the law the note cites, on the row's provision, of the note's kind, not another row's. Recommended.
- **D2 — Fix the orphan join** (`EffectIndex.with_orphans/2`): a legacy change id never takes an effect that has its own note or markup; where its note cites a law, only an effect by that law; else none. Rows stop taking other changes' effects (changed_by, territory). Recommended.
- **D3 — A row's changed_by / effective_from**: from its latest dated effect (the feed's affecting law, e.g. 2020/1567 "as substituted"). With no dated effect: (a) one undated effect → its law, no date; several → empty (recommended: one is unambiguous, "first by name" isn't) — or (b) empty — or (c) as now (first by law name).
