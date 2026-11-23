---
session: 'Commencement reader: staleness that follows what changed'
status: active
opened: 2026-11-23
---

# Session: Commencement reader: staleness that follows what changed (ACTIVE)

## Problem

One version stamp (`Commencement.ReadVersion`, 63 files) covers the whole reader, so any fix stales all 72,043 stored rules, and usually every build (`ChangeVocabulary.Version`, 54 files shared) and every extent reading (`Extent.ReadVersion`) too. `Store.write` deletes and re-inserts, so even an identical re-read moves `read_at` and stales every build that reads those rules, in any family. In Waste, Water and Climate two late fixes cost a round re-read and rebuild of about an hour (1,088 laws). Retrospective Decision 1 (a). Spec: `docs/lat-change-pipeline/COMMENCEMENT-READER.md` §5.

## Todo

Plan approved 2026-11-23 (`~/.claude/plans/gleaming-doodling-matsumoto.md`). Pass rule: a re-read with unchanged code writes no rule and stales no build (after the cycle: a second re-read writes 0, commencement reasons 0); three read stamps (clause, orders, effects) test-held to exactly their paths' reach; `order.ex` and `order/*` outside the build's and the extent reader's stamps; round checks, yardstick, switched families and golden as at the close; suite and Dialyzer green, no new Credo issue; feed owners written only on Jason's go.

- ⬜ 1. Write only what changed: `Store.write/3` compares rows; identical → stamp only, `read_at` kept
- ⬜ 2. Three read stamps (clause, orders, effects), explicit lists, each = its path's reach (architecture test); per-group staleness
- ⬜ 3. Build and extent stamps drop the order reader: `ClmlRef.ref`, `RefContext`, `LawStart.Sentences`; `Extent.ReadVersion` explicit
- ⬜ 4. Feed-difference owners: `{"status","owner"}` entries, `FeedDifferences.owner/3`, yardstick by owner; owners dry-run for Jason
- ⬜ 5. Pre-flight: targeted tests, Credo, Dialyzer; round `--preview` 0 changes; `lat.reread` dry runs for the cost
- ⬜ 6. The one-time cycle on Jason's go: restore point; store-wide re-read; rebuild of every built law
- ⬜ 7. Check: second re-read writes 0; stale reasons 0; round checks, yardstick, switched, golden as at close; suite
- ⬜ 8. Close: DATA-ARCHITECTURE row; RULES rule; session close; commits by path

## Dependencies

- ✅ Commencement reader: step procedures, feed figures and workflow rules closed
