---
session: 'Pipeline checks in Elixir: the store scan and extent shapes (#192)'
status: closed
opened: '2026-11-07'
closed: '2026-11-07'
outcome: success
summary: Extent shape mining (mine.py, review.py and four .exs steps) is one task, mix lat.extent_shapes, with output
  identical to the Python pipeline's on run-03's frozen inputs (by sha256) and on today's dump, in 126 s against 235 s.
  The store scan is mix lat.store_scan with named forms; its first form matches the bracketed-Part scan once that
  script's greedy ref pattern is corrected (328 effects in 52 laws, not 310 in 50). Along the way the extent read cache's
  silent misses and the extent version's coverage gap were fixed (Decisions 1 and 4), and Flow was ruled out by measurement
  (Decision 3).
decisions:
- what: 'Decision 1 (A): fix the extent read cache''s and the label fold cache''s [:safe] decode here'
  why: a reading holds atoms not yet made in a fresh VM, so every such law was read again silently (20 s for UK_ukpga_1995_25)
  result: warm dump 0.6 s; 285 builds rebuilt, digest identical
- what: 'Decision 2 (A): the store scan matches the corrected reference, not the original'
  why: the original's greedy pattern read FoundRef and err:Ref as refs
  result: 328 bracketed in 52 laws, 20 unbracketed in 16; listing byte-identical to the corrected script
- what: 'Decision 3 (A): no Flow'
  why: 99.8% of the scan is ChangesFeed.parse, already 4 wide; Flow would schedule the same parse on the same cores
  result: '#192''s Flow question closed; a faster feed-page read parked with the Feed reader'
- what: 'Decision 4 (A): add the four modules LawStart.Input reaches to Extent.ReadVersion'
  why: VersionCoverageTest failed once read_version.ex recompiled; a failing architecture test shouldn't reach main
  result: 285 builds rebuilt, digest identical, stale 0, golden 27/27, mix test 10,233 passed
metrics:
  extent_shapes_s: { python_pipeline: 235, elixir_first: 402, elixir_final: 126, verdicts: 80, overreach: 33, defaults: 9, dump_warm: 0.5, mine: 2.1 }
  extent_shapes_identical: { run_03_sha256: 5 of 5, todays_dump: 9 of 9 files }
  store_scan: { effects: 261557, bracketed: 328, bracketed_laws: 52, unbracketed: 20, unbracketed_laws: 16, wall_s: 70.4, cpu_pct: 420, peak_gb: 2.6, python_s: 9 }
  checks: { stale_built: 0, golden: 27/27, tests: 10233, sobelow_high: 0 }
  agent_tokens: 0
lessons:
- title: A frozen run with a manifest makes a port provable
  detail: run-03's manifest held the sha256 of every input and output, so Mine and Review were proven byte for byte in ExUnit
    on its inputs; the store scan had no frozen run, and its recovered script turned out to carry a fault.
  tag: tooling
- title: Port the rule, check the script
  detail: The bracketed-Part script's greedy ref pattern read FoundRef and err:Ref, undercounting by 18; a byte-for-byte port
    would have carried the misread into every later scan.
  tag: data
- title: Fields sliced from one big binary ran 2.6x slower
  detail: String.split of a 2.6 MB TSV gives sub-binaries; verdicts over them took 271 s against 81 s with :binary.copy.
    Copy fields that travel to workers or feed regex-heavy code.
  tag: tooling
- title: '[:safe] decode misses silently in a fresh VM'
  detail: A cached term holding atoms only a not-yet-loaded module creates won't decode with [:safe]; a rescue that treats
    it as a miss hides it. Decode with non_executable_binary_to_term/1 and log a failed decode.
  tag: infrastructure
- title: A version's file list is compiled once
  detail: SourceVersion's wildcard is evaluated when the version module compiles, so a new file matching it is left out
    until something recompiles it; VersionCoverageTest only sees what the list holds.
  tag: tooling
bugs:
- pattern: 'Extent.ReadCache never hits for a law whose reading holds atoms not yet created: its [:safe] decode raises and the rescue recomputes silently, e.g. UK_ukpga_1995_25 20 s every fresh run'
  category: read-cache-safe-decode-miss
  module: AmendingLaw.Extent.ReadCache
  affected: every ReadCache user; speed only
  fix: non_executable_binary_to_term/1, a failed decode logged (14c881a8, Decision 1)
  step: Extent reader
  status: fixed
