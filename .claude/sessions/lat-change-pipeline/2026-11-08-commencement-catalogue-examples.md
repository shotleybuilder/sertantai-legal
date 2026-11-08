---
session: "Commencement catalogue: examples in the parallel read"
status: pending
lane: build
opened: 2026-11-08
---

# Session: Commencement catalogue: examples in the parallel read (PENDING)

## Problem

`mix lat.commencement_patterns` takes 228 s warm after #195, even though it reads 0 laws. About 170 s of that is the serial merge. For each taken sentence the merge chooses an example at up to four prunings (`example/8`, each an `OwnClause.read`), then reads once more per example law (`merge_law/3`). Feed and markup now take 4–5 s warm, because each law's examples are computed in its parallel, cached scan and the merge only looks them up.

Jason (2026-11-08, Decision in the #195 session): close #195 with option 1, and make option 2 the next session.

## Todo

- ⬜ Plan mode: aim, pass rule (byte-equal to 7d81e1e2's output, warm target), frozen fixtures, out of scope
- ⬜ Move `example/8` into the cached law reading, using the solo-scan argument from `FeedPatterns.LawScan`: a law alone always finds room
- ⬜ `merge_law/3` stays serial; measure what it costs on its own
- ⬜ Cold and warm runs, byte-equal against `backend/data/reports/catalogue-cache/after/warm/commencement/`

## Dependencies

- ✅ #195 whole-store catalogues (`2026-11-08-issue-195-catalogue-cache.md`, 7d81e1e2)
