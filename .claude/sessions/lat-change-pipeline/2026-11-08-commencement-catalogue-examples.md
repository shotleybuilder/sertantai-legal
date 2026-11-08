---
session: "Commencement catalogue: examples in the parallel read"
status: closed
lane: build
opened: 2026-11-08
closed: 2026-11-08
outcome: success

summary: >
  The commencement catalogue's examples are now chosen per law alone, in the cached parallel read
  (CommencementCatalogue.LawScan), and replayed in law order. Only the merge of each law's held
  examples stays serial. Outputs are byte-equal to 7d81e1e2's, and the warm run takes 104 s, down from 228 s.

decisions:
  - what: Each law's examples are computed alone and cached with its sentences; the serial pass looks them up
    why: A law alone always finds room, so the examples the whole run asks of it are a subset of those it computes alone (the FeedPatterns.LawScan argument)
    result: Byte-equal cold and warm; the serial pass fell from about 170 s to 31 s
  - what: The merge of a law's held examples (laws.json) stays serial
    why: Its input is the set held in the whole run, which is often smaller than the solo set
    result: 31 s warm, measured with the task's new "merge:" line

metrics:
  warm: { seconds: 104, before: 228, read: 0, hits: 2787, merge_s: 31 }
  cold: { seconds: 254, before: 259, read: 2787, merge_s: 35 }
  tests: { scraper_and_architecture: 9329 }

lessons:
  - title: A recorded raise must not end a solo scan
    detail: In the serial run, a raise in an example rolls back the whole law, but only when that example is asked for. A solo scan therefore records {:raise, msg} and goes on (the slot freed), so that the outcomes are complete for a run where that pattern is full. The replay raises again only when asked.
    tag: tooling

bugs: []

artifacts:
  - backend/lib/sertantai_legal/scraper/commencement_catalogue/law_scan.ex
  - backend/lib/sertantai_legal/scraper/commencement_catalogue/law_read.ex
  - backend/lib/mix/tasks/lat.commencement_patterns.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/catalogue/law_scan_replay_test.exs
  - backend/data/reports/catalogue-commencement-examples/

depends_on:
  - 2026-11-08-issue-195-catalogue-cache.md

enables:
  - Commencement catalogue runs in under 2 min warm for each family round
---

# Session: Commencement catalogue: examples in the parallel read (CLOSED)

## Problem

`mix lat.commencement_patterns` takes 228 s warm after #195, even though it reads 0 laws. About 170 s of that is the serial merge. For each taken sentence the merge chooses an example at up to four prunings (`example/8`, each an `OwnClause.read`), then reads once more per example law (`merge_law/3`). Feed and markup now take 4–5 s warm, because each law's examples are computed in its parallel, cached scan and the merge only looks them up.

Jason (2026-11-08, Decision in the #195 session): close #195 with option 1, and make option 2 the next session.

## Todo

Plan approved 2026-11-08: `~/.claude/plans/gleaming-doodling-matsumoto.md`. Pass rule: byte-equal to 7d81e1e2's `after/warm/commencement/`; warm reads 0 laws in under 120 s, the merge timed (over 120 s because of the merge alone is a decision, not a fix here); tests, Credo, Dialyzer and Sobelow pass. Fixtures frozen, no `--accept`.

- ✅ Tests first: commencement cases in `law_scan_replay_test.exs` (a not-held slot to the next sentence, a full pattern, a raise rolling its law back, a merge drop freeing a slot for a later law)
- ✅ `CommencementCatalogue.LawScan`: `scan/3` (a law alone) and `select/5` (serial with a function, or the replay over its outcomes), the merge inside
- ✅ `LawRead` caches the outcomes, `Version` holds `law_scan.ex`, the task is the thin reduce with a "merge: N s" line
- ✅ Tests (9,329 in scraper and architecture), Credo diff (no new issues), Dialyzer, Sobelow
- ✅ Cold and warm runs, `cmp` against `after/warm/commencement/`: all five files equal both times
- ✅ Close: WORKFLOW times, TESTING row; session closed; code with hooks, session `--no-verify`; push when asked

## Dependencies

- ✅ #195 whole-store catalogues (`2026-11-08-issue-195-catalogue-cache.md`, 7d81e1e2)

## Results

The runs were under `systemd-run`, with a peak of 2 GB. Reports and logs are in `backend/data/reports/catalogue-commencement-examples/`.

| Run | Time | Cache | Merge | Byte-equal |
|---|---|---|---|---|
| Cold | 254 s (was 259 s) | 0 hits, 2,787 read | 35 s | 5 of 5 files |
| Warm | 104 s (was 228 s) | 2,787 hits, 0 read | 31 s | 5 of 5 files |

Of the 104 s warm, about 70 s goes on gathering each law's rows and start input, and on starting up. Gathering was out of scope here.

