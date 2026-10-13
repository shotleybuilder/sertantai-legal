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
- ⬜ Markup collector: change markup no effect explains (source `markup`)
- ✅ Ash resource `SertantaiLegal.Legal.LatChangeLog` + Ash-generated migration (`20261013090525_add_lat_change_log`, migrated; table empty)
- ⬜ `mix lat.collect_changes --laws|--all [--dry-run]`: counts by source and via, unresolved list
- ⬜ Dry run on all LAT laws → Jason → fill (DB write)
- ⬜ Gemini acceptance

## Decisions for Jason

- **D1 — Record shape** (see Record shape)

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
