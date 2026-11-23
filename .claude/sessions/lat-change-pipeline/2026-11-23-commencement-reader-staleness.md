---
session: 'Commencement reader: staleness that follows what changed'
status: pending
opened: 2026-11-23
---

# Session: Commencement reader: staleness that follows what changed (PENDING)

## Problem

One version stamp (`Commencement.ReadVersion`, 63 files) covers the whole reader, so any fix stales all 72,043 stored rules, and usually every build (`ChangeVocabulary.Version`, 54 files shared) and every extent reading (`Extent.ReadVersion`) too. `Store.write` deletes and re-inserts, so even an identical re-read moves `read_at` and stales every build that reads those rules, in any family. In Waste, Water and Climate two late fixes cost a round re-read and rebuild of about an hour (1,088 laws). Retrospective Decision 1 (a). Spec: `docs/lat-change-pipeline/COMMENCEMENT-READER.md` §5.

## Todo

- ⬜ Plan (plan mode): measure each stamp's reach; the change, test first; pass rule: a re-read with unchanged code writes nothing and stales no build
- ⬜ Rules re-written only when their content changes (as `Amendment.ReadPass` does)
- ⬜ One version per substep: own clause, orders, amending laws' clause, feed effects
- ⬜ `ChangeVocabulary.Version` and `Extent.ReadVersion` leave out the reader's modules they reach only through stored rules
- ⬜ The stamps hash whole folders (`commencement/*.ex`), and `read_version.ex` sits in the folder it hashes: a new tool module there, or an edit to the except list, stales every stored rule (found 2026-11-23 by the step-procedures session, which put its modules in `scraper/step_procedures/` for this reason). List the reader's modules, or keep tools out by rule with an architecture test
- ⬜ One round re-read; prove builds untouched where rules are identical (`mix lat.reread --family F`, `--preview`)
- ⬜ The rules stale elsewhere: 26,427 of 72,043 on 2026-11-23, among them the switched Fire and OH&S (`mix lat.reread --family "Fire and OH&S"`: 170 own-clause laws, 247 amending laws, 21 Acts' orders, 16 feed laws), staled by the Waste, Water and Climate fixes; re-read with this session's change, on Jason's go
- ⬜ Close

## Dependencies

- ⬜ Commencement reader: step procedures, feed figures and workflow rules closed
