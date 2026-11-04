---
session: 'Maritime Safety: Sources'
status: closed
opened: '2026-11-04'
closed: '2026-11-04'
family: '💙 TRANSPORT: Maritime Safety'
step: Sources
outcome: success
summary: >
  The Sources gate passes for Maritime Safety after a build: all 682 documents the 117 making laws' labels need are
  held or absent upstream (16), 0 failures, 0 register differences, two runs identical. 314 documents fetched in
  three rounds with 0 fetch failures; 5 laws' register change statistics re-scraped (Jason). Same day, first plan.
decisions:
  - what: Build once between fetch rounds, so the gate sees territory, dates and backlog needs
    why: on OH&S the gate passed on own text and feeds, then failed at Store and build (103 needs)
    result: needs 235 → 682 seen in this step; WORKFLOW.md Sources records the order
  - what: Re-scrape the 5 differing laws' register statistics (Decision 1, Jason)
    why: each had 2026 amendments the register hadn't counted; the register's statistics are the completeness check
    result: 0 differences; MSA 1995 then had a newer register than its feed, so its feed was refreshed and the law rebuilt (+4 backlog needs, fetched)
metrics:
  needs: { laws: 117, before_build: 235, after_build: 682, held: 666, absent: 16, failures: 0 }
  fetched: { round_1_feeds: 101, round_2: 201, round_3: 8, after_decision_1: 4, failed: 0 }
  build: { laws: 117, changes: 13729, seconds: 161 }
  register: { differences_before: 5, rescraped: 5, differences_after: 0 }
  checks: { gate_runs_identical: true, tests: 9817, failures: 0 }
  cost: { days: 1, plan_changes: 0, agent_tokens: 0 }
lessons:
  - title: The gate's full needs show only after a build
    detail: territory, dates and backlog are read from stored changes (Store.for_law); before the build the gate passed on 235 of the 682 needs. Building once inside Sources closes the gap OH&S fell into.
    tag: data
  - title: A register re-scrape can make our feed the stale one
    detail: MSA 1995's re-scraped statistics (887) passed our feed (885, fetched 2026-10-09); refreshing the feed and rebuilding the law brought 4 new backlog needs. Re-scrape, then compare again, before calling the gate passed.
    tag: data
  - title: persist_direct with a single stage writes only that stage's fields
    detail: ParsedLaw.to_db_attrs drops nil and empty values, so StagedParser stage :amended_by → LawParser.persist_direct updated the 5 laws' change statistics with live status unchanged (checked per law).
    tag: tooling
artifacts:
  - backend/data/reports/sources/maritime-safety-0.txt … -7.txt
  - docs/lat-change-pipeline/WORKFLOW.md (Sources: gate after one build)
depends_on:
  - 2026-11-04-maritime-safety-making-laws.md
  - 2026-11-04-maritime-safety-meta.md
enables:
  - "Maritime Safety: Feed reader"
---

# Session: Maritime Safety: Sources (CLOSED)

## Problem

The 117 making laws of Maritime Safety now have LAT rows (Making laws step). Every document the later steps need must be held locally or known absent upstream:
- their feeds;
- the amending laws' bodies;
- commencement orders;
- enabling Acts.

On OH&S, the gate passed before a build and then failed later, when the build surfaced new needs (103 documents). So this run builds once between the fetch rounds.

- **Plan (approved 2026-11-04):** `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`; principles `coverage-from-lgu`, `law-text-wins`.
- **Time box:** one day.
- **Meta session:** `2026-11-04-maritime-safety-meta.md`.

## Todo

- ✅ Session and baseline: 117 laws, 235 needs (own 118 held; feed 16 held, 101 not fetched); 92 register differences (`backend/data/reports/sources/maritime-safety-0.txt`)
- ✅ Fetch round 1: 101 feeds fetched, 0 failed; gate: 0 failures on own and feed, 5 register differences (`-1.txt`)
- ✅ Restore point `sources-maritime-build`; build: 117 laws, 13,729 changes, 2 min 43 s (7 laws with no changes, e.g. SI 2025/1234 and 2025/1298, both new)
- ✅ Gate with full needs (`-2.txt`): 667 needed, 201 failing, all not fetched (territory 75, introduction 106, dates 13, backlog 6, enabling parent 1; 10 backlog absent upstream)
- ✅ Fetch round 2: 201 fetched, 0 failed; the one more round: 8 (enabling Acts and one order), 0 failed; after Decision 1, 4 more (MSA 1995's new backlog), 0 failed
- ✅ Register differences: 5, all the register older than the feed (2026 amendments); Decision 1 (a) applied, restore point `sources-maritime-register-rescrape-5`; 0 differences
- ✅ Pass: gate PASS, 682 needs, 0 failures, 0 differences; two runs identical (`-6.txt`, `-7.txt`); `mix test` 9,817 pass; WORKFLOW.md updated
- ✅ Close; meta status row

## Pass rule (fixed)

1. The gate prints PASS after the family build: every need is held and fresh, or absent upstream.
2. Register differences are 0, or each is explained by a named reason the code shows (law newer than the scrape; register older, re-scraped under Decision 1).
3. Two gate runs at the end are identical.
4. `mix test` has 0 failures; `sources_test.exs` is unchanged.

Golden not run: Sources writes no labels or rules.

## Dependencies

- ✅ Making laws step closed (117 making laws with rows)
- ✅ `mix lat.sources` (gate and `--fetch`); `mix lat.vocabulary --build`

## Parking list

## Decisions for Jason

### 1. Five register differences: re-scrape the register's change statistics? — DECIDED (a), 2026-11-04

- **Question.** In 5 laws, our feed has more effects than the register's `🔻_stats_affected_by_*`:

  | Law | Effects (ours vs register) | Laws (ours vs register) |
  |---|---|---|
  | MSA 1995 | 885 vs 872 | 253 vs 251 |
  | SI 2014/1613 | 74 vs 72 | 9 vs 8 |
  | SI 2016/1026 | 5 vs 3 | 2 vs 1 |
  | SI 2017/943 | 2 vs 1 | 2 vs 1 |
  | SI 2023/984 | 1 vs 0 | 1 vs 0 |

  Each has 2026 amendments in our feed (MSA 1995: 27 effects from 9 laws), more than its difference. So the register's statistics are older than the feed. OH&S had the same case (9 laws, 2026-10-22). Re-scrape them?
- **Aim:** `coverage-from-lgu`. The register's statistics are the check that our feed is complete.
- **Options:**
  - (a) re-scrape the 5 laws' change statistics through the register's own path (`StagedParser` stage `:amended_by` → `LawParser.persist_direct`), as on OH&S: dry run, then a restore point of `legal_register`, then apply;
  - (b) accept them as explained by "register older than the feed", and write nothing.
- **Recommendation:** (a). It is 5 fetches, and it leaves 0 differences, so the next gate run compares like with like.

