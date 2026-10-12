---
session: 'LR-13: Identity & Note Fixes, Targeted Wave'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-13 Identity & Note Fixes, Targeted Wave (PENDING)

## Problem

Plan step 1b (LR-00 meta). LR-10 found fixable defects in the wave-4 data. The largest: 1,307 rows / 123 laws carry `#position` section_ids, mostly parser identity gaps (per-Part chapters without the Part, nested lists losing a level, territorial versions with no qualifier, mixed types sharing an id). The id changes whenever an earlier row changes, and fractalaw keys enrichment on it. Scope is whatever Jason approves in LR-10 D1.

## Todo

- ⬜ Scope = LR-10 D1 as approved
- ⬜ No schedules (LR-10 D3 b, Jason 2026-10-12), test-first: `Walker` skips `Schedule` elements (incl. PDF-transcript CLML, 1979/791); narrow the 12 enabling scopes to their sections (`LatScope.narrow!/3`, history entry); remove the 4,646 schedule rows and the 978 schedule-only notes in the wave (dry run → Jason)
- ⬜ Classify all 525 duplicate groups (Part-scoped chapter, lost list level, missing version qualifier, mixed type, true source duplicate); fixtures per class, red first
- ⬜ Fix ids in `Ids` / `Rows`; `#position` only for true source duplicates; check sort_key sub-segments (2016/1105 reg.49 repeats `.002`)
- ⬜ changed_by from bare SI numbers the register holds (22 notes / 3 laws), test-first
- ⬜ parse_snapshot classified diff: only the expected id renames / changed_by fields, 0 unexpected
- ⬜ Delete the 32 notes on laws without LAT: dry run → Jason → apply
- ⬜ Targeted wave (affected laws only, `--store only`): dry run → Jason → apply → verify (lat.status 0, text/change diff 0); rename list for LH-05

## Decisions for Jason

- **D1 — Rename approach**: ids that change get LatMerge's rename carry (enrichment kept) and a rename list for fractalaw — or freeze current ids and accept `#position` as a known limit
- **D2 — Note deletion**: approve the dry-run list of 32 notes
- **D3 — Wave**: approve the targeted wave from its dry run

## Dependencies

- ⬜ LR-10 D1 approved
