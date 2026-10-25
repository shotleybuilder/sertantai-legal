---
session: Reader run time — make the catalogues, checks and re-reads quicker
status: active
opened: 2026-10-24
---

# Session: Reader run time (ACTIVE)

## Problem

Each change-vocabulary step's runs take too long (Jason 2026-10-24: "These runs take a long time … optimise and reduce compute time"). A CV-S05 fix round runs:
- the extent catalogue: 25 minutes alone, 60 minutes when sharing the machine;
- the extent check: about 26 minutes;
- the commencement catalogue: 13–15 minutes;
- golden: about 4½ minutes;
- the re-read and the rebuild.

Two catalogue runs in one round (run 4 bugged, run 5 again) cost two hours. The order catalogue takes 30 seconds, so the cost is in reading whole laws, not in the patterns.

## Todo

- ✅ Profile one catalogue run and the check on a sample of laws (`:eprof` / `:fprof`, or timing per stage): XML parse (`SweetXml` in `Doc.new`), `Doc.lines`, sentence splitting, the per-sentence "reads the same alone" check, the regexes. Record where the time goes before changing anything.
- ⬜ Parse each law once and reuse it: cache the parsed `Doc` (or its flattened text and ids) keyed by the stored files' hash, so the catalogue, the check and the re-read don't each parse the same 3,357 laws again.
- ⬜ Incremental runs: re-read only the laws a change can alter. Key each law's result by reader version + file hash, and re-use unchanged results ("prove a change alters a run first"; memory: no needless corpus runs). A full run then costs only what changed.
- ⬜ The "reads the same alone" check: run it only for examples whose pattern or reading changed, not every sentence on every run.
- ⬜ Bounded concurrency inside a run (2 laws at once, under a memory cap), if profiling shows CPU-bound work. Memory: a 5-wide corpus run once crashed the machine; one law at a time is the rule until this is proven safe.
- ✅ The extent check: it re-runs `Patterns.classes` per law. Share that work with the catalogue (the same result), or read the catalogue's stored result.
- ⬜ Measure before and after on the same inputs: the extent catalogue, the commencement catalogue and the extent check give identical output, in less time.

## Dependencies

- ✅ The shared CLML loader (`ClmlStore.law_docs`, `689c0adb`): one place to add a parse cache.
- ✅ CV-S05 suspended for it (Jason 2026-10-25: "Let's suspend and sort out run time"). This session must not change readings: each catalogue, check and re-read gives identical output before and after.

## Profile and first fixes (2026-10-25)

- **Profile** (45 laws: 40 random, the 5 largest; ms in total):
  - reading the files: 132;
  - XML parse: 21,191;
  - `Extent.read`: 504,314;
  - `Patterns.classes`: 658,482 (it reads the law again);
  - the example: 7,934;
  - the "alone" re-read: 31,046.
  - ukpga 2009/4 alone: 156 s for one `Extent.read`.
  - **The cause:** `units/2` regex-matched every id in the document for every provision, four times per read (plus once in the catalogue), and `holds_id?/3` re-walked the ids per id. This is quadratic in law size; parsing and the "alone" check are minor.
- **Fix 1 (`cb5d9ce7`):** `Doc.new` builds each id's direct children and the Part positions once; the reader builds its unit sentences once. 51 laws: 1,357 s → 114 s (12×), output identical term for term (extent, classes, examples, alone).
- **Fix 2 (`13e247a0`):** the check reads and classes each law once instead of three times (`Patterns.classes/2` takes the extent read). The OH&S check went from 30 minutes to 4, with the report identical to round 5's. Its claims are now in a fixed order (`array_agg … ORDER BY`), so the sample is repeatable byte for byte; before, two runs could differ in claim order.
- **The extent catalogue:** 60 minutes → 15. No example reads differently. Its fixtures are now current (`821bcd8d`): the ten pattern keys left stale after run 7 moved as reviewed.
- **Cores:** the machine has 6; every run uses one (about 110% CPU, about 290 MB). Next, with Jason's go-ahead:
  - measure peak memory on the largest Acts;
  - laws in parallel with a fixed limit (4 of 6) and a memory ceiling;
  - prove the output identical.
- **Still to profile:** the commencement catalogue (13–15 minutes), the re-read (12), golden (6).