- pattern: 'Extent.ReadVersion missed 4 modules law_start/input.ex reaches (Commencement.Effects, Commencement.Evaluator, LatRef, ChangesFeed)'
  category: read-version-coverage-gap
  module: AmendingLaw.Extent.ReadVersion
  affected: the extent version
  fix: the 4 files in its patterns (9c8f9b18, Decision 4)
  step: Extent reader
  status: fixed
- pattern: 'A SourceVersion''s file list is a compile-time wildcard, so a new file its pattern matches is left out of the hash (and of VersionCoverageTest''s walk) until the version module happens to recompile'
  category: version-wildcard-stale
  module: SourceVersion
  affected: every SourceVersion (ChangeVocabulary.Version, ReaderVersion, FeedVersion, Extent.ReadVersion)
  fix: '@external_resource on the pattern directories, or __mix_recompile__?/0 comparing the wildcard with the compiled list'
  step: Store and build
  status: open
- pattern: 'Feed-page reads for whole-store scans are slow: ChangesFeed.parse (SweetXml/xmerl) ~1.9 ms an effect, 99.8% of a 70 s scan'
  category: feed-parse-slow-for-scans
  module: LegislationGovUk.ChangesFeed
  affected: mix lat.store_scan and any whole-store feed scan
  fix: a streaming SAX read (Saxy) of only the attributes a scan needs
  step: Feed reader
  status: open
artifacts:
- backend/lib/sertantai_legal/scraper/checks/
- backend/lib/mix/tasks/lat.extent_shapes.ex
- backend/lib/mix/tasks/lat.store_scan.ex
- backend/lib/sertantai_legal/scraper/amending_law/extent/read_cache.ex
- backend/lib/sertantai_legal/scraper/amending_law/extent/read_version.ex
- backend/lib/sertantai_legal/scraper/label_tools/fold_cache.ex
- backend/test/sertantai_legal/scraper/checks/
- backend/test/fixtures/extent_shapes/run-03/
- backend/data/reports/store-scan/bracketed_container.py
- docs/lat-change-pipeline/WORKFLOW.md
- docs/lat-change-pipeline/TESTING.md
- docs/lat-change-pipeline/GLOSSARY.md
depends_on:
- lat-change-pipeline/2026-11-07-label-tools-run-time
enables:
- lat-change-pipeline/2026-11-07-extent-census-as-a-task
- 'Family 3: ENVIRONMENTAL PROTECTION'
---

# Session: Pipeline checks in Elixir: the store scan and extent shapes (#192) (CLOSED)

## Problem

Some of the pipeline's checks are still Python: copies in each run folder, and store scans written fresh in each session. #192 moves them into tested Elixir mix tasks. On 2026-11-07 Jason split it in two. This session covers the reusable store scan and extent shape mining. The whole-reader census is its own session (`2026-11-07-extent-census-as-a-task.md`, PENDING).

**Plan:** approved 2026-11-07 (`~/.claude/plans/gleaming-doodling-matsumoto.md`). Work is on the branch `python-checks-to-elixir`, fast-forwarded into main on Jason's go.

**Pass rule:**
1. **Frozen run:** `Mine` and `Review` on run-03's frozen inputs reproduce its outputs' sha256 (ExUnit).
2. **Today's dump:** the Elixir shapes run equals `mine.py` and `review.py` on the same input.
3. **Scan listing:** `lat.store_scan --list` equals the recovered Python scan's sorted listing.
4. **Checks:** stale 0, `mix test`, Credo and Sobelow pass.
5. **Wall times:** recorded.

New code goes in `scraper/checks/`, which the code version doesn't cover.

## Todo

- ✅ Open the session, cut the branch, open the census session, take the references: the Python scan reproduces 261,557 / 310 (50 laws) / 15 unbracketed in 9 s; the Python shapes pipeline on today's dump in 235 s
- ✅ Tests first: Mine and Review on run-03 against the manifest hashes (red)
- ✅ `Checks.ExtentShapes.Mine` and `Review` ported: run-03's 5 outputs by sha256 (`f0734d74`)
- ✅ `mix lat.extent_shapes`: dump, verdicts, over-reach and defaults in modules; on today's dump all 9 files identical to the Python pipeline's (402 s; see Decision 1)
- ✅ `Checks.StoreScan` + `BracketedContainer` + `mix lat.store_scan`: listing equal to the corrected reference (Decision 2); 70 s, 420% CPU; no Flow (Decision 3) (`09490819`)
- ✅ The pass: stale 0 of 285; golden 27/27; `mix test` 10,233 passed after Decision 4 (`9c8f9b18`); Credo by the hooks; Sobelow 0 high; wall times above; README lines in the run folders; WORKFLOW, TESTING and GLOSSARY
- ✅ Close: session closed, commits on the branch; the fast-forward waits on Jason's go (no push)

