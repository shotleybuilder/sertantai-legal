---
session: Reader run time — make the catalogues, checks and re-reads quicker
status: closed
opened: 2026-10-24
closed: 2026-10-25
outcome: success
summary: >
  A CV-S05 fix round's runs went from ~2½ hours to ~10 minutes with identical output: the extent
  reader was quadratic (12× from a children index in Doc), the check read each law three times,
  laws now run in parallel behind a machine check (LawRunner.Guard), and a per-law reading cache
  (Extent.ReadCache) is shared by the catalogue, check, re-read and build. The amendment read
  pass, re-run after the Doc change staled its indexes, exposed two existing defects (golden 26/27).
decisions:
  - what: Profile before optimising; prove each change gives identical output (term, row or byte digests)
    why: Jason's rule — the session must not change readings
    result: every catalogue, check, re-read, rebuild and golden run compared before/after; identical
  - what: Children index and Part positions built once in Doc.new; unit sentences once per read
    why: profile — units/2 regex-scanned every id per provision, 4× per read (156 s for one read of ukpga 2009/4)
    result: 51 laws 1,357 s → 114 s, output identical
  - what: Parallel runs only after a pre-run machine check (LawRunner.Guard)
    why: Jason — the 5-wide crash had a VM open; check memory, busy cores, VMs first
    result: (MemAvailable − 6 GB) ÷ 1.8 GB per law, cores not busy (/proc/stat), any VM → 1; max 4; decision printed
  - what: Busy cores measured over half a second, not the 1-minute load average
    why: the load average still counted a just-finished run and chose 1 worker on a quiet machine
    result: guard decides 4 on a quiet machine
  - what: Cache readings (small), not parsed documents
    why: measured — decoding a saved parse of ukpga 2009/4 took 5.9 s vs 4.9 s to parse, at 2× the size
    result: Extent.ReadCache, 3,358 laws in 14 MB; warm catalogue 3.5 s, check 3 s, re-read 3.6 s
  - what: Cache keyed by a digest of every app module plus a digest of the law's stored files
    why: a stale reading would be wrong; a full recompute costs ~5 min
    result: any code change re-reads every law
  - what: Leave the commencement catalogue's serial example step
    why: measured — BEAM ~110%, Postgres idle; parallel example selection would be ~5× the work
    result: 13 → 6m40 from the parallel per-law reads only
metrics:
  extent_catalogue_min: { before: 60, after_cold: 5.3, after_warm: 0.06 }
  extent_check_min: { before: 30, after: 1.5, warm_cache: 0.05 }
  extent_reread_min: { before: 12, after: 1.5, warm_cache: 0.06 }
  rebuild_min: { before: 2.05, after: 1.1 }
  golden_min: { before: 6.4, after: 2.6 }
  commencement_catalogue_min: { before: 13, after: 6.7 }
  amendment_read_pass: { laws: 2102, wall_min: 28.7, cpu_min: 81, rules_before: 37719, rules_after: 41435 }
  peak_memory_per_law_gb: { small_si: 0.16, largest_act: 1.70 }
lessons:
  - title: The cost was an algorithm, not the hardware
    detail: The 60-minute catalogue was dominated by a quadratic id scan in one helper; parsing and the "alone" check were minor. Profiling per stage on a sample with the largest laws found it in minutes. Parallelism alone would have hidden it.
    tag: tooling
  - title: A version hash over source files stales derived data when an unrelated field is added
    detail: ReaderVersion covers amending_law/doc.ex, so adding Doc's children/parts fields made all 2,095 amendment indexes stale; builds silently fell back to parsing every amending law (correct, slower). Re-run the read pass after touching a hashed file.
    tag: tooling
  - title: A re-read after store changes surfaces latent reader defects
    detail: The amendment read pass over the fuller store (Schedules fetched, duplicate fragments removed) added 3,716 rules and exposed two existing defects (SOCPA Royal Assent beside a by-order clause; Localism Act read as FRSA 2004). Compare rules per law and trace each difference to its cause before accepting.
    tag: data
  - title: Parallel results must be merged in a fixed order, and aggregates need an ORDER BY
    detail: Catalogue example choice depends on law order; the check's array_agg had no ORDER BY, so even serial runs could differ byte for byte.
    tag: tooling
