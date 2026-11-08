---
session: 'Environmental Protection: Sources'
status: closed
opened: '2026-11-08'
closed: '2026-11-08'
family: '💚 ENVIRONMENTAL PROTECTION'
step: Sources
outcome: success
summary: >
  The Sources gate passes for Environmental Protection after a build. 1,422 documents are needed, held or absent
  upstream (77), with 0 failures and 0 unexplained register differences; two runs are identical. 620 documents
  fetched in four rounds, 0 fetch failures; 16 laws' register statistics re-scraped (Decision 1); the empty-introduction
  bug fixed, with an absent-upstream case.
decisions:
  - what: Re-scrape the 16 laws' register statistics and rebuild the two laws whose feeds moved (Decision 1, a)
    why: the register's statistics are the completeness check; the re-read refreshed two feeds after the build
    result: 14 differences closed; EPA 1990 and Environment Act 1995 explained (register capped at 1,000 effects, parked)
  - what: Register differences explained in a reviewed fixture (test/fixtures/sources/explained.json), read by the gate
    why: Sources.report already took explained differences but the task never passed any
    result: gate PASS with 2 explained
  - what: An introduction stored as a 404 on every path is absent, not not-fetched
    why: SI 1992/682 has no XML upstream; the empty-cache fix would otherwise fail it forever
    result: Sources.introduction_status/2 and EnablingCache.absent_upstream?/1, unit-tested
metrics:
  needs: { laws: 122, before_build: 306, after_build: 1382, final: 1422, held: 1345, absent: 77, failures: 0 }
  fetched: { round_1: 81, round_2: 516, round_3: 20, round_4: 1, after_rebuild: 3, failed: 0 }
  build: { laws: 122, changes: 34552, claims: 292700, seconds: 214, epa_1990_seconds: 190 }
  register: { differences_after_fetch: 16, rescraped: 16, explained: 2, differences_after: 0, became_revoked: 2 }
  checks: { gate_runs_identical: true, tests: 10364, failures: 0, maritime_gate: PASS }
  cost: { days: 1, plan_changes: 0, agent_tokens: 0 }
lessons:
  - title: The register stage writes the feeds it reads
    detail: the dry-run re-read of register statistics (StagedParser :amended_by) refreshed the stored feeds, so two laws' stored changes became one feed behind. Rebuild every law whose feed moves after a register re-read.
    tag: data
  - title: A register re-scrape can re-decide live status
    detail: persist_direct runs LiveStatus. Two in-force SIs became revoked, both rightly (whole revocations, unapplied), and 9 laws' legacy live_description values were rewritten. Print live before and after for each law.
    tag: data
  - title: The register's change statistics cap at 1,000 effects
    detail: Amending reads one results page of 1,000. Laws past that (EPA 1990, 1,699) always differ from a complete feed. Such a difference is explained, not re-scraped.
    tag: data
bugs:
  - pattern: "lat.sources counted an SI's introduction held whenever its enabling cache file existed, even as [] with no introduction stored (12 Maritime amenders, 2026-11-05)"
    category: enabling-cache-empty-counts-held
    module: lat.sources (status/2), Sources.introduction_status/2
    affected: 12 laws (Maritime Safety)
    fix: "an empty cache counts held only when the introduction is in the store (EnablingCache.from_store/1)"
    step: Sources
    status: fixed
  - pattern: "The register's change statistics read one page of the changes feed (Amending @results_count 1000), so a law with more than 1,000 effects is undercounted (EPA 1990: 882 against the feed's 1,699; Environment Act 1995: 876 against 1,072)"
    category: register-stats-capped-at-1000
    module: Scraper.Amending (get_laws_amending_this_law, @results_count)
    affected: "2 laws (Environmental Protection); any law over 1,000 effects"
    fix: "page the affected feed to its end (as ChangesFeed does), then re-scrape those laws' statistics"
    step: Register
    status: open
  - pattern: "Two laws with LAT rows became revoked when their register statistics were re-scraped (SI 2002/1927 by SI 2004/1959 reg. 12; SI 2004/1959 by SI 2010/2598; both unapplied whole revocations): LAT holds rows only for live making laws"
    category: rows-for-revoked-law
    module: LAT parse / discard (LatScope.exclude!/2 or a revoked-law discard)
    affected: 2 laws
    fix: "discard the rows of laws decided revoked (archive first), as for not-making laws"
    step: LAT parser
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/sources.ex (introduction_status/2)
  - backend/lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex (absent_upstream?/1)
  - backend/lib/mix/tasks/lat.sources.ex
  - backend/test/sertantai_legal/scraper/sources/sources_test.exs
  - backend/test/fixtures/sources/explained.json
  - backend/data/reports/sources/environmental-protection-0.txt … -10.txt
  - docs/lat-change-pipeline/WORKFLOW.md (Sources)
depends_on:
  - 2026-11-08-environmental-protection-making-laws.md
enables:
  - "Environmental Protection: Feed reader"
---

# Session: Environmental Protection: Sources (CLOSED)

## Problem

Step 1 for Family 3. Each document the family's 122 laws need is held locally or known absent upstream. That means own text, feed, the amending laws' territory, introductions and enabling Acts, dates and backlog. The baseline has 301 needs with 81 failing, and the territory, dates and backlog needs show only after one build.

Plan (approved 2026-11-08): `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`.
- **Time box:** one day.
- **Meta:** `2026-11-08-environmental-protection-meta.md`.

## Todo

