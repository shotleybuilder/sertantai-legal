---
session: Reader run time — make the catalogues, checks and re-reads quicker
status: active
opened: 2026-10-24
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
- ✅ Parse each law once and reuse it: cache the parsed `Doc` (or its flattened text and ids) keyed by the stored files' hash, so the catalogue, the check and the re-read don't each parse the same 3,357 laws again.
- ✅ Incremental runs: re-read only the laws a change can alter. Key each law's result by reader version + file hash, and re-use unchanged results ("prove a change alters a run first"; memory: no needless corpus runs). A full run then costs only what changed.
- ✅ The "reads the same alone" check: run it only for examples whose pattern or reading changed, not every sentence on every run.
- ✅ Bounded concurrency inside a run (2 laws at once, under a memory cap), if profiling shows CPU-bound work. Memory: a 5-wide corpus run once crashed the machine; one law at a time is the rule until this is proven safe.
- ✅ The extent check: it re-runs `Patterns.classes` per law. Share that work with the catalogue (the same result), or read the catalogue's stored result.
- ✅ Measure before and after on the same inputs: the extent catalogue, the commencement catalogue and the extent check give identical output, in less time.

- ✅ The amendment read pass (`mix lat.amending --read`): this morning's `Doc` change (`cb5d9ce7`) changed `ReaderVersion`, so all 2,095 amendment indexes are stale and every build and golden re-parses every amending law. The pass is now parallel (`fb72a393`); running it, with a restore point and an `amendment_rules` digest compared before and after, needs Jason's go-ahead.

### Reopened 2026-10-25 — in order