bugs:
  - pattern: "Commencement: an Act with a by-order clause also holds an \"all — act_enactment\" (Royal Assent) rule, so an amending provision no order rule names is dated Royal Assent: SOCPA 2005 Sch.7 para 27(2) repealing RTA 1988 s.4(6) dated 2005-04-07, golden expects 2006-01-01 (SI 2005/3495). Exposed 2026-10-25 when the read pass (with SOCPA's Schedules now held) first reached that repeal: golden 26/27"
    category: commencement
    module: Commencement (OwnClause / LawStart act_enactment rule beside a by-order clause; CV-S04)
    affected: 1
    fix: "Royal Assent stands only for an Act with no clause (CV-S04's rule); SOCPA s.178(8) leaves the rest to orders. Fix in CV-S04's readers, then rebuild; or confirm the order (SI 2005/3495) is held and read"
    status: open
  - pattern: "Amendment reader: \"The Localism Act 2011 is amended as follows\" (PCA 2017 Sch.1 para 94) read as amending FRSA 2004 whenever FRSA is among the laws pointing to the amending law; with only the Localism Act it reads nothing"
    category: amendment
    module: Amendment.Reader (law?/laws title matching)
    affected: 3
    fix: "Find why the context's title doesn't select the Localism Act and FRSA matches instead; the stored rules before 2026-10-25 had the Localism Act (FRSA wasn't then pointing to PCA 2017)"
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/doc.ex
  - backend/lib/sertantai_legal/scraper/law_runner/guard.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/read_cache.ex
  - backend/lib/mix/tasks/lat.extent_patterns.ex
  - backend/lib/mix/tasks/lat.extent_check.ex
  - backend/lib/mix/tasks/lat.amending.ex
  - backend/lib/mix/tasks/lat.commencement_patterns.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
depends_on:
  - 2026-10-22-cv-s05-extent-reader.md
enables:
  - CV-S05 rounds in ~10 minutes of runs
  - later families' catalogues and checks at corpus scale
---

# Session: Reader run time (CLOSED)

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
- ✅ Parse each law once and reuse it: cache the parsed `Doc` (or its flattened text and ids) keyed by the stored files' hash, so the catalogue, the check and the re-read don't each parse the same 3,357 laws again.
- ✅ Incremental runs: re-read only the laws a change can alter. Key each law's result by reader version + file hash, and re-use unchanged results ("prove a change alters a run first"; memory: no needless corpus runs). A full run then costs only what changed.
- ✅ The "reads the same alone" check: run it only for examples whose pattern or reading changed, not every sentence on every run.
- ✅ Bounded concurrency inside a run (2 laws at once, under a memory cap), if profiling shows CPU-bound work. Memory: a 5-wide corpus run once crashed the machine; one law at a time is the rule until this is proven safe.
- ✅ The extent check: it re-runs `Patterns.classes` per law. Share that work with the catalogue (the same result), or read the catalogue's stored result.
- ✅ Measure before and after on the same inputs: the extent catalogue, the commencement catalogue and the extent check give identical output, in less time.

- ✅ The amendment read pass (`mix lat.amending --read`): this morning's `Doc` change (`cb5d9ce7`) changed `ReaderVersion`, so all 2,095 amendment indexes are stale and every build and golden re-parses every amending law. The pass is now parallel (`fb72a393`); running it, with a restore point and an `amendment_rules` digest compared before and after, needs Jason's go-ahead.

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

## Parallel, with a check of the machine first (2026-10-25)