- ✅ Open the step session; baseline gate (`backend/data/reports/sources/environmental-protection-0.txt`)
- ✅ Fix `enabling-cache-empty-counts-held`, test first: `Sources.introduction_status/2`, read by `lat.sources` (no change on this family or Maritime, whose 12 were since refetched)
- ✅ Fetch round 1: 81 fetched, 0 failed; gate 306 needs, 2 failing (enabling Acts for NERC Act 2006), 16 register differences (`-1.txt`)
- ✅ Restore point `sources-environmental-protection-build`; build: 122 laws, 34,552 changes, 214 s (EPA 1990 alone 190 s; 10 laws with no changes)
- ✅ Full-needs gate 1,382 needs, 516 failing (`-2.txt`); fetch round 2: 516, 0 failed; round 3: 20, 0 failed; the last introduction (SI 1992/682) has no XML upstream: an absent case added to the fix (`EnablingCache.absent_upstream?/1`); gate 1,419 needs, 0 failures (`-6.txt`)
- ✅ Register differences: 16; Decision 1 (a): restore points, 16 laws re-scraped (2 became revoked, rightly), EPA 1990 and SI 2016/1154 rebuilt, 3 more fetched; 2 explained (register capped at 1,000: `explained.json`)
- ✅ Pass: gate PASS, 1,422 needs, 0 failures, 0 differences; two runs identical (`-9.txt`, `-10.txt`); `mix test` 10,364 pass; Maritime gate still PASS
- ✅ Close: WORKFLOW Sources, meta row, commits

## Pass rule (fixed)

1. Every needed document is held, or missing with a reason (no XML upstream, 404, out of scope); no fetch failure is left.
2. A held copy older than legislation.gov.uk's latest fails until it is refetched or explained.
3. Each stored feed matches the register's change statistics, or each difference goes to Jason.
4. The counting rules are unit-tested (the empty-introduction fix included); two gate runs give the same report.
5. `mix test` 0 failures; the ratchet clean; hooks pass.

Golden (27) and the fixtures are untouched.

## Dependencies

- ✅ Environmental Protection: Making laws closed (116 making laws, all with LAT rows)

## Parking list

- LAT parser: SI 2002/1927 and SI 2004/1959 became revoked at the re-scrape and still hold LAT rows (frontmatter).
- Register: statistics capped at 1,000 effects (frontmatter); EPA 1990 and the Environment Act 1995 explained in `explained.json` until fixed.

## Baseline (2026-11-08, read-only)

| Need | Needed | Held | Failing |
|---|---|---|---|
| own text | 122 | 121 | 1 stale |
| feed | 121 | 58 | 63 not fetched |
| territory | 37 | 29 | 8 |
| introduction | 12 | 4 | 8 |
| enabling parent | 4 | 4 | 0 |
| backlog | 5 | 4 | 1 |

55 feeds differ from the register's change statistics, most because the feed has not been fetched yet.

## Register differences (2026-11-08)

After the fetch rounds the gate shows 0 failures, and 16 feeds differ from the register's change statistics (`-7.txt`).

**The dry run.** The 16 laws' statistics were re-read through the register's own stage (`StagedParser` `:amended_by`), with no database write. Scratchpad script; results in the table below.
- Every law's fresh statistics match its feed, except EPA 1990 and the Environment Act 1995. For those two the register reads one page of 1,000 effects, which they exceed. That is raised against the Register (frontmatter).
- **A side effect:** the register stage writes the feeds it reads to the store. Two feeds moved after the build:
  - EPA 1990: 1,697 → 1,699 effects;
  - SI 2016/1154 (Environmental Permitting): 505 → 506.

  Their stored changes are one feed behind.

| Law | Feed now | Register stored | Register fresh |
|---|---|---|---|
| Senedd Act 2026/4 | 3 | 2 | 3 |
| Aggregates Tax (Scotland) Act 2024 | 67 | 66 | 67 |
| Natural Environment (Scotland) Act 2026 | 37 | 0 | 37 |
| SSI 2015/383 | 16 | 8 | 16 |
| EPA 1990 | 1,699 | 882 | 882 (capped) |
| Environment Act 1995 | 1,072 | 876 | 876 (capped) |
| Environment Act 2021 | 487 | 477 | 487 |
| SI 2002/1927, 2004/1959 | 0 | 1 | 0 |
| SI 2002/761 | 14 | 11 | 14 |
| SI 2008/2841 | 102 | 72 | 102 |
| SI 2015/168, 2015/810, 2017/1050, 2017/1200 | +1 | | = feed |
| SI 2016/1154 | 506 | 427 | 506 |

### Decision 1. Re-scrape the 16 laws' statistics, and rebuild the two laws whose feeds moved? — DECIDED (a), 2026-11-08

- **Question.** Write the fresh statistics for the 16 laws, and rebuild EPA 1990 and SI 2016/1154 on their refreshed feeds?
- **Aim:** `coverage-from-lgu`. The register's statistics are the check that each feed is complete, and the build must read the feed held.
- **Options:**
  - (a) Do both:
    - re-scrape: a restore point of `legal_register`, then `persist_direct` with the `:amended_by` stage only (as Maritime);
    - rebuild: a restore point of the change tables, then `lat.vocabulary --build --laws UK_ukpga_1990_43,UK_uksi_2016_1154`, about 3½ min;
    - then re-gate and fetch any new needs.

    That leaves 2 differences, both explained by the register's 1,000-effect cap (parked).
  - (b) Rebuild only. The 16 differences stay, each explained in the table above.
- **Recommendation:** (a). It is 16 small writes and 2 rebuilds, and the next gate then compares like with like.
