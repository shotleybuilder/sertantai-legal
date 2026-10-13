---
session: 'LR-23: Change Log Table & Feed Collector'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-23 Change Log Table & Feed Collector (ACTIVE)

## Problem

LR-22 (design approved 2026-10-13) needs its register: the `lat_change_log` table, filled from the sources we already hold, the changes feed and our CLML change markup. Today the joins between effects and rows are made inside the LAT parse, and only the flattened result survives: `legal_articles.effect_ids`, plus the notes' `effect_ids`. Nothing records how an effect reached a row, or which effects reached no row. This session builds the table and the collectors that record each change with its target rows and how each was joined. Nothing reads the table yet; labels switch over in LR-24 and LR-25.

## Todo

- ⬜ Record shape: one row per change × target row (`via`), unresolved changes kept with no row (D1)
- ⬜ Tests first: pure feed collector (joins by markup, whole provision, ref, note pointer; unresolved effect; no fact from note text)
- ⬜ Walker emits each row's joins with their kind (`effect_joins`), not only the flat `effect_ids`
- ⬜ `ChangeCollector.Feed` (pure) and `ChangeCollector` (orchestrator, store only)
- ⬜ Markup collector: change markup no effect explains (source `markup`)
- ⬜ Ash resource `SertantaiLegal.Legal.LatChangeLog` + Ash-generated migration
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