- **Jason:** the 5-wide crash happened with a VM session open (usually it isn't), so a parallel run should check the system state first. Memory updated.
- **Measured** peak per law, each in its own process: a small SI 160 MB; the largest Acts 1.27–1.70 GB (ukpga 2010/4). The crashed run held ~3.3 GB per law, with the VM open.
- **`LawRunner.Guard` (`7dd02446`):**
  - The number of laws at once is the smallest of: the maximum, 4; (MemAvailable − 6 GB) ÷ 1.8 GB; and the cores not busy, measured over half a second from `/proc/stat`.
  - A VM running (qemu, VirtualBox, VMware, GNOME Boxes) or an unreadable state means one at a time; `--workers` overrides.
  - The decision is printed at the start of each run.
  - The first version used the 1-minute load average. That still counted a run just finished, so it chose 1 on a quiet machine. Replaced.
- **Results are merged in law order**, so output doesn't depend on how many ran at once.
  - Extent catalogue: 15 → 5 min (peak 2.3 GB); fixtures unchanged.
  - Extent check: 4 → 1.5 min; report and sample identical.
- **So far today:** the catalogue went from ~60 min to 5, and the check from ~30 to 1.5.
- **Next:** the re-read (`lat.amending --extents`, 12 min, writes `extent_rules`), the commencement catalogue (13–15 min) and golden (6 min). Profile each, then the guard where laws are independent.

## The re-read, the commencement catalogue and golden (2026-10-25, Jason: "Go ahead with all three")

- **The re-read (`5142706a`):**
  - restore point `run-time-before-reread`; `extent_rules` snapshotted row for row;
  - today's code, one law at a time: 3m46 (12 min before the reader fix), rows identical;
  - parallel through the guard: 1m30, rows identical.
  - The parents among the laws re-read are now read first, so an SI never reads a parent not yet re-read. That was a latent order dependency in the sequential loop.
- **The commencement catalogue (`83e31838`):**
  - profiled first: no quadratic spot (55 laws, the 5 largest included, 22 s; parsing the XML of amending laws costs most);
  - each law's reading runs in parallel, streamed in law order (a bounded window), with examples chosen in that order as before;
  - 13 min → 6m40, peak 2.9 GB; fixtures unchanged; the "2 examples not held" are the same as before.
- **Golden (`55d58a2b`):** the 21 golden laws run in parallel, results in law order. 6m23 → 3m19; 27/27, every PASS/FAIL line the same. Only the per-law notices print in finishing order.
- **A CV-S05 round's runs now:** the extent catalogue 5 min, the re-read 1.5, the rebuild ~2, the check 1.5, golden 3.3: about 13 minutes, against about 2½ hours this morning. The commencement catalogue (6.7 min) runs only when the commencement readers or the store change.
- **Not done (small):**
  - the rebuild (`lat.vocabulary --build`, ~2 min) is still one law at a time;
  - golden is bound by its slowest law;
  - the commencement catalogue's serial example step, which now dominates it.

## The remaining items (2026-10-25, Jason: "Finish all items in this session")

- **A parse cache was measured and not taken:** loading a saved parse of ukpga 2009/4 takes 5.9 s against 4.9 s to parse it, at twice the XML's size.
- **`Extent.ReadCache` (`fc681416`):**
  - What it holds: a law's reading (`Extent.read`, the catalogue classes, the example and its alone classes), kept between runs. Keyed by the code version (a digest of every module of the app, so any code change reads every law again, never stale) and a digest of the law's stored files. 3,358 laws in 14 MB, under `data/cache/extent_reads/`.
  - Who shares it: the catalogue, the check, the re-read, and the build's unstored extents.
  - Timings: a cold catalogue run 5m21 fills it; warm 3.5 s. From the cache, the check takes 3 s and the re-read 3.6 s.
  - Output: fixtures unchanged; the check's report and sample byte-identical; `extent_rules` identical row for row.
  - The "alone" check now runs only when a law's reading is recomputed.
- **The rebuild (`b7275079`):** parallel, 2m03 → 1m06; every change and claim identical (a digest of all rows).
- **Golden:** prints each law's time and takes `--law X` (`682364b2`). TCPA 1990 alone takes 140–169 s of its ~3 min. Profiled: over half is XML parsing of its amending laws. **The cause is mine:** `ReaderVersion` covers `amending_law/doc.ex`, so this morning's `Doc` change made all 2,095 amendment indexes stale, and the build falls back to parsing each amending law (by design: output unchanged, slower). The read pass restores them.
- **The commencement catalogue's example step:** measured and left. 300 laws take 39 s on 1 worker and 28 s on 4, with the BEAM at ~110% CPU and Postgres idle, so the serial example selection is the limit. Running it in parallel would mean testing every law's first sentence of each pattern (~5× the work). It runs only when the commencement readers or the store change; 6m40.
- **A CV-S05 round now, from code change to agent:**
  - extent catalogue 5 min (cold; fills the cache);
  - re-read ~4 s;
  - rebuild ~1 min;
  - check ~3 s;
  - golden ~3 min (~1–2 min once the amendment indexes are fresh).
  - About 10 minutes in all, against about 2½ hours this morning.

## The amendment read pass (2026-10-25, Jason: "Run it")

- **Before the run:** restore point `run-time-before-amendment-read` (`amendment_rules`); the 2,095 index files archived in `backend/data/cache/amendment-index-2026-10-25.tar.gz`; the rules snapshotted (37,719).
- **The run:** 2,102 amending laws, 4 at once, no failures. 28m40 wall clock, 81 minutes of CPU: about 3× faster than one at a time, more than the ~16 minutes I'd estimated.
- **Rules: 37,719 → 41,435. Not identical, and every difference traced to the store:**
  - 64 laws given their Schedules today: +2,224;
  - 18 laws whose duplicate fragments were removed today (F): +1,137 (e.g. ukpga 2015/15 0 → 89);
  - 14 laws whose Schedules were stored on 2026-10-22, after the last read pass: +355 (e.g. SI 2014/469 0 → 129).
  - Only 3 rules changed. PCA 2017 Sch.1 para 94 now reads as amending FRSA 2004 instead of the Localism Act 2011, which is wrong. The old-style document (with the fragments) reads it the same way, so it's an amendment-reader defect, exposed because FRSA now points to PCA 2017. Bug logged.
- **Golden (indexes fresh):** 2m38, TCPA 1990 130 s. **26/27:** RTA 1988 s.4(6) now ends 2005-04-07, not 2006-01-01.
  - The new SOCPA rules (Sch.7 para 27(2), the Sch.17 table) reach the repeal for the first time.
  - SOCPA's commencement holds an "all — act_enactment" Royal Assent rule beside its by-order clause, so the repeal is dated Royal Assent.
  - This is a CV-S04 commencement defect, exposed by the fuller store. Bug logged; golden all-pass is part of CV-S05's stopping rule, so it is to be fixed before CV-S05 can close.
- **The rebuild has not been re-run since the read pass,** so `provision_changes` still reflect the old rules. The next CV-S05 round's rebuild picks the new ones up.

