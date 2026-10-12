---
session: 'LR-20: Note-Fact Inventory & Rule'
status: closed
opened: 2026-10-12
closed: 2026-10-12
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  Read-only inventory and measurement of LAT's reliance on note text: 14 code paths derive facts from notes, and
  24,750 notes / 21,276 rows hold note-sourced facts — about half are join faults (the effect exists), 1,828 notes
  can come from amending laws in the store, 12,604 have no data behind them. Jason approved the rule (no fact from
  note text, ever; empty where nothing supports it), the amending-law route now (LR-08), and empty for amending
  laws not held in v0.1 (#179 for compliance v0.2).

decisions:
  - what: The rule — facts come from markup, effects or the amending law; a note is shown as a note and may only point; no fallback to note text for any field; provenance never `note` (D1)
    why: "Jason's 2026-10-09 decision ('notes aren't law') was never delivered: LR-07 kept a note fallback that was never put to him"
    result: "rule written for LR-11 / LR-12; delivered in LR-19, LR-08, LR-21"
  - what: Build the amending-law route now (LR-08), before removing the fallbacks (D2)
    why: "1,828 notes (class b) have no effect but their amending law is in the store; doing LR-08 first means LR-21 empties only facts with no data"
    result: "LR-08 scoped: class b + laws' own commencement"
  - what: Amending laws not in the store (class c2) stay empty for v0.1; a bounded fetch is raised for compliance v0.2 (D3)
    why: "4,115 notes / 253 laws; legal scopes EHS and HR laws and must not walk the amendment tree widely"
    result: "#179: one hop, amending provision only, prioritised by use, capped"

metrics:
  inventory: { note_fact_paths: 14, mislabelled_provenance: 3, no_provenance: 3 }
  notes_with_note_facts: { total: 24750, a1_effect_on_provision: 7970, a2_effect_other_provision: 2348, b_amending_law_in_store: 1828, c1_no_law_named: 8489, c2_law_not_in_store: 4115 }
  rows_with_note_change_facts: { total: 21276, effect_names_row: 13019, no_effect: 8257 }
  laws_without_feed_in_store: 0

lessons:
  - title: Provenance columns can understate a dependency
    detail: "Three paths label note-derived values as effect or markup (changed_by when affecting is nil, the effect kind from the note's Type letter, '[Repealed]' from CommentaryRef presence) and three record nothing (change-log cause, renumbering renames, the manifest's amended flag). Counting provenance = note gave 21,276 rows; the real reliance is larger. Inventory the code, not only the labels."
    tag: data
  - title: Most note reliance was a join fault, not missing data
    detail: "For 10,318 of 24,750 note-sourced notes and 13,019 of 21,276 rows, an effect by the law the note names already sits in the changes feed. The fallback hid join failures: when a fallback exists, a missed join looks like success."
    tag: data

bugs:
  - pattern: "LAT facts derived from legislation.gov.uk note text alone where no markup or effect supports them (AmendmentNote / LatStatus fallback kept by LR-07 against the 2026-10-09 decision)"
    category: lat-change-facts
    module: "scraper/change_facts.ex, amendment_note.ex, lat_status (note fallback), commentary_parser citation_law"
    affected: "21,276 rows / 302 laws (change facts), 525 rows (status), 24,750 notes (facts)"
    fix: "a fact comes from markup, effects or the law; a note-only change stays a note (text shown, no derived fact)"
    status: open
  - pattern: "Row change facts pool note facts with effect facts and take the latest date, so a note can override an effect on the same row"
    category: lat-change-facts
    module: "scraper/change_facts.ex (row_facts/5, AmendmentNote.row_effective/1)"
    affected: "rows with both notes and effects (unmeasured)"
    fix: "row facts from effects (and the amending law) only — LR-21"
    status: open
  - pattern: "Provenance mislabelled or missing for note-derived values: changed_by when affecting is nil and the effect kind from the note Type labelled effect; '[Repealed]' from CommentaryRef presence labelled markup; change-log cause, renumbering renames and the manifest amended flag record none"
    category: lat-provenance
    module: "change_facts.ex note/3 + kind/2, lat_parser/rows.ex mark_repealed/2, lat_change_log.ex, lat_cause/apply.ex, lat_hash/query.ex"
    affected: "6 paths"
    fix: "remove or re-source in LR-21; provenance only markup / effect / law"
    status: open

artifacts:
  - .claude/sessions/lat-refactor/2026-10-12-lr-20-no-facts-from-notes.md (inventory, measurement, rule)
  - .claude/sessions/lat-refactor/2026-10-12-lr-08-amending-law-source.md (scoped)
  - 'GitHub #179 (bounded fetch of amending laws not held, compliance v0.2)'

depends_on:
  - 2026-10-09-lr-07-change-metadata-from-effects

enables:
  - LR-19 effect joins (classes a1, a2; 13,019 rows)
  - LR-08 the amending law as a source (class b)
  - LR-21 note fallback removal
---

# Session: LR-20 Note-Fact Inventory & Rule (CLOSED)

## Problem

Jason decided on 2026-10-09: notes aren't law; facts come from the law → the revised text's change markup → effects; a note showing a change the effects layer lacks is kept as a note, or checked against the law it was built from. LR-07 kept a note-text fallback instead (see LR-00 meta, "Why the notes decision was not delivered"). Today 21,276 rows in 302 laws hold change facts from note text alone, 525 rows a status, and 24,750 notes their own facts.

## Todo

- ✅ Inventory (2026-10-12, Explore agent; claims #4, #9, #13 checked in code): 14 paths derive a stored fact or served value from note text or note attributes — see Inventory
- ✅ Measure (2026-10-12, offline, store only; `lr20` script in scratchpad): 24,750 notes and 21,276 rows with note-sourced facts, classed — see Measurement
- ✅ Feed coverage: every LAT law has a changes feed in the store (0 without); the gaps are effects missing for older changes (e.g. 1954/70's 1993 SIs), measured as classes b / c2
- ✅ The rule, written down (see The rule) for the guide (LR-11) and QA spec (LR-12)
- ✅ Jason decided D1, D2, D3 (2026-10-12)

## Inventory (2026-10-12)

All writes run through `LatStatus.Apply.refresh/2`, called on every parse (`CommentaryPersister`) and by `mix lat.status` / `lat.place_notes` / `lat.reorder_notes`. Not note-derived: EffectTerritory, InForceQualifier (the feed's qualification), LatTerritory, LatParser.Effects; NoteTerritory only feeds a report.

| # | Path | From the note | Produces | Role | Provenance written |
|---|---|---|---|---|---|
| 1 | `AmendmentNote.parse/3` | verb, d.m.yyyy dates, citation after " by ", "(Wales)" titles | note effect / dates / changed_by | parser behind every fallback | — |
| 2 | `ChangeFacts.note/3` (no effect joined) | #1 | note effect, dates, changed_by | fallback | `facts: note` |
| 3 | `ChangeFacts.note/3` (effects undated) | note dates | note dates | fallback | `dates: note` |
| 4 | `ChangeFacts.note/3` (`affecting` nil) | note changed_by | note changed_by | fallback | **`facts: effect` (wrong)** |
| 5 | `ChangeFacts.kind/2` | the note's Type letter (C/I) | note effect "commenced"/"modified" | overrides the effect's Type | **`facts: effect` (wrong)** |
| 6 | `ChangeFacts.changed_by/3` | the note's `<Citation>` URI (`citation_law`) | note changed_by | when no effect joins | follows #2/#4 |
| 7 | `ChangeFacts.marginal/2` | note code "M…" | clears changed_by / dates | on the note fact | — |
| 8 | `LatStatus.Apply.known_laws/2` | changed_by from note text | the register set behind the wsi/uksi choice | supports #6 | — |
| 9 | `ChangeFacts.row_facts/5` | the facts of the row's and ancestors' notes | **row effective_from / changed_by** | **pooled with effects; the latest date wins** — a note can override an effect | `change: note` only when the winner is a note; note dates (#3) show as effect |
| 10 | `LatStatus.resolve/2`, `status/2` | "for specified purposes", "wholly in force", "savings", "S. n" | **row status** in_force_partial / repealed_saved | fallback when no repeal/commencement effect decides; spreads to descendants and versions | `status: note` |
| 11 | `LatCause.Apply` → `LatChangeLog.entries/2` | note change_ids, targets | `lat_changes.cause` legislative / unattributed | primary | none |
| 12 | `LatChangeLog.renumber_pair/2` | "S. 23 renumbered as s. 24" | `lat_changes` renamed rows, `lat_section_id_renames` (match `renumbered`) | primary | none |
| 13 | `Rows.mark_repealed/2` | that an empty row has CommentaryRefs | row text "[Repealed]" → status repealed | primary | **`status: markup` (wrong)** |
| 14 | `LatHash.Query` | whether any amendment note exists | manifest `amended` flag (served to fractalaw) | primary | none |

Acceptable (pointers / identity, not facts): CommentaryRef placement (`affected_sections`), effect joins by `key-` id and ChangeId, `change_id` (a hash of the note text, an identity), CommentaryRef counts per row (`amendment_count` …), NoteTerritory in the territory check report.

So the provenance columns undercount: #4, #5, #13 and note dates at row level are labelled `effect` or `markup`; #11, #12, #14 record nothing.

## Measurement (2026-10-12)

Notes whose facts come from their own text (`fact_provenance.facts = note`), by what data exists. "Pointed-to law": the law the note names after " by " (its Citation, or "S.I. YYYY/N", "YYYY c. N").

| Class | Notes | Laws | By type | Where the fact can come from |
|---|---|---|---|---|
| a1 — an effect by the pointed-to law names the note's provision | 7,970 | 273 | amendment 5,157, modification 2,425, commencement 384 | **effects** — a join fault (LR-19) |
| a2 — an effect by the pointed-to law exists, on another or an unstructured provision | 2,348 | 172 | amendment 1,345, modification 854 | **effects**, with a wider join (LR-19) |
| b — no effect; the pointed-to law is in the CLML store | 1,828 | 183 | amendment 1,080, extent_editorial 408, modification 339 | **the amending law** (LR-08) |
| c1 — the note names no law | 8,489 | 396 | extent_editorial 5,806, commencement 2,232 | editorial notes and self-commencement ("in force at …, see s. 70"); not changes by another law: **empty** (a law's own commencement: from the law, LR-08) |
| c2 — no effect; the pointed-to law isn't in the store | 4,115 | 253 | amendment 2,172, modification 1,103, extent_editorial 772 | **empty** (or the amending law fetched; outside the store) |

Rows whose change facts (effective_from / changed_by) come from notes (`change_provenance.change = note`): 21,276. **13,019 have an effect in the feed naming the row or its provision** (effects can supply them: LR-19); **8,257 have none** (LR-08 or empty).

Reading: about half the note-derived facts (10,318 notes a1+a2; 13,019 rows) are join faults — the data is in the effects and the code took the note instead. 1,828 notes can come from the amending law in the store. The rest (12,604 notes: c1 + c2; up to 8,257 rows) have no data behind them and become empty.

## The rule (draft for the guide)

1. A fact (status, effective dates, changed_by, effect kind, territory) comes from the law's markup, the changes feed's effects, or the amending law's own text — in that order.
2. A note is shown as a note. It may point to where to look (its CommentaryRef placement; its `key-` id or the law it names as a join hint to an effect or an amending law), and the value then comes from what it pointed to.
3. No fallback to note text for any field. Where nothing supports a fact, it is empty.
4. Provenance names the source of every fact: `markup`, `effect` or `law`. `note` never appears.

## Decisions for Jason

**Decided 2026-10-12:** D1 the rule — approved. D2 the amending-law route now (LR-08) — approved. D3 class c2 — empty for v0.1; a bounded fetch of amending laws legal doesn't hold raised for compliance v0.2 as #179 (one hop, the amending provision only, prioritised by use, capped).


- **D1 — The rule** above (a fact no markup, effect or law supports is empty; the note is kept and shown as a note)
- **D2 — The amending-law route (LR-08) now**, for class b (1,828 notes) and the law's own commencement (part of c1) — recommended, so the removal (LR-21) empties only what has no data — or later
- **D3 — Notes in class c2** (4,115: the named law isn't in the store): empty (recommended: the store holds what legal scopes), or fetch those amending laws

## Dependencies

- ✅ LR-07, LR-05 closed
- LR-15 and LR-19 follow this rule
