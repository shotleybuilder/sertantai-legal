---
session: 'LR-23: Change Log Table & Feed Collector'
status: active
opened: 2026-10-13
bugs:
  - pattern: "A note's joined effects spread to every row the note sits on: a pointer (cited-law) join pairs every effect found with every placement row; a markup join reaches rows whose text doesn't carry the change"
    category: label-join
    module: ChangeFacts.row_facts (note placement) / ChangeCollector.Feed
    affected: "1990/43 Pt. 2A note: 692 rows × 24 effects; 1991/56 blanket M_F_ note: 560 rows × 15 effects (rows with the change markup: 684)"
    fix: "Collector records the real pair: cited → the provision the effect was found on; markup → only rows whose own markup carries the change; own (commencement/modification) → the note's placement. Labels move in LR-24/25"
    status: open
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-23 Change Log Table & Feed Collector (ACTIVE)

## Problem

LR-22 (design approved 2026-10-13) needs its register: the `lat_change_log` table, filled from the sources we already hold, the changes feed and our CLML change markup. Today the joins between effects and rows are made inside the LAT parse, and only the flattened result survives: `legal_articles.effect_ids`, plus the notes' `effect_ids`. Nothing records how an effect reached a row, or which effects reached no row. This session builds the table and the collectors that record each change with its target rows and how each was joined. Nothing reads the table yet; labels switch over in LR-24 and LR-25.

## Todo

- ✅ Record shape: one row per change × target row (`via`), unresolved changes kept with no row (D1, built; Jason to confirm)
- ✅ Tests first: pure feed collector (joins by markup, whole provision, ref, note pointer; unresolved effect; no fact from note text)
- ✅ Walker emits each row's joins with their kind (`effect_joins`), not only the flat `effect_ids`
- ✅ `ChangeCollector.Feed` (pure) and `ChangeCollector` (orchestrator, store only)
- ✅ Markup collector: change markup no effect explains (source `markup`)
- ✅ Ash resource `SertantaiLegal.Legal.LatChangeLog` + Ash-generated migration (`20261013090525_add_lat_change_log`, migrated; table empty)
- ✅ `mix lat.collect_changes --laws|--all [--apply]`: counts by source and via, unresolved list
- ⬜ Dry run on all LAT laws ✅ → Jason → fill (DB write)
- ⬜ Gemini acceptance

## Decisions for Jason

- **D3 — Compact targets** (Jason, 2026-10-13: "Surely there is a way to architect and not create so many rows and retain the same data fidelity"): see Compact targets; D2 waits on it
- **D2 — Fill**: approve `mix lat.collect_changes --all --apply` (writes only `lat_change_log`, empty today; no other table changes)
- **D1 — Record shape** (see Record shape). Taken back to Gemini 2026-10-13 (Jason): **VERDICT: ACCEPT** (`backend/data/code-reviews/2026-10-13-lr-23-d1-record-shape.md`)

## Dependencies