## Dependencies

- ✅ Label tools run time (#191) closed and pushed (21ee0d44)

## Shapes: today's run

`mix lat.extent_shapes --out data/reports/extent-shapes/elixir` against the Python pipeline (`reference/`, run-03's scripts over the same `ReadCache`): `diff -r` shows all 9 files identical.

| Phase | Elixir | Python pipeline |
|---|---|---|
| dump | 1.8 s | |
| mine | 2.1 s | 0.65 s (`mine.py`) |
| verdicts | 269 s | 105 s (`verdicts.exs` alone) |
| review | 0.1 s | |
| over-reach | 105 s | |
| defaults | 23 s | |
| whole | 402 s (126 s after the row copy) | 235 s |

The first run's extra time had two causes. The extent read cache missed silently (Decision 1). And the rows were slices of one 2.6 MB binary: verdicts took 271 s over slices against 81 s over copies (`LawReading.row/1` copies them). After both fixes the run took 126 s: verdicts 80, over-reach 33, defaults 9.

## Decision 1: the extent read cache's silent misses

- **Found:** `Extent.ReadCache` decodes its files with `[:safe]`, which allows no new atoms. A reading holds atoms (`:unread`, `:classes`, `:competence` …) that exist only once the extent reader's modules have loaded. So in a fresh VM the decode raises, the rescue treats it as a miss, and the law is read again. `UK_ukpga_1995_25` takes 20 s on every single-law run. Today's runs rewrote 1,199 of the 3,657 cache files. Outputs are unchanged; only time is lost, in every user of the cache: the read pass, the extent checks, and here verdicts, over-reach and defaults.
- **Same trap in #191's `LabelTools.FoldCache`**, which decodes the same way. It hits today only because the label tools load the atoms first.
- **Question:** fix both in this session, or raise the extent one and park it with the Extent reader?
- **Aim:** run time, with no label touched.
- **Options:**
  - **(A) Fix both here.** Decode with `Plug.Crypto.non_executable_binary_to_term/1`: functions still refused, atoms allowed, which is safe since the files are ours. Each cache also counts its misses. **Cost:** `read_cache.ex` is inside two code versions, the extent reader's (`Extent.ReadVersion`) and the change register's (`amending_law/extent/*.ex`). So the edit stales all 285 built laws, which means a weighted rebuild of about 4 minutes, a digest compare and golden. The extent read cache goes cold once and refills on its next use. Moving the file to an `except` list doesn't avoid that, since `version.ex` is itself in the change register's version.
  - **(B) Fix `FoldCache` here** (my code from #191), and park `ReadCache` for the census session (Extent reader).
- **Recommendation: A.** The rebuild is about 4 minutes and the digest proves it changes nothing. In return every cache user gets its warm cache back: the read pass, the extent checks, these shape checks and the coming census.
- **Decided (Jason, 2026-11-07): A.**

## Decision 2: the store scan's reference has a regex fault

- **Found:** the recovered scan reads a provision's ref with `<ukm:Section [^>]*Ref="…"`. The pattern is greedy, so it takes the last `…Ref=` in the tag. In about 9,500 tags that is `FoundRef`, legislation.gov.uk's nearest found provision. In about 4,100 it is `err:Ref`, the message "Section missing in legislation", which then counts as a provision. Read with the true `Ref`, which is what `ChangesFeed` reads, the scan finds:
  - bracketed: 328 effects in 52 laws, against 310 in 50;
  - unbracketed: 20, against 15.

  Listings: `backend/data/reports/store-scan/reference-list.tsv` against `true-ref-list.tsv`. The 2026-11-06 figures (Maritime Safety: Switch-over) undercounted by 18 bracketed effects. The reader fix it informed (`Readers.Feed.located/3`) reads refs through `ChangesFeed`, so it is unaffected. Only the session's reported figures were low.
- **Question:** what should the Elixir scan reproduce?
- **Aim:** checks in code that read the source faithfully (`law-text-wins`: the feed's own ref, never its nearest-found pointer).
- **Options:**
  - **(A) The true-Ref reference** (`true-ref-list.tsv`, the recovered script with only the ref pattern corrected). Note the corrected figures in the Maritime switch-over session.
  - **(B) The original byte for byte,** fault and all.
- **Recommendation: A.** The fault is the reference's, not the rule's, and a port that copied it would carry a misread into every later scan.
- **Decided (Jason, 2026-11-07): A.**

## The store scan

`mix lat.store_scan --form bracketed_container --list data/reports/store-scan/elixir-list.tsv`:
- **Counts:** 261,557 effects; bracketed 328 effects in 52 laws, unbracketed 20 in 16.
- **Listing:** byte-identical to the true-Ref reference (`true-ref-list.tsv`, entities unescaped: the regex read the raw attribute, `ChangesFeed` unescapes it).
- **Run:** 70.4 s wall, 420% CPU, 2.6 GB peak, against the Python regex scan's 9 s on one core.
- **Where the time goes:** on a 1-in-40 sample (33 pages, 4,150 effects), `ChangesFeed.parse/1` (SweetXml on xmerl) takes 7,684 ms; reading and gunzipping take 12 ms. That is 99.8% parse, about 1.9 ms an effect.

## Decision 3: Flow for the store scan?

- **The plan's rule:** try Flow if the scan takes over 60 s with the parse dominating, and keep it only if a timed comparison beats the plain version. Both conditions hold (70 s, 99.8% parse).
- **Why Flow can't win here:** the work is CPU-bound parsing of each page, already 4 wide under the guard (420% CPU). Flow would schedule the same parse on the same cores. Its strengths are partitioned reduce and back-pressure. Here the reduce (dedup in path order) takes milliseconds, and it must keep first-seen order, which partitioning would break.
- **The real lever:** a faster read of the feed pages, such as a streaming SAX parse (Saxy) of only the attributes a scan needs. That belongs to the Feed reader or Sources step, not this tooling session.
- **Question:** add Flow and time it as the plan says, or close the Flow question on this measurement?
- **Aim:** checks in code at a run time that doesn't hold up a step.
- **Options:**
  - **(A) Close it without Flow.** Record the measurement in #192. Park "a faster feed-page read for whole-store scans" with the Feed reader.
  - **(B) Add the `flow` dependency** and time it against the plain scan on the same input.
- **Recommendation: A.** 70 s is fine for a scan run a few times per family. Adding a dependency to confirm a measured no-win isn't worth it.
- **Decided (Jason, 2026-11-07): A.** No Flow; #192's Flow question closed on this measurement.

## Decision 4: the extent version's coverage gap

- **Found:** the full `mix test` has one failure, `VersionCoverageTest`: `Extent.ReadVersion` misses `commencement/effects.ex`, `commencement/evaluator.ex`, `lat_ref.ex` and `legislation_gov_uk/changes_feed.ex`. All four are reached from `law_start/input.ex`, which came in with 44c73d68 (Maritime Safety: Switch-over). `ReadVersion` takes `law_start/*.ex`, but its file list is fixed when `read_version.ex` compiles. Until Decision 1's edit to `read_cache.ex` recompiled it, the list didn't hold `input.ex`, so neither the hash nor the test saw it. The gap predates this session, and the edit only exposed it. Behind it sits a wider fault: a version's file list goes stale when a new file matches its pattern (raised against Store and build).
- **Question:** close the gap here?
- **Aim:** stale results never look current (the reason the versions exist).
- **Options:**
  - **(A) Add the four files to `ReadVersion`'s patterns here.** The extent cache goes stale again and refills on next use (about 11 minutes). `read_version.ex` is in the change register's version too, so the 285 builds go stale again, which means a rebuild (about 4 minutes), the digest compare, golden and stale 0. `mix test` then passes. The wider fault stays parked.
  - **(B) Park it.** The branch keeps a failing test, and the merge waits on the Extent reader's next session.
- **Recommendation: A.** The rebuild is short and proven by the digest. A failing architecture test shouldn't go to main.
- **Decided (Jason, 2026-11-07): A.**

## Parking list

- Feed reader: a faster read of stored feed pages for whole-store scans. A streaming SAX parse (Saxy) of only the attributes a scan needs would replace SweetXml/xmerl, at about 1.9 ms an effect (Decision 3).