- ✅ Inventory of what the first pass missed (8 gaps; see "Inventory")
- ✅ Guard in `LawRunner.run` itself: every parallel run checks the machine — `0ba0bd31`
- ✅ Staleness that hid: version hashes cover what they reach (`VersionCoverageTest`); amendment indexes keyed to the stored text's digest — `7afcd1f0`
- ✅ Build and golden never use stale amendment rules: `Amendment.ReadLaw` reads a stale amending law from the text held — `dcb91f5f`
- ✅ **Amendment read pass speed, profile-led: 35 min → 4 min 30 s** (reader's repeated work, feed start-up cache, workers, largest first; see "Read pass profile"):
  - ✅ step 1, the reader's repeated work: laws named found once per instruction, defined-term patterns compiled once — `18e25def` (570,639 regex compiles gone; 1995/25 8.2 → 1.7 s; SI 2019/696 + WSI 2013/755 ~17 → 2.5 min; rules identical)
  - ✅ step 2, start-up: every LAT law's feed pages were parsed at the start of each pass (160 s); `FeedCache` keeps the parse (offline), keyed by `FeedVersion` + page digest — `d293d7d8` (one-law pass 2 min 15 s → 12 s; golden and build gain too)
  - ✅ step 3, a full pass on the new code: **7 min 19 s (was 35 min)**, 2,099 laws, 0 errors, peak 2.3 GB, 4 workers. Rules 41,581 → 42,270, 17 laws, traced (see below); it exposed a list-item comma in definitions — fixed `81016a36`, so the indexes are stale again until one more pass (7 min)
- ✅ Stop the fix → full pass loop: `--preview` (writes nothing) + `--regression` (committed list + golden laws' amending laws: 255 laws, ~2 min) with a per-law change report (`ReadReport`); the full pass prints the same report; workflow in the scraper guide and memory — this commit
- ⬜ One full read pass at the end of the current round of reader fixes (indexes stale since `6314f79a`; ~7 min) — Jason's go-ahead
- ✅ After the gate: a caption names no law, nested quotes stripped whole — `be32c526` (Petroleum Act 1998 +9, SI 2024/1268 +1; regression 29 changed, net +78)
- ⬜ Environment Act 1995 Sch. 22 para 30 (HSWA, "in this paragraph referred to as …"): its sub-paragraphs read no rule since the "etc." fix (they had read wrongly as COPA 1974) — trace in the reader work after the decomposition gate
- ⬜ Annex/Schedule targets: instructions placed in a Schedule or Annex of the amended law (by a heading, or a term like "the electronic communications code" = CA 2003 Sch. 3A) are read at its paragraphs (EU Annex instructions are now held back, giving no Article rules; PSTI 2022's dropped). Was: a defined term meaning a Schedule of a law ("the electronic communications code" = CA 2003 Sch. 3A, PSTI 2022): read its instructions at that Schedule's paragraphs (now dropped rather than placed on CA 2003 sections; belongs to CV-S05's reader work)
- ✅ Decompose `Amendment.Reader` (1,004 → 305 lines; five modules under ~270; gate 0 changed) — `2d4b7c7e`…`81573975`
- ⬜ Decompose `AmendingLaw.Extent` (1,343 lines) the same way: plan, review, steps test-first, zero-diff gate on the extent catalogue and check
- ⬜ Incremental read pass: re-read only the amending laws whose output can change (per-law inputs; a reader edit no longer stales all 2,102)
- ❌ Cached `Doc` for the read pass — dropped on measurement: loading a stored `Doc` costs about as much as parsing it (2017/3: load 1.3 s, parse 0.6 s; 1995/25: 2.3 vs 4.5 s). Cache only what step 2 shows is costly, if anything
- ⬜ LR-45 Saxy (pending v0.2 session) reconsidered: parsing is not the read pass's bottleneck (profile); kept for memory and cold parses, not for this
- ✅ More workers where memory allows: the read pass's own measure (0.8 GB a law, max 5) — `2efc3ed4`
- ✅ Largest laws first in `LawRunner` (`weight:`) — `2efc3ed4`; full read 7 min 20 s → 4 min 30 s with both
- ⬜ Staleness that over-reaches: `Extent.ReadCache` keyed on the modules the reading uses, not the whole app; `mix.lock` out of `ChangeVocabulary.Version`
- ⬜ Incremental rebuild: skip a law whose stored code version and input fingerprints are unchanged
- ⬜ Commencement catalogue cache (6–7 min every run), as `Extent.ReadCache`

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


## Re-opened as suspended (2026-10-25)

Jason, on CV-S05's 28-minute amendment read pass (for the `DefinedTerms` fix, `65bf8b34`): "why is this not faster given the previous session". This session made the pass parallel (`fb72a393`, ~85 → 28 min, 81 CPU-minutes, 4 workers by the guard's 1.8 GB a law) but gave it neither an incremental mode nor a cache: it was treated as a rare run, and it never was profiled. Two items added to the todo (Jason: "log 1 and 2 in the previously closed session - that should now be marked-up as suspended"). Jason then added the third: more workers where memory allows. All three are pending. Resume after CV-S05 or when Jason says.

## Active again (2026-10-25)

Jason: "make the unclosed/suspended runtime session active again … first todo in the reactivated session is to find the other bits we didn't fix last time around". CV-S05 suspended. No pushes without naming them to Jason first (another lane is fixing GitHub CI).

## Inventory: what the first pass missed (2026-10-25, Jason: "Do the inventory")

From the code (each task's runner, caches, version hashes) and the times recorded in the CV sessions. No runs made for it.

| Run | Time | Parallel | Cached | Incremental | Goes stale on |
|---|---|---|---|---|---|
| Amendment read pass `lat.amending --read` | 35 min (2,102 laws) | guard, max 4 | no | per law, by `ReaderVersion` only | any edit to 8 reader files (all laws); never on a stored-file change |
| Extent re-read `--extents` | 3.6 s warm / ~12 min cold | guard | `Extent.ReadCache` | via the cache | **any module of the app** (cache key) |
| Extent catalogue `lat.extent_patterns` | 3.5 s warm / 5 min cold | guard | `ReadCache` | via the cache | any module of the app |
| Extent check `lat.extent_check` | 3 s warm | guard | `ReadCache` | via the cache | any module of the app |
| Commencement catalogue `lat.commencement_patterns` | 6–7 min | guard | no | no | — (always all 2,606 laws) |
| Own clauses `lat.commencement --read --all` / `--read-amending` | 33 s / 2 min 15 s | **5, no guard** | no | no | — (always all) |
| Orders `--read-orders` | seconds | **5, no guard** | order lists cached | no | — |
| Rebuild `lat.vocabulary --build` | ~1 min (fresh indexes) | guard | no | **no: always every law, though each law's input fingerprints are stored** | `ChangeVocabulary.Version` |
| Golden `--golden` | 2.6 min fresh / ~6 min stale indexes | guard | no | no | — |
| Relabel `lat.relabel` | ~18 min preview | **5, no guard** | no | by `LabelVersion` / `ParserVersion` | label/parse code |
| Wave preview, re-parse `--store only` | ~22 min re-parse | **5, no guard** | no | no | — |
| Feed / markup / order catalogues, feed check | 30 s – 2 min | serial | no | no | — |

### Gaps, worst first

1. **No guard on five parallel runs.** `LawRunner` defaults to 5 workers with no system check: `lat.relabel`, `lat.wave_preview`, `lat.commencement --read / --read-amending / --read-orders`, `lat.reparse --store only`. That is the 5-wide setting of the crash Jason asked a pre-run check for; only the tasks touched in the first pass got the guard (`--read-amending` ran 5 wide unchecked today). Fix: the guard inside `LawRunner.run` itself, so no task can skip it.
2. **Staleness under-reported (correctness):**
   - `ChangeVocabulary.Version` (stored changes) omits `law_start.ex` and `law_start/*.ex`, which its commencement readers use: today's LawStart fixes (`65bf8b34`, `9c28b1ad`) don't mark stored changes stale.
   - `Index.fresh?` (amendment indexes) compares only `ReaderVersion`, never the stored CLML: laws given Schedules or cleared of fragments kept "fresh" indexes (why the last read pass found +3,716 rules nobody had flagged).
3. **Staleness over-reported (time):**
   - `Extent.ReadCache` is keyed by every module of the app: any commit (even golden's printing) makes the next extent catalogue, check and re-read cold (5–12 min, not seconds). It should key on the modules the reading uses.
   - `ReaderVersion` stales all 2,102 indexes for an edit that changes few laws (todo: incremental read).
   - `ChangeVocabulary.Version` includes `mix.lock`: any dependency bump stales every stored change.
4. **No incremental rebuild.** `--build` rebuilds every law though `provision_changes` stores each law's code version and input fingerprints; it could skip laws whose version and inputs are unchanged.
5. **No cache for the commencement catalogue** (6–7 min every run, 2,606 laws) or for the amendment read pass (todo); golden re-reads its laws each run.
6. **Long single-law tails.** `LawRunner` runs laws in list order, so a huge law near the end runs alone (SI 2019/696: the last ~9 of 35 min). Fix: start the largest laws first (by stored file size).
7. **Workers capped at 4 by a cautious estimate** (1.8 GB a law; today's read pass peaked at 1.8 GB for all four together, ~600 MB resident mid-run). Todo: measure, then size.
8. **Serial runs:** the feed, markup and order catalogues and the feed check (30 s – 2 min each) — small; parallel only if they grow.

## The guard in `LawRunner` (2026-10-25, Jason: "Guard start"), code `0ba0bd31`

- `LawRunner.run` asks `LawRunner.Guard` whenever the caller names no `workers`; `--workers N` stays the user's override (printed as such); one law runs alone without probing. `default_workers/0` (5) removed.
- Callers that passed the hard 5 now pass `opts[:workers]`: `lat.relabel`, `lat.wave_preview`, `lat.commencement` (`--read`, `--read-amending`, `--read-orders`); `lat.reparse --store only` asks the guard (live re-parses stay 1 for the rate limit).
- Tests: the guard decides with no workers named; one law never probes. Full suite 8,729 pass. Live: `lat.commencement --read` on 2 laws printed the guard's decision (4 at once: 29.9 GB available, 0.5 of 6 cores busy).
- Docs: the tasks' usage lines and the scraper guide ("Corpus runs are parallel") say the guard decides.

## Staleness that hid (2026-10-25, Jason: "Do those 2"), code `7afcd1f0`

- **Version coverage.** A closure over compiled module references from each version's files: `ChangeVocabulary.Version` reached 20 files it didn't cover (the 5 LawStart readers; effect/feed facts: `effect_*`, `in_force_qualifier`, `note_pointer`, `provision_text`, `changes_feed`; `change_collector/record`; `lat_parser/xml`; the store codec; and I/O: repo, client, CLML store). `ReaderVersion` missed `lat_parser/xml`, `territory`. All but the I/O added. `VersionCoverageTest` now fails the suite on any miss (red-checked: removing the LawStart lines lists all five).
- **Index freshness.** `ClmlStore.digest/1` (the stored text's bytes); the index records it; `Index.fresh?/2`, `current?/3` compare it (callers: the label collector, the read pass).
- **Found on the way:** the vocabulary's build and golden read `amendment_rules` with no freshness check at all (only the label collector checked). They now name stale amending laws, as they name unread extent clauses (golden on RTA 1988: 82 named — all, every index predating today's changes). Using stale rules still happens after the notice; reading those laws' documents on the fly is a todo for Jason.
- Full suite 8,731 pass. Both versions changed, so stored changes and amendment indexes are stale (they were already).

## Never stale amendment rules (2026-10-25, Jason: the answer is self-evident from the aim), code `dcb91f5f`

- `Amendment.ReadLaw`: the read pass's reading of one amending law, moved out of `mix lat.amending` (re-reading 3 laws before/after gave the same 1,383 rules).
- `lat.vocabulary` (build, golden): stored rules only where the amending law's index is fresh; a stale one is read now, for the law built, at the provisions its notes and feed point to (the reader decides each law on its own, so reading for one law gives that law's rules).
- RTA 1988 golden passes; 138 amending laws read from text (all stale today), 180 s instead of 28 s — correct, slower until the indexes are fresh (the incremental and cached read todos).

## Read pass profile (2026-10-25, Jason: "the incremental and cached read pass todos … we need to do these things next"; "the reader is very poorly architected … Needs optimising")

- **Per law, by stage** (ms): uksi 2013/1119 parse 891, read 0; ukpga 1995/25 parse 4,475, read 7,941 (406 provisions × 24 laws); ukpga 2017/3 parse 622, read 512; WSI 2013/755 parse 403. A stored `Doc` loads in 657 / 2,285 / 1,310 / 550 — no gain over parsing (cached `Doc` dropped).
- **The tail is reading, not parsing:** WSI 2013/755 parses in 0.4 s but took ~8 min in the pass (976 provisions, 57 laws).
- **eprof, ukpga 1995/25 reading:** 570,639 `re:compile` calls — `Reader.laws/2` built `~r/(?<!\w)TERM(?!\w)/` for every defined term, every text, every law offered; ~30% of time, GC 19%; 6.3 M `downcase` calls. Fixed `18e25def`.
- **After step 1:** a quarter of WSI 2013/755's provisions for 83 laws reads in 1.3 s; SI 2019/696 + WSI 2013/755 through the pass 2 min 28 s together (peak 1.5 GB) — so most of what's left is outside the reader: step 2.
- Lesson: profile before optimising — the first pass parallelised the read pass without profiling it, and the planned cure (a parse cache) would have saved nothing.

## Read pass, step 2: start-up (2026-10-25, Jason: "Build it"), code `d293d7d8`

- Stage timings: SI 2019/696 parse 1.9 s, extent 1.4 s, index 0.07 s; WSI 2013/755 parse 0.4 s, extent 0.7 s. **Start-up: every LAT law's feed pages parsed, 160 s** — a one-law pass took 2 min 15 s.
- Where a law's 150 ms went: page parse 110 ms, territory query 3 ms; a cached parse loads in ~1.5 ms.
- `FeedCache` (`data/cache/feed_effects/`, one file per law): the parsed effects keyed by `FeedVersion` (ChangesFeed's code, added to `VersionCoverageTest`) and the stored pages' digest (`ClmlStore.feed_files/4`); offline only (`law_effects(…, store: :only)`); the territory lookup stays live.
- Checked: 107 laws' effects equal parsed vs cached; parse 11.8 s, warm 0.28 s; tests for cache hit, a changed page re-parsed, no pages. One-law read pass: cold 2 min 05 s (fills the cache), warm 12 s, same 251 rules.

## Read pass, step 3: the full pass (2026-10-25, Jason: "Run it")

- Restore point `run-time-before-read-pass-2` (amendment_rules, extent_rules); indexes archived in the scratchpad.
- **7 min 19 s** (35 min before today's reader and start-up fixes), 2,099 laws (3 already fresh), 0 errors, peak 2.3 GB, CPU 348%.
- Rules 41,581 → 42,270; 17 laws changed, all from the definition fixes (`5d404342`): abbreviations with a chapter now read — Local Transport Act 2008 → Transport Act 2000 (+191), Railways Act 2005 → Railways Act 1993 (+219), Energy Act 2004 → Electricity Act 1989 (+77), GLA Act 2007 → GLA Act 1999 (+135), Planning (Wales) Act 2015 → TCPA 1990 (+68, was the Hazardous Substances Act), Employment Relations Act 2004 → TULRCA 1992 (+119, was ERA 1996), Planning Act 2008 → TCPA 1990.
- **Exposed, fixed:** asp 2011/6 (WANE) lost 344 rules — its definitions list ends items with "," ("…Act 1981 (c.69),"), so only the last term was read and every 1981 Act instruction went to the 2004 Act (before, with no terms, to all three laws). `DefinedTerms` now ends a definition at ";", "." or "," (each perhaps with "and"/"or").
- **Removed rightly:** PSTI 2022 (ukpga 2022/46) −17 against the Communications Act 2003: "paragraph 3", "paragraph 4" of the electronic communications code (Sch. 3A) had been placed on CA 2003 ss.2, 4, 17A — false changes on real sections.

## Read pass 4 of today (2026-10-25, Jason: "Run it") and what it exposed

- **7 min 14 s**, 2,102 laws, 0 errors, peak 2.1 GB. Rules 42,270 → 42,561; 18 laws, traced: the list-comma fix (`81016a36`) put WANE (asp 2011/6) on the Wildlife and Countryside Act 1981 (127) and the Badgers Act 1992 (23); Water Act 2003 → Water Industry / Water Resources Acts 1991; NC(S)A 2004 → WCA 1981; Scottish Acts → Civic Government (Scotland) Act 1982; SSI 2004/332's rules leave the Listed Buildings (Scotland) Act for "the 1997 Act" (TCP (Scotland) Act 1997, not offered for that SSI).
- **Exposed, fixed `8b3026bd`:** SI 2019/598 regs 6–7 (2 rules) lost. "For regulation 24 substitute—" sits in Part 3 "Amendment to the 2009 Regulations", but `Doc` kept only a provision's deepest heading, so the reader walked back into Part 2 and met "the 2008 Regulations" (newly recognised: its definition ends "; and"); before, it reached the definitions sentence naming all three laws and got the 2009 Regulations by luck. `Doc.headings/2` keeps every container's title, nearest first; the reader checks them all before the text before. Reg 7 now reads the 2009 Regulations.
- Pattern: each definitions fix exposes a reader shortcut that luck had covered; each pass's diff is traced per law before accepting.

## Read pass 5 of today (2026-10-25, Jason: "Run it") and the heading work

- **7 min 20 s**, 2,102 laws, 0 errors. Rules 42,561 → 42,534; SI 2019/598 regained its 2 rules, but **my heading rule was too strong**: SI 2019/453 lost 69 (its Part "Amendments pursuant to the European Communities Act 1972" names the enabling Act and beat "The Transport Act 1968 is amended …" earlier in the Part).
- Fixed: structural nearness in `Text.before` — earlier provisions in the Part, then the Part's headings, then earlier Parts (a Schedule: its earlier paragraphs, its headings, then the body naming it). The reader passes only the nearest heading again.
- Exposed and fixed: titles garbled by xmerl's `//text()` order ("etc.The Building (Approved Inspectors ) Regulations 2010", WSI 2013/747 −5; "EnforcementAmendment of the REACH Regulations 2008", SI 2019/758) — `Doc` titles now read in document order (an old LR-31 zero-diff choice kept the garbling).
- Exposed: SI 2019/758 Sch. 3 ("Amendment of the Annexes and Appendices to the REACH Regulation") read Annex paragraphs as REACH Articles 1, 2(7), 4, 8 — false changes on real Articles. Held back: no Article rules under an Annex/Appendix heading until Annex targets are read (open todo).
- 13 changed laws re-read against the rules before the heading work: 7 differ, all checked right — gains by Part/Schedule headings (asp 2024/15 → CC(S)A 2009; ukpga 1972/70 Sch. 24 → TA 1968; ukpga 2026/6 → MCAA 2009; SI 2019/598 → the 2009 Regulations; SI 2019/758 para 61 → REACH Title 10) and corrections (ukpga 1994/39 → Sewerage (Scotland) Act 1968 / Water (Scotland) Act 1980, not LGFA 1992; SI 2019/544 off a 2011 SI).

## Breaking the fix → full pass loop (2026-10-25, Jason: "we repeat the same pattern … how to stop doing this?"; "do that plan and it needs to outlive this session")

- Cause: `ReaderVersion` hashes the whole reader, so any edit stales all indexes; and I treated stale indexes as urgent though, since `dcb91f5f`, they cost speed, not correctness.
- Built: `Amendment.ReadPass` (the read pass out of the mix task, reading apart from writing), `Amendment.ReadReport` (pure: per amending law, rules removed/added per amended law and the provisions behind them), `mix lat.amending --read --preview` (writes nothing) and `--regression` (`test/fixtures/amendment_read/regression.txt`, each law with why, + the golden laws' amending laws). The full pass prints the same report.
- First regression preview: 255 laws, 1 min 54 s; 2 changes, both expected (SI 2019/758 −4: the Annex guard; SI 2016/285 +6: the title fix finds the Building (Approved Inspectors etc.) Regulations 2010).
- Durable: the workflow in `backend/lib/sertantai_legal/scraper/CLAUDE.md` (amendment reader section) and memory (`reader-fix-loop`, `module-size`).
- Module size: `lat.amending` 372 → under 300 lines (`with_powers` → `AmendingLaw.Extent.Powers`; the read pass → `ReadPass`); `VersionCoverageTest` now stops at I/O modules.

## Plan: decompose `Amendment.Reader` (1,004 lines, 73 functions) — PROPOSED 2026-10-25, revised after review

**Order:** after the end-of-round full read pass (running); **no reader behaviour change until the gate passes** (the Annex/Schedule targets work waits). Each step a commit that leaves the suite green.

**Call direction, no cycles:** `Brackets` ← `Clauses` ← `Targets` ← `LawNamed` ← `Reader`; `RepealTable` → `Brackets`, `Targets`, `LawNamed`. Arities kept; each moved function keeps its name and arity, made public with `@spec` and `@doc` where another module calls it.

| Module | Holds (from Reader, names and arities kept) | Public (called across modules) |
|---|---|---|
| `Amendment.Reader.Brackets` | `@bracket`, `plain_brackets/1`, `bracket_level/1`, `above/2`, `ref/2`, `combos/1` | all |
| `Amendment.Reader.Clauses` | `clauses/1`, `verb?/1`, `operation/1`, `captionless/1`, `strip_captions/1`, `located_brackets/1`, `words_unnamed?/1`, `asides/1` | `clauses/1`, `operation/1`, `captionless/1`, `located_brackets/1`, `asides/1`, `words_unnamed?/1` |
| `Amendment.Reader.Targets` | `numbers/2`, `inserted_named/1`, `sections_quoted?/1`, `provision_path?/1`, `own_number?/2`, `brackets/1`, `quoted_targets/2`, `quoted_paths/4`, `quoting_clause/1`, `named_refs/5`, `rule/4` | `numbers/2`, `brackets/1`, `quoted_targets/2`, `quoting_clause/1`, `named_refs/5`, `rule/4`, `inserted_named/1` |
| `Amendment.Reader.LawNamed` | `named/2`, `laws/2`, `law_named?/2`, `norm/1`, `term_re/1`, `unquote_words/1`, `scoped/4`, `own_part/3`, `law_spans/2` | `named/2`, `law_named?/2`, `norm/1`, `unquote_words/1`, `scoped/4` |
| `Amendment.Reader.RepealTable` | `repeal_table/3`, `repeal_table?/2`, `table_rows/1`, `entries/1`, `table_law?/2`, `line_targets/1`, `siblings/2`, `located/1`, `mixed_line/3`, `mixed_pieces/3`, `provisions/1`, `words_targets/3`, `words_line?/1`, `whole_targets/2` | `repeal_table/3`, `repeal_table?/2` |
| **Stays in `Amendment.Reader`** | `law_ref/3`, `read/4`, `provision?/1`, `references/1`, `has_effect/1`, `parts/1`, `schedule_of/1`, `reference/2`, `instruction/4`, `articles_only/3`, `set_out/2`, `of_text/5`, `rules/5` | its public API unchanged; `repeal_table/3`, `repeal_table?/2` delegate |

**Steps:**
1. `Brackets`, with `ReaderVersion` gaining `lib/sertantai_legal/scraper/amendment/reader/*.ex` in the same commit (`SourceVersion` takes globs) so the coverage test stays green. Unit tests: `plain_brackets("(a)(ii)")`, `bracket_level/1`, `above/2`, `ref/2`, `combos/1` on the inputs the existing reader tests produce ("subsection (5), paragraphs (b) and (c)").
2. `Clauses`: unit tests from reader_test's mixed-instruction cases (AR-08: "omit “either”; and at the end insert—" → two clauses), built with `%Text{}` as reader_test builds them.
3. `Targets`: unit tests from reader_test's quoted-provision cases (Clean Air Act 1968 s.5(1): `(b)` → `(b)`, `(c)`) and named-bracket cases.
4. `LawNamed`: unit tests from readers_test's defined-term cases and the SI 2019/598 / 2019/453 heading cases (`named/2` over texts).
5. `RepealTable`: reader_test's repeals-table cases move to `RepealTable.repeal_table/3` unchanged.
6. After each step: `mix test` green and `mix lat.amending --read --preview --regression` reports 0 changed.
7. **Gate (ask Jason first, ~7 min):** `mix lat.amending --read --preview --all` reports 0 changed over every amending law; every module under ~300 lines.

Review: `backend/data/code-reviews/2026-10-25-reader-decomposition-plan-reviewer.md` — all 7 findings Taken (cycle broken by `Brackets` and a call direction; arities kept; tests named per module; ReaderVersion glob in step 1; gate command exact and asked; what stays listed and the order fixed; figure updated).

## End-of-round pass (2026-10-25, Jason: "implement the plan"), and the "etc." fix

- Read pass with largest-first and the guard's own measure (0.8 GB a law, max 5): **7 min 19 s**, still 4 workers (1.1 cores busy at start → 6 − 2); peak 3.25 GB (largest laws together). Report: 6 laws changed, rules 42,576 → 42,591 — the first report printed by the pass itself.
- Traced: SI 2009/229 and WSI 2016/413 right (cross-headings naming the amended Act); SI 2013/283 and SI 2016/912 **wrong** — "The Maternity and Parental Leave etc. Regulations 1999", "(Licensing etc.) Regulations 2010": the title pattern stopped at the "." of "etc.", so an "etc." title named no law (hidden until the title fix by luck).
- Fixed: one title pattern in the reader allowing "etc." (and in DefinedTerms' apposition). Regression preview: 41 of 258 laws change, rules 21,893 → 22,030 — HSWA ("Health and Safety at Work etc. Act 1974"), the Local Government etc. (Scotland) Act 1994 and the Water Services etc. (Scotland) Act 2005 now named; moves checked (ERRA 2013 s.69 → HSWA s.47; Environment Act 1995 HSWA paragraphs off COPA 1974; the Approved Inspectors Regulations are SI 2010/2215, not 2010/2214 the Building Regulations — the earlier "+6" was itself wrong).
- Open: Environment Act 1995 Sch. 22 para 30 now reads nothing for HSWA (todo).

## Baseline pass for the decomposition (2026-10-25, Jason: "Run it")

- **7 min 23 s**, 5 workers (0.8 cores busy at start), peak 3.35 GB, 0 errors. 85 laws changed, rules 42,591 → 43,548 (+957) — the "etc." fix across the corpus: HSWA named in full; NI "(Design and Construction, etc.)" Regulations; Energy Act 2013 52 rules Nuclear Installations Act → HSWA; SI 2020/1488 +630 on the "Human Medicines (Amendment etc.) (EU Exit) Regulations 2019" (its Schedule heading).
- Exposed (logged, fixed after the gate so the refactor is measured clean): captions naming a law (Petroleum Act 1998 −9) and nested quotes (SI 2024/1268 −1).
- Decomposition step 1 (`Reader.Brackets`) extracted test-first; `ReaderVersion` and `ChangeVocabulary.Version` cover `amendment/reader/*.ex` (the coverage test caught the second).

## Reader decomposition, steps 1–5 (2026-10-25, Jason: "implement the plan")

| Step | Module | Lines | Commit | Regression preview |
|---|---|---|---|---|
| 1 | `Reader.Brackets` | 78 | `2d4b7c7e` | 272 laws, 0 changed |
| 2 | `Reader.Clauses` (+ `unquote_words`, moved here not to LawNamed: `located_brackets` uses it) | 147 | `e1ae9f04` | 0 changed |
| 3 | `Reader.Targets` | 215 | `a109cc29` | 0 changed |
| 4 | `Reader.LawNamed` | 216 | `7512d200` | 0 changed |
| 5 | `Reader.RepealTable` (Reader delegates) | 268 | `81573975` | 0 changed |

- `Amendment.Reader` 1,004 → 305 lines; calls run Brackets ← Clauses ← Targets ← LawNamed ← Reader, RepealTable → Brackets, Clauses, LawNamed; no cycles.
- Each step test-first (red, then green); 3 of my new tests had wrong expectations (a year is a valid bracket; a title is captured from its first capital; a repeals table needs its header row) — corrected to the existing behaviour, never the code.
- Full suite 8,773 pass.
- ✅ **Gate (Jason: "Push then the gate"): `mix lat.amending --read --preview --all` — 2,102 laws, 0 changed, rules 43,548 → 43,548; 4 min 30 s** (5 workers, largest first; the same full read was 35 min this morning). Pushed first: `32cbe53c..c142170a` (27 commits; Dialyzer caught a closed map type in `Targets` — fixed `c142170a`).

## Caption and nested-quote fixes (2026-10-25, Jason: "Carry on")

- First try (`asides/1` on the texts searched for a law) was too blunt: regression preview 52 changed with net losses — `asides` keeps a bracket only right before "Act/Regulations/…", so a title with two bracketed parts ("The Environmental Protection (Disposal of …) (England and Wales) Regulations 2000") lost its first and named nothing. Caught by the preview, never written.
- Fix: `Clauses.uncaptioned/1` drops only the bracket right after a provision reference ("section 1 (…)", "regulation 2(1) (…)"); `unquote_words/1` strips nested quotes innermost first.
- Previews: the two laws as intended; regression 29 changed, net +78 — moves to the Act the text amends (WSI 2025/1320's 20 rules to the Wales 2024 Regulations its context names; SI 2009/1941 off the Insolvency Act 1986); losses checked (each caption had named another Act).
- The preview workflow paid for itself: the blunt version would have been a full write pass and a revert.
- ⬜ End of this round: one full write pass (~4.5 min) — refreshes every index and stores these fixes.
