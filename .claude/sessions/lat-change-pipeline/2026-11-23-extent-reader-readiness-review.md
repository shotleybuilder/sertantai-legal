---
session: 'Extent reader readiness review'
status: pending
opened: 2026-11-23
---

# Session: Extent reader readiness review (PENDING)

## Problem

The Commencement reader retrospective found problems that probably affect the Extent reader too: the reader's aim and scope never written; substeps, inputs, outputs and staleness undocumented; one version stamp over the reader (`Extent.ReadVersion`, 95 files, including commencement modules); fetch needs found late; golden run late; heavy checks per fix. Jason (2026-11-23): run a similar retrospective before launching the Extent reader step.

## Todo

- ⬜ The Extent reader's spec: aim, scope in and out, its boundary with the Amending-law and Commencement readers
- ⬜ Its substeps: inputs, writes, outputs, what goes stale and why, what loops
- ⬜ Its complexity, measured; its earlier families' step records read
- ⬜ What to change before the step, decided with Jason
- ⬜ Revise `docs/lat-change-pipeline/COMMENCEMENT-READER.md` (accepted 2026-11-23) to the reader after all the follow-on sessions: substeps, version stamps, loops, overlaps removed; and bring COMMENCEMENT-GUIDE §2 and §5, AMENDMENT-GUIDE's "effects first" and DATA-ARCHITECTURE's `commencement_rules` row up to date with it (Jason 2026-11-23)
- ⬜ Close

## Dependencies

- ⬜ The Commencement reader's four follow-on sessions closed (step procedures; staleness; decouple; order split)