- ✅ LR-22 design: D1–D4 decided; `LatChangeLog` renamed `LatParseLog`
- ✅ LR-19 effect joins (become the collector's join logic)

## Record shape (D1, proposed 2026-10-13; built this way, revisable before the fill)

**One row per change × target row**, so "row → its changes" is a single indexed query (`law_name, section_id`). A change that reaches no row is kept, with `section_id` null: a visible gap.

- **Target and join:** `section_id` (nullable), plus `via`, saying how the change reached the row:
  - `markup`: our CLML change element's ChangeId or CommentaryRef;
  - `whole`: an applied whole-provision change on a provision with no joinable markup;
  - `ref`: the effect's affected ref names the row's provision;
  - `note`: a note's placement carried the joined effect; `pointer` holds the note id.
- **The change:** `source` (effect | markup | law), `evidence` (effect id / ChangeId / law provision path), `affected_ref` as stated, `affecting_law`, `affecting_ref`, `operation` (`ChangeFacts.kind/2` vocabulary), `effect_type` (raw), `effective_from`, `in_force` (jsonb entries), `prospective`, `applied`, `savings`, `affected_extent`, `effect_extent`, `territorial_application`, `dated_by_law`, `dated_by_ref`.
- **Run metadata:** `collector`, `collected_at`.

**Gemini vs this shape.** Gemini advised against storing rows, because a stored row goes stale when a provision is renumbered. Here `section_id` is the text provision id ("UK_ukpga_1990_8:s.195(4)"), not a key. The collector rewrites a law's records after every parse of that law, so they never lag its LAT. Storing the join is the point: it records *how* each change reached the row, which labelling at query time would hide.

Ancestor inheritance is not stored. The projection (LR-24) applies it, so a change is recorded once, on the row it names.

## Build (2026-10-13)

- **Join kinds.** `Effects.row_effect_joins/4` returns `{id, :markup | :whole | :ref}`, and the walker emits `effect_joins` next to `effect_ids`, which is unchanged. `CommentaryParser.with_effects/3` gives notes `effect_joins`: `{id, :markup}`, `{id, :own}`, or `{id, :cited, section_id}`. Nothing persisted changes.
- **Modules.**
  - `ChangeCollector.Feed` (pure) and `ChangeCollector.Record` (struct).
  - `ChangeCollector` (orchestrator): parse store-only, then the collectors, then per law and collector a delete + insert in one transaction.
  - `mix lat.collect_changes --laws|--all [--apply] [--tag]`: a dry run by default; resumable report.
- **Tests:** 8 for the collector, 2 for the join kinds. Suite 2,633 pass.

**Fan-out found on the first two laws** (bug logged above). A note's joins were spreading across its whole placement:
- **1990/43:** the "Pt. 2A inserted" note sits on 692 rows; its 24 pointer (cited-law) effects made 16,608 pairs.
- **1991/56:** the blanket "Words in Act substituted … by virtue of Water Act 2003" note sits on 560 rows; its 15 markup effects made 8,400 pairs. Those effects' own markup is in 684 rows.

Rule now:
- a cited join reaches the provision its effect was found on;
- a markup join reaches only rows whose own markup carries the change;
- an own join (commencement or modification: the note sits on the provision) reaches the note's placement.

Records: 1990/43 26,530 → 9,854; 1991/56 18,630 → 9,951.

Today's labels spread the same way (`ChangeFacts.row_facts` gives every row in a note's placement the note's fact). LR-24's diff will show which labels move.

**Markup collector.** `LatTerritory.unjoined_changes/1` gives a ChangeId that joined no effect (after the orphan joins), as `{change_id, ref, operation}`; the walker emits it as `unjoined_changes`. `ChangeCollector.Markup` records it with source `markup`, the commentary ref as `pointer`, and no date or law: a change happened, and nothing here says when or by whom. Four-law trial: markup records 1990/43 1,090, 1991/56 1,111, 1974/37 212, 2017/1013 15.

**Range effects reach every provision in the range.** In 1974/37, "s. 1-59 applied by …" and "s. 1-54 (Pt. 1) amended …" each reach 786–820 rows, sub-provisions included (`EffectIndex` expands a range against the document's id order, as today's parse does). This is recorded faithfully. The projection inherits from ancestors anyway, so the duplicates don't change labels. Narrowing the expansion to the named provisions is a later choice, not this session's.

## Gemini on D1 (2026-10-13)

Jason asked Gemini to accept or push back harder. **VERDICT: ACCEPT.** Its reasons:
- the stored id is a text provision id, not a key;
- the rewrite per law after every parse keeps the table in step;
- joins that `affected_ref` can't give (markup, whole, note pointers, orphans) need storing with their kind to be traceable;
- the fan-out bug was visible only because the joins are stored.

One correction to Gemini: it calls the text ids "stable across renumberings". They aren't: a renumbered provision gets a new `section_id`. The guard is the rewrite after every parse, which is what holds the records in step.

Remaining risks and guards:
- **Collector not re-run after a parse.**
  - Guard: LR-25's parse hook runs collect + relabel after every LAT parse.
  - Until then, a staleness check: laws whose latest `lat_events` `parsed` is newer than their latest `lat_change_log.collected_at`. It goes in `mix lat.collect_changes` and the LR-25 verification.
- **Partial runs.** Already covered and stronger than Gemini assumed: `ChangeCollector.write/2` writes all of a law's collectors in one transaction, so a law's records are all new or all old.
- **Drift in the collector logic.** Unit tests per join kind, plus a full dry-run report compared against the previous one before any `--apply`.

## Dry run, all LAT laws (2026-10-13)

`backend/data/reports/lat-refactor/lr23_dry.csv` (gitignored): 1,066 laws, 0 errors.

| | Count |
|---|---|
| Records (feed) | 525,369 |
| Effects in the feed | 203,639 (856 laws; 210 laws have none) |
| Effects reaching no row | 121,978 |
| Joins by kind: `ref` / `markup` / `note_markup` / `note_own` / `whole` / `note_cited` | 272,220 / 104,515 / 104,096 / 46,379 / 17,227 / 6,971 |
| Markup records (change markup no effect explains) | 18,532 |

**Effects reaching no row.** Sample: 40 random laws plus the 3 largest, 18,731 unreached effects.

| Reason | Effects | Share |
|---|---|---|
| Outside the law's LAT scope (fragment laws) | 10,907 | 58% |
| On a Schedule (LAT holds no Schedules, LR-10) | 6,874 | 37% |
| Whole instrument ("Act", "Regulations") | 213 | 1.1% |
| Annex / appendix | 184 | 1.0% |
| Not yet applied (prospective / unapplied) | 177 | 0.9% |
| No affected ref | 74 | 0.4% |
| **Words-level, applied, no markup join** | **261** | **1.4%** |
| **Whole-provision, applied, no row** | **41** | **0.2%** |

The last two (about 1.6% of the unreached) are the real gaps: changes to provisions LAT holds that reached no row. They include "specified amended provision(s)" commencement orders, multi-number refs ("reg. 9(6)(7)", "art. 63(6)(v)(w)") and ranges of inserted subsections ("s. 20(5D)-(5F)"). They become LR-24's gap query.

**Volume.** Range modifications dominate: New Roads and Street Works Act 1991 has 73,482 records, 69,761 of them `ref` joins from Part 3-wide modifications ("s. 48-106 (Pt. 3) saved / applied / excluded") reaching about 690 rows each. Recorded faithfully, as today's parse joins them.

## Compact targets (2026-10-13)

Jason on the per-row volume (New Roads and Street Works Act 1991: 73,482 records, a Part-wide modification written on about 690 rows each): store each change once against what it covers, and expand to rows when read.

**Measured** on 44 laws (the 4 largest plus 40 random, scratchpad `lr23_compact.exs`):
- **Hierarchy:** drop a record when an ancestor carries the same change by an inheritable join (`ref`, `whole`, `note_own`, `note_cited`).
- **Ranges:** collapse a run of covered rows in document order into one record.

| | Records | Cut |
|---|---|---|
| Today's shape | 229,088 | — |
| Hierarchy compression | 58,389 | 75% |
| Plus ranges | 41,879 | 82% |

1991/22: 73,482 → 14,988 → 7,242. 1986/44: 44,177 → 6,244 → 3,768. Projected over the corpus: about 525,000 → about 96,000.

**Proposed shape:**
- **Target.** `section_id` (the provision the change covers; its top, as the source states it), `section_id_to` (the end of a contiguous range; nil otherwise), and `covers`:
  - `row`: this row only (markup joins and words-level changes: the row's own text);
  - `subtree`: the row and its descendants (`hierarchy_path` prefix).
- **Expansion.** One SQL view, `lat_change_log_rows`, joins records to `legal_articles` by `hierarchy_path` prefix and `position` range. "Row → its changes" stays a single query.
- **Fidelity gate.** Before any fill, for every law, expanding the compact records must reproduce today's per-row join set exactly: zero rows added, zero lost. A test for each covers kind, plus that corpus check.
