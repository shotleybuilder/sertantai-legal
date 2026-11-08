---
session: "Whole-store catalogues: cache and parallel (#195)"
status: closed
lane: build
opened: 2026-11-08
closed: 2026-11-08
outcome: success

summary: >
  The feed, markup and commencement pattern catalogues keep each law's result in CatalogueCache,
  keyed by the catalogue's code version and a digest of the law's inputs, and read laws in
  parallel under LawRunner.Guard, replaying the serial choice of examples in law order. Outputs
  are byte-equal to today's code. Warm runs read 0 laws: feed 4 s and markup 5 s (from about 10
  and 21 min), commencement 228 s (from 365 s; its serial merge is the next session).

decisions:
  - what: Feed and markup laws are scanned alone, and the serial choice of examples is replayed from their solo outcomes
    why: examples go first come in law order, and a markup example that is dropped frees its slot, so a law's part depends on the laws before it; a law alone always finds room, so its solo examples hold every one the whole run asks of it
    result: byte-equal patterns and examples, cold and warm; the replay-equals-serial tests cover a dropped slot, a raised example, and a full pattern still asking for another pattern's example
  - what: The cache key is the catalogue's SourceVersion plus a digest of the inputs it gathered, not a list of named input files
    why: every input is in the key by construction (rows, file digests, start input); the database rows are part of a law's input, not only its files
    result: the planted edit gave 0 hits of 1,347; the warm runs gave 0 read
  - what: The commencement catalogue's modules go in commencement_catalogue/, not commencement/
    why: commencement/*.ex is under the wildcards of ChangeVocabulary.Version and Commencement.ReadVersion, so a new file there would stale every build and every commencement rule
    result: no stored output staled
  - what: "Decision: close with commencement at 228 s warm (option 1); the examples in the parallel read are the next session (option 2), not a parked bug (Jason)"
    why: feed and markup were the hour a round; commencement's serial merge (about 170 s) is a separate change with its own byte-equal proof
    result: pending session 2026-11-08-commencement-catalogue-examples.md

metrics:
  before_s: { feed_alone: 593, feed_beside_markup: 637, markup_beside_feed: 1273, commencement: 365 }
  after_cold_s: { feed: 145, markup: 329, commencement: 259 }
  after_warm_s: { feed: 4, markup: 5, commencement: 228 }
  laws: { feed: 1347, markup: 3727, commencement: 2787 }
  commencement_split_s: { one_worker_warm: 398, four_workers_warm: 228, serial_merge_est: 170 }
  cache_size: { catalogues: 44M }
  tests: { change_vocabulary_commencement_cache: 5087 }

lessons:
  - title: A query with no ORDER BY reads in a different order when another scan of the same table is running
    detail: The before feed run sat beside markup, and both scanned legal_articles. Postgres synchronised the scans, so the second started partway through and an EU law's rows came back rotated, changing 3 examples. Run alone, the output matched. Run before-and-after comparisons alone, or order the query.
    tag: data
  - title: Edit in a separate worktree while a "before" run still has a step to start
    detail: The before script ran commencement after feed and markup, and mix would have compiled the new code first. The edits were moved to a git worktree (deps and _build/test copied, data/cache symlinked), so the main tree stayed at HEAD until the run ended.
    tag: tooling
  - title: A cache doesn't speed up the work that stays in a serial merge
    detail: Commencement's cache cut only 31 s, because about 170 s of the warm run is the merge choosing examples. Time one worker against four on a warm run to find the serial share, then profile.
    tag: tooling

bugs:
  - pattern: "The feed catalogue takes a law's rows from a query with no ORDER BY, so a concurrent scan of legal_articles can rotate an EU law's rows and change its examples (e.g. UK_eur_2004_273, 3 examples)"
    category: catalogue-row-order
    module: lib/mix/tasks/lat.feed_patterns.ex (rows/1)
    affected: 3 examples in 1 law (under a concurrent scan only)
    fix: "ORDER BY in the rows query (and markup's), then one --accept review of any example that moves"
    step: Feed reader
    status: fixed  # 2026-11-08-parked-owner-bugs

artifacts:
  - backend/lib/sertantai_legal/scraper/catalogue_cache.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/feed_patterns/{law_scan,law_read,version}.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/markup_patterns/{law_scan,law_read,version}.ex
  - backend/lib/sertantai_legal/scraper/commencement_catalogue/{law_read,version}.ex
  - backend/lib/sertantai_legal/scraper/law_runner.ex (ordered/3)
  - backend/lib/mix/tasks/lat.{feed,markup,commencement}_patterns.ex
  - backend/test/sertantai_legal/scraper/catalogue_cache_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/catalogue/law_scan_replay_test.exs
  - backend/test/sertantai_legal/architecture/version_coverage_test.exs
  - backend/data/reports/catalogue-cache/ (gitignored)
  - docs/lat-change-pipeline/{WORKFLOW,TESTING,DATA-ARCHITECTURE}.md

depends_on:
  - 2026-11-08-issue-194-stage-versions.md

enables:
  - 2026-11-08-commencement-catalogue-examples.md
  - Family 3 (Environmental Protection) fix rounds that re-run the catalogues in seconds
---

# Session: Whole-store catalogues: cache and parallel (#195) (CLOSED)

## Problem

Every run of a whole-store catalogue re-reads every stored file. Feed patterns takes about 8 min and runs serially, markup patterns about 16 min serially, and commencement patterns about 12 min. These times grow with each family's fetches and are paid every fix round. This is item 4 of the scaling review (`backend/data/reports/pipeline-scaling/2026-11-07-scaling-review.md`), to be fixed before Environmental Protection.

**Aim:** each catalogue re-reads only what changed since its last run, and a reader edit's cold run is divided across workers. No output changes. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md` (approved 2026-11-08).

## Todo

- ✅ Open the session: this doc, and branch `catalogue-cache`
- ✅ Before: the three catalogues on today's code, to `backend/data/reports/catalogue-cache/before/` (27 min; feed re-run alone, 593 s)
- ✅ Tests: the `CatalogueCache` cases (7), the replay-equals-serial cases (markup and feed: a slot a dropped example leaves, a raised example, a full pattern still asking for a second pattern's example), and the three versions in `VersionCoverageTest` (written alongside the code, not before it)
- ✅ `CatalogueCache` and the three versions (file lists from the reach walk: feed 70 patterns, markup 69, commencement 18)
- ✅ Feed and markup: the law scans, `LawRunner.ordered` under `Guard`, the replay, `--no-cache`, the cache line
- ✅ Commencement: gathering split from reading, and the reading cached
- ✅ The runs: cold and warm byte-equal; warm reads 0 laws (feed 4 s, markup 5 s, commencement 228 s, which misses its 2 min target: Decision); planted edit 0 hits, then reverted
- ✅ Close: WORKFLOW, TESTING, DATA-ARCHITECTURE; session and #195 closed; code 7d81e1e2 with hooks; push on Jason's go

## Dependencies

- ✅ #193 silent staleness (closed)
- ✅ #194 stage versions (closed, 0f55e75f)

## Plan in brief

- **`Scraper.CatalogueCache`:** one cached result per law. The key is the catalogue's `SourceVersion` plus a sha256 of the inputs the catalogue gathered (file md5s and the law's rows), so every input is in the key by construction.
- **Three new versions,** each held by `VersionCoverageTest`:
  - `FeedPatterns.Version`;
  - `MarkupPatterns.Version`;
  - `Commencement.PatternsVersion`.
- **Feed and markup:**
  - **The law scan:** each law is scanned alone, in parallel under `LawRunner`'s guard. The scan records every change's patterns and every example it computed.
  - **The replay:** today's reduce is replayed in law order, looking examples up instead of computing them. That set always holds the examples the real run needs: a law alone always finds room, and a full pattern takes nothing.
- **Commencement:** each law's reading is cached, keyed on its rows and its start input. The merge is unchanged.
- **Pass rule:**
  - the outputs are byte-equal to today's code;
  - a warm run reads 0 laws, with feed and markup each under 60 s and commencement under 2 min;
  - a planted catalogue edit gives 0 hits;
  - the tests, Credo, Dialyzer and Sobelow pass.
- **Frozen:** the catalogue fixtures and golden. The runs write only to `--out` directories.

## Parking list

- Feed reader: `catalogue-row-order` — `lat.feed_patterns` (and the new `FeedPatterns.LawRead` key) take a law's rows from a query with no `ORDER BY`, so a concurrent scan of `legal_articles` can rotate an EU law's `rows` and change its examples (2004/273, 3 examples)

## Implementation notes

- **Worktree.** The code was written in `../sl-195`, on branch `catalogue-cache` (removed after the merge). The before runs compile the main tree's dev build. The commencement run starts only after feed and markup finish, so it would have compiled the new code; the main tree stays at 0f55e75f until the before runs end.
- **`LawRunner.ordered/3`,** new, in place of `LawRunner.run`. It streams results in the laws' order under `Guard`, so each law's scan is replayed as it arrives and no map of every law's results is held. Each task gets only its own law's name, path and rows.
- **Examples keyed by position.** A scan's examples are keyed by the change's place in the law, not by its example id. Where a law repeats an id, the serial run computes the later change's example again after a drop, and keying by place keeps that behaviour.
- **The commencement catalogue's modules sit in `commencement_catalogue/`,** not `commencement/`. `commencement/*.ex` is under the wildcards of `ChangeVocabulary.Version` and `Commencement.ReadVersion`, so a new file there would have staled every build and every commencement rule.
- **`CatalogueCache` joins `VersionCoverageTest`'s I/O list,** because it only stores.
- **Feed effects come through `FeedCache`.** It returns the same effects as reading the pages, keyed on `FeedVersion` and the pages' digests.

## Results (runs, 2026-11-08)

Reports: `backend/data/reports/catalogue-cache/{before,after}/`.

| Catalogue | Before (today's code) | After, cold | After, warm | Laws read warm |
|---|---|---|---|---|
| Feed patterns | 593 s alone (637 s beside markup) | 145 s | **4 s** | 0 of 1,347 |
| Markup patterns | 1,273 s (beside feed) | 329 s | **5 s** | 0 of 3,727 |
| Commencement patterns | 365 s | 259 s | **228 s** | 0 of 2,787 |

- **Byte-equal:** markup's two files and commencement's five (four fixtures and the leftovers report) are byte-equal, cold and warm.
- **Feed, 3 of 1,716 examples:** these differed from the first before run. All are in one EU law (2004/273), and only the order of the example's `rows` list changed. The old code reads the rows with a query that has no `ORDER BY`. In that before run, feed and markup scanned `legal_articles` at the same time, and Postgres let the second scan join the first partway through (synchronised scans), so the rows came back rotated. Re-run alone, today's code gives files byte-equal to the new code's, cold and warm (`before/feed-alone/`). See the parking list.
- **Planted edit:** a comment added to the feed law scan gave "cache: 0 hits, 1347 read" (136 s). The edit was reverted after the run.
- **Commencement misses its warm target** (under 2 min). The cache does its part (0 laws read), but the run is held up elsewhere:
  - **Measured:** one worker, warm, takes 398 s, and four workers take 228 s. That splits as about 230 s of per-law gathering, which runs in parallel, and **about 170 s of serial merge**.
  - **Where the merge time goes:** the merge chooses examples. For each taken sentence it runs `OwnClause.read` at up to four prunings (`example/8`), and then reads once more per example law (`merge_law/3`). The profile is mostly regex in `LawStart.Provisions` and `Clause.sentences`.
  - **Gathering:** for an amending law it parses the CLML (about 73 ms a law) and counts its notes (about 24 ms).

## Decision: commencement's serial merge (for Jason)

**Question:** commencement patterns' warm run is 228 s, not under 2 min, because examples are chosen and checked in the serial merge. Do we close #195 with that, or move the example work into the parallel, cached law reading too?

**Aim:** the pipeline scales to every family without its checks being skipped. A fix round runs this catalogue once, so the per-round cost is what counts.

**Options:**
1. **Close #195 as it stands.** Commencement goes from 365 s to 228 s warm and 259 s cold; feed and markup go from about 32 min to about 10 s warm. The serial merge is parked for Store and build as its own short session. Nothing more to run now.
2. **Move `example/8` into the law reading**, as the feed and markup scans do: each law alone computes its sentences' examples, and the merge looks them up. `merge_law/3` stays serial, because which examples a law keeps depends on the laws before it. Estimate: a warm run of about 60–90 s. Cost: about half a day of code, and one more cold-and-warm run with a byte-equal check (about 10 min).
3. **Option 2, plus caching `merge_law/3`'s reads** by the law and its kept example ids. Warm would be under 2 min with certainty. More code, more ways to differ.

**Decided (Jason, 2026-11-08): option 1. Option 2 is the next session (`2026-11-08-commencement-catalogue-examples.md`), not a parked bug.** Recommendation was 1. The hour a round was feed and markup, and that is gone (about 10 s warm). Commencement's 4 minutes is now the largest catalogue, but it no longer grows with re-reads, only with the corpus. Option 2 is a clean follow-up with its own byte-equal proof, and fits before Environmental Protection if wanted.
