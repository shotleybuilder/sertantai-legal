---
plan: "QQ Data Readiness — screener data fixes for compliance v0.1"
status: active
created: 2026-09-25
issue: 161
meta_session: .claude/sessions/qq-data-readiness/2026-09-25-qq-00-meta.md

summary: >
  Fix the sertantai-legal data that limits compliance's applicability screener for QQ
  (ENHESA ends 31 Oct 2026; compliance v0.1 ships ~27 Oct; feature freeze 20 Oct).
  Data fixes land by 17 Oct. Every fix is measured with compliance's QQ benchmark.
  A separate track gets prod usable (#133, #27) with no prod action taken without
  explicit approval.
---

# QQ Data Readiness Plan (#161)

## Goal

Legal data good enough that compliance's screener, run on QQ's reviewed profile,
reproduces QQ's legal register except where the register itself is wrong. #161's
acceptance bar is **register recall ≥ 95%**, or the remaining gap explained and
accepted.

Dates: data fixes land by **Fri 17 Oct**. Compliance re-tunes the screener in the week of
13–20 Oct. Feature freeze is **20 Oct**, tag ~27 Oct, ENHESA ends 31 Oct.

## Baseline (2026-09-25)

Compliance run `2026-09-25T1047-reviewed` was reproduced exactly as
`2026-09-25T1107-legal-baseline`, so later `legal-*` runs compare against it.

| Measure | Value | Notes |
|---|---|---|
| Register "yes" laws | 651 | legacy_register.csv (plus 60 "no") |
| In both | 262 | |
| Register only | 389 | 163 not_making, 104 revoked, 74 no_tree, 48 tree/profile misses |
| Screener only | 172 | 45 carry a caveat; 40 are Northern Ireland laws |
| **Evaluable agreement** | **68.2%** | 262 / (262 + 122). Denominator = register-only laws with side `tree` or `profile_or_tree`, **including no_tree** |
| **Register recall (excl. revoked)** | **47.9%** | 262 / (651 − 104). This is closer to #161's recall bar |
| Corpus | 3,250 in-force UK Making laws, 546 with trees | 799 have LAT, 545 have fitness |

### Two things about the metric that shape the ordering

1. **Evaluable agreement leaves out `not_making` and `revoked` laws.** If a misclassified
   law is reclassified as Making, it enters the denominator. If it has no tree, it adds
   to `no_tree` and the headline **falls**. Making fixes raise real recall but can lower
   evaluable agreement until trees exist. Every run reports both numbers.
2. **Evaluable agreement ignores screener-only laws.** Over-match fixes (territory, NI)
   don't change it at all. They're measured by the `screener_only` count and the caveat
   count, i.e. how much a QQ reviewer has to read and dismiss.

## Where the trees come from (constraint)

`compiled_applicability` is built by **fractalaw** and pushed over Zenoh
(`zenoh/taxa_subscriber.ex`). Legal stores it as received. Legal doesn't lint or
normalise it, and it can't ask fractalaw to re-enrich a law. Re-enrichment is a manual
`fractalaw sync publish --laws …` step, and fractalaw only queues laws that its own triage
calls Making. So:

- **Tree coverage** needs LAT (legal), then a fractalaw run (Jason).
- **Extraction quality** (Not, construction, TimeWindow, territory branches) can be fixed
  in two places:
  - **at source in fractalaw**, which is outside this repo, needs a full re-enrichment, and
    is hard to fit into three weeks;
  - **in a legal-side deterministic tree normaliser**, a pure module run on ingest and as a
    backfill. It keeps the raw tree, so every rule is reversible and can be benchmarked
    within hours.

**Recommendation: the normaliser.** Every rule it applies is also logged as a source-fix
request for fractalaw, so the rules can be retired as fractalaw improves. *Needs Jason's
decision; see the meta session.*

## Sessions

| # | Session | Size | Target window | Moves |
|---|---|---|---|---|
| 01 | Making triage & is_making precedence | detailed | 29 Sep – 1 Oct | not_making 163 → only laws with a register-cleanup verdict (~75–85) |
| 02 | Tree coverage for QQ laws | detailed | 29 Sep – 9 Oct | no_tree 74 (+ laws newly Making from 01) → ≤ 5 |
| 03 | Tree normaliser & gate fixes | detailed | 1 – 8 Oct | gate misses 34 → ≤ 8; caveats 45 → ≤ 15 |
| 04 | Jurisdiction & territory over-match | medium | 6 – 10 Oct | screener-only NI 40 → 0; territory-only/branch 54 → ≤ 20 |
| 05 | Controlled vocabulary & actor roles | loose | 8 – 16 Oct | condition misses 14 → ≤ 5; vocab table for compliance (#132) |
| 06 | Register hygiene: revoked audit, #114, #83 | loose | 12 – 16 Oct | 104 revoked laws given a verdict; asc scrape |
| P1 | Prod: backup + partition migration (#133) | track | from 29 Sep | prod has `legal_register`; Electric shapes load |
| P2 | Prod: dev→prod data sync (#27) | track | after P1 | July enrichment + these fixes in prod; repeatable push |

Sessions 01, 02 (LAT half) and P1 prep can run in parallel in week 1. Session 03's normaliser
should land before the wider-corpus tree run, so new trees are normalised on ingest.

## Ordering: where the data disagrees with the brief

The brief's order was: Making → tree coverage → over-matching → extraction quality →
vocabulary → hygiene. The data supports most of it. Four changes:

1. **Making first, as a queue feeder, not as the biggest win.**
   - Of the 163 laws, 74 look procedural by title: amending, commencement, revocation or fees
     instruments. They are probably register-cleanup findings for QQ, not legal fixes.
     #25 found about 17% of "(Amendment)" titles are really Making, though, so each gets a
     quick check rather than a blanket verdict.
   - 89 need a real review: 83 candidate principal laws and 6 EU directives or decisions.
     29 EU directives are already Making and matching.
   - 38 of the 83 principal candidates already have trees. 43 of the 163 were never
     classified at all (`making_classification` is null).
   - Reclassifying the principal laws adds about +25–35 to `both`, and about 45 laws to the
     tree queue.
   - Evaluable agreement will probably *drop* (about 68% → 63%) until session 02 builds those
     trees.
   - It goes first because it decides session 02's queue, not because it moves the headline.
   - It also exposed a code bug: `is_making` has four writers, and `making_review` (the human
     verdict) never wins. 14 of the 163 carry a `making` classification or review but have
     `is_making = false`.
2. **Extraction gates before over-matching.**
   - `generic_code_gate` (21), `construction_misfire` (8) and `gov_actor_gate` (5) are 34
     register-only misses on laws that already have trees. Fixing them is worth up to
     **+8.9 points** of evaluable agreement.
   - Over-match fixes are worth **0 points** on that metric (see above).
   - So session 03 comes before session 04.
3. **Over-matching is mostly a jurisdiction problem, not territory-only trees.**
   - **40 of the 172 screener-only laws are Northern Ireland laws**, and QQ has no NI sites.
     That's more than `territory_only_tree` (16).
   - Two causes:
     - (a) the trees don't gate on jurisdiction:
       - 24 nest `northern_ireland` inside Or branches next to place types (`premises`,
         `workplace`), so any GB org with premises matches.
       - 4 gate at the root but also list `united_kingdom`.
       - 12 have no jurisdiction code at all.
     - (b) legal's `geo_extent` is wrong for about 480 devolved in-force Making laws (192
       nisr, 195 ssi and 94 wsi say `UK`), so it can't be used as a gate.
   - Session 04 fixes `geo_extent` and adds a jurisdiction gate.
4. **Vocabulary is a smaller lever than the #161 comment suggested.**
   - With compliance's routing fix in, the vocabulary-attributable misses are 14
     (`material_condition_miss` 10, `territorial_condition_miss` 3, `multi_condition_miss` 1).
   - Vocabulary still matters for compliance's profile wizard and the MCP interface, so it
     stays as session 05. It is not a bigger QQ lever than tree coverage.

Tree coverage (02) remains the biggest single headline lever. At the current match rate on
tree-bearing QQ laws (262 / 310 = 84.5%), 74 new trees would add about 62 to `both`, taking
evaluable agreement to about 84%.

## Expected trajectory (estimates, to be replaced by measured runs)

| After | both | Evaluable agreement | Register recall* | screener_only |
|---|---|---|---|---|
| baseline | 262 | 68.2% | 47.9% | 172 |
| 01 Making | ~292 | ~63% | ~62% | ~180 |
| 02 Coverage (QQ) | ~390 | ~83% | ~83% | ~200 |
| 03 Normaliser | ~415 | ~88% | ~88% | ~180 |
| 04 Jurisdiction | ~415 | ~88% | ~88% | ~120 |
| 05/06 | ~425+ | ~90%+ | ~92%+ | ~110 |

\* Recall over register "yes" laws minus revoked, procedural and other confirmed
register-cleanup laws. The 95% bar needs the remaining gap explained law by law. That work
goes into compliance's v0.1-06 accuracy loop.

## Measuring

```
cd ~/Desktop/sertantai-compliance/backend && mix screener.benchmark \
  --org c075d56b-8420-4408-b695-ccfbc1ba15ec --name qq --label legal-<NN>-<fix> \
  --profile-file priv/benchmarks/qq/profile_reviewed.json
```

- Compare with `runs/2026-09-25T1107-legal-baseline/` and the previous `legal-*` run.
- Report `both`, evaluable agreement, register recall, `screener_only`, the caveat count and
  the cause rows the session targets.
- Post the before/after numbers on #161.
- Never commit in the compliance repo. Run folders there stay untracked.

## Worklists

Per-law lists are in `.claude/sessions/qq-data-readiness/worklists/`. Each was generated from
`triage.csv` joined with the dev DB state on 2026-09-25.

| File | Rows | Buckets |
|---|---|---|
| `01-not-making.csv` | 163 | principal_candidate 83, procedural_by_title 74, eu_directive_or_decision 6; `verdict` column to fill |
| `02-no-tree.csv` | 74 | a_needs_lat 22, b_needs_enrichment 51, c_fitness_no_tree 1 |
| `03-screener-only.csv` | 172 | by cause; `ni_law` flag |
| `04-tree-gate-misses.csv` | 48 | generic_code_gate 21, material 10, construction 8, gov 5, territorial 3, multi 1 |
| `06-revoked.csv` | 104 | `verdict` column to fill |

## Prod track (P1, P2)

- **No prod action without Jason's explicit go-ahead, step by step.**
- A verified prod DB backup must exist before any migration.
- `~/Desktop/sertantai-stack/scripts/backup.sh` is the 2025 **Baserow** backup script:
  - It `pg_dump`s only `$POSTGRES_DB` from the stack `.env`, plus the Baserow volume.
  - Check it targets `sertantai_legal_prod` before relying on it. Otherwise use a targeted
    `pg_dump -Fc sertantai_legal_prod`.
  - `restore.sh` runs `DROP DATABASE`. Test restores go into a scratch DB, never the live one.
- The order is **schema (#133) before data (#27)**. Compliance's v0.1-03 session verifies
  from its side.

## Risks

- **Fractalaw throughput.** Sessions 02 and 03 (and any source fixes) need fractalaw runs that
  only Jason can trigger. Book the runs in advance: one batch for the QQ laws (week 1), one
  for the wider corpus (week 2).
- **Evaluable agreement will dip after session 01.** Expected and explained above. Warn
  compliance so it doesn't retune against the dip.
- **Normaliser rules can over-correct.** Each rule is a separate flag, benchmarked on its own,
  and the raw tree is kept.
- **Shared dev DB.** Legal's changes reach compliance straight away. Each change is announced
  on #161 with its benchmark run.
