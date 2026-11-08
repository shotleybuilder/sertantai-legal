---
session: 'Label tools run time (#191)'
status: closed
opened: '2026-11-07'
closed: '2026-11-07'
outcome: success
summary: A family's label tools (shadow, rules, strata, gate, the switch dry run) took about 12 minutes each on Maritime
  Safety; they now take about 85 s for the first and 4-7 s each after it, with outputs byte for byte the same as main's.
  The profile put 516 s of the fold in one law's reach test (regexes per row and change); a prefix test cut it to 74 s
  (Decision 1, A), and a fold cache and parallel folds did the rest. On the branch label-tools-run-time, for the
  fast-forward on Jason's go.
decisions:
- what: 'Decision 1 (A): make the reach test fast inside the fold, though it stales every build'
  why: one law (the Merchant Shipping Act 1995) was 516 s of the 766 s fold, nearly all regexes in Label.reaches?; a cache
    helps only repeat runs
  result: the fold 516 s -> 74 s; the 285 builds rebuilt, digest identical; golden's EPA 1990 513 s -> 105 s
- what: Fold results travel between processes packed
  why: a message copies each row's own list of the law's changes; the cold run reached ~21 GB and the kernel OOM killer
    took the terminal, twice
  result: the cold and warm runs inside a 14 GB unit, no OOM
metrics:
  maritime_wall_s:
    shadow: 766 -> 84 cold, 5 warm
    rules: 768 -> 4
    strata: 749 -> 4
    gate: 734 -> 7
    dry_run: 708 -> 82
    five_tools: 3725 -> 181 cold, 103 warm
  fold_msa_1995_s: 516 -> 74
  build_285_s: 241 -> 232.6 (UK_ukpga_1990_8 started first, 229 s alone)
  checks:
    outputs_vs_baseline: 6 of 6 identical, cold and warm
    digest_285: identical
    stale_built: 0
    golden: 27/27
    tests: 10214
  agent_tokens: 0
lessons:
- title: Profile before parallelising
  detail: The plan's parallel folds could not have beaten one law's 516 s; the profile found it was regex work in a rows x
    changes loop, a two-line guard. Measure first.
- title: Parallel BEAM results copy without sharing
  detail: Rows sharing one changes list became a copy each once sent from a task (~21 GB); the OOM killer took the terminal.
    Ship shared structures packed, and run heavy jobs under systemd-run MemoryMax.
  tag: infrastructure
- title: A capture's arguments run per call
  detail: '&reaches?(&1, base_id(id)) ran the base_id regex once per change, 2M times; bind it first.'
  tag: tooling
bugs:
- pattern: The big golden Acts build 3x slower than on 2026-10-31 with 4 workers (EPA 1990 513 s vs 156 s alone; RTPA 1988
    368 s, HSWA 1974 345 s); the family build itself is fast (Maritime 38.8 s)
  category: big-act-build-slowdown
  module: ChangeVocabulary.Label
  affected: golden's big Acts
  fix: the reach test's prefix guard (55477fd3); golden EPA 1990 105 s
  step: Store and build
  status: fixed
- pattern: The build's wall time is one law, UK_ukpga_1990_8 (229 s alone, started first); its build is unprofiled
  category: build-long-pole
  module: ChangeVocabulary.Build
  affected: 1 law, every rebuild
  fix: profile Build.law/1 for UK_ukpga_1990_8 by phase, as the fold was
  step: Store and build
  status: moved
  moved_to: "profiled in #194 (2026-11-08-issue-194-stage-versions.md); the speed-up is readers-reparse-body there"
- pattern: lat.label_switch's dry run writes the tracked data/reports/change-vocabulary/cv-06-dry-run.csv, overwriting another
    family's committed record
  category: dry-run-overwrites-record
  module: Mix.Tasks.Lat.LabelSwitch
  affected: 1 file, each dry run
  fix: write the dry run's csv per family (cv-06-dry-run-<family>.csv) or to a --out path
  step: Switch-over
  status: fixed  # 2026-11-08-parked-owner-bugs
artifacts:
- backend/lib/sertantai_legal/scraper/change_vocabulary/label.ex
- backend/lib/sertantai_legal/scraper/label_tools/fold_cache.ex
- backend/lib/sertantai_legal/scraper/label_tools/family_fold.ex
- backend/lib/mix/tasks/lat.label_shadow.ex
- backend/lib/mix/tasks/lat.label_rules.ex
- backend/lib/mix/tasks/lat.label_check.ex
- backend/lib/mix/tasks/lat.label_switch.ex
- backend/lib/mix/tasks/lat.vocabulary.ex
- backend/test/sertantai_legal/scraper/change_vocabulary/label_reach_test.exs
- backend/test/sertantai_legal/scraper/label_tools/
- docs/lat-change-pipeline/WORKFLOW.md
- backend/data/reports/label-tools/
depends_on:
- lat-change-pipeline/2026-11-07-ohs-amending-law-reader-repair
enables:
- 'GitHub #192'
- 'Family 3: ENVIRONMENTAL PROTECTION, its later steps in minutes'
---

# Session: Label tools run time (#191) (CLOSED)

## Problem

The label tools a family's later steps run (shadow, rules, strata, gate, the switch dry run) each fold every law from scratch, one at a time: about 12 minutes each for Maritime Safety's 117 laws, repeated about 12 times in its switch-over session. The build starts its longest law last. GitHub #191.

**Plan:** approved 2026-11-07 (`~/.claude/plans/gleaming-doodling-matsumoto.md`). Work on the branch `label-tools-run-time`, fast-forwarded into main once the pass holds. The aim: the same outputs, byte for byte, in a fraction of the wall time, with nothing a label is made from changed.

**Pass rule:**
1. Cold and warm runs on the branch equal main's baseline, byte for byte, with only the guard's decision line and wall-time lines filtered out.
2. Unit tests show the cache key moves when an input moves, and that output order is the input order.
3. The build: the changes digest matches after a weighted rebuild, and the heaviest law starts first.
4. Stale 0, golden 27/27, `mix test` and Credo pass.
5. Wall times are recorded.

**Constraint:** no edit to code the change register's version covers (`ChangeVocabulary.Version`), so no build goes stale, except the reach fix Decision 1 took (then rebuilt). New code goes in `label_tools/` and the mix tasks.

## Todo

- ✅ Open the session, cut the branch, start the baseline on main's code: shadow 766 s, rules 768, strata 749, gate 734, dry run 708 (62 min)
- ✅ Profile: the Merchant Shipping Act 1995 is 516 s of the fold, in the reach test's regexes → Decision 1 (A); the fold now 74 s (`55477fd3`)
- ✅ Tests first: FoldCache keys and round trip, FamilyFold order, reach equivalence (red)
- ✅ FoldCache and FamilyFold; shadow, rules and check wired; `--no-cache` (green, `ec2ba89f`)
- ✅ Dry run parallel in law order; build heaviest first (`ec2ba89f`)
- ✅ The pass: restore point `label-tools-rebuild`, weighted rebuild 232.6 s, digest of 285 laws identical; cold and warm outputs 6 of 6 identical to the baseline; stale 0 of 285; golden 27/27; `mix test` 10,214 passed; Credo by the hooks (results below)
- ✅ Close: WORKFLOW lines (no RULES line: no label rule changed), session, commits on the branch; the fast-forward waits on Jason's go (no push)

## Dependencies

- ✅ OH&S: Amending-law reader repair closed (0 stale, 285 built)

## Profile (`backend/data/reports/label-tools/profile.txt`)

- **One law is most of the fold.** The Merchant Shipping Act 1995 (3,585 rows, 5,565 changes) takes about 545 s: `labels` 371 s and the reaching filter 171 s. Maritime's whole shadow run took 766 s. A mid-sized SI takes about 2 s. So 4-wide folds can't bring a cold run below about 9 minutes; only the cache (warm runs) and a faster fold can.
- **The cost is the reach test.** Each row tests each change (`Label.reaches?/2`, from 8 call sites in the fold), and each test works out the row's ancestors again with regexes (`Label.above/1`, `LatRef.ancestors/1`). For SI 1993/3138 that comes to 2.8M reach tests and 14.9M regex runs, most of the profile. The work grows as rows × changes.

## Decision 1: make the reach test fast inside the fold?

- **Question:** should this session change the reach test so that each row's ancestors are worked out once, and changes are looked up by target rather than scanned?
- **Aim:** the workflow's run time. Labels are unchanged: the pass is byte-identical outputs and an identical changes digest.
- **Options:**
  - **(A) Yes, in this session, on the branch, as its own commit.** It is `Label`'s code, which the code version covers, so all 285 builds go stale. The plan's weighted rebuild (about 4 minutes, and faster after this) then takes them, and the build's own label work gets faster too.
  - **(B) No.** Keep the plan as approved: cache and parallel only. Cold runs stay at about 9–13 minutes, and the fix is parked for the Label fold step.
- **Recommendation: A.** It removes the long pole at its cause, for cold runs and the build alike. The cache alone helps only repeat runs. The byte-identical pass covers it, and the rebuild is already in the plan.
- **Decided (Jason, 2026-11-07): A.**

## Parking list

- Store and build: the build's wall time is now one law, UK_ukpga_1990_8 (229 s, started first, 267th to finish of 285, 232.6 s in all). Its build is unprofiled.
- Switch-over: `lat.label_switch`'s dry run writes the tracked `data/reports/change-vocabulary/cv-06-dry-run.csv`, so a dry run on any family overwrites another family's committed record.

## The pass (`backend/data/reports/label-tools/`)

| Tool (Maritime Safety) | main | cold | warm |
|---|---|---|---|
| shadow | 766 s | 84 s | 5 s |
| rules | 768 s | 4 s | 4 s |
| strata | 749 s | 4 s | 4 s |
| gate | 734 s | 7 s | 7 s |
| dry run (no cache) | 708 s | 82 s | 83 s |

- **Outputs:** each tool's output equals the baseline, cold and warm, with log lines and the guard's line filtered out (`compare.sh`). `cv-06-dry-run.csv` matches too.
- **Rebuild:** 285 laws, digest identical (`digest-before.tsv`, `digest-after.tsv`).
- **Checks:** 0 of 285 stale; golden 27/27 (EPA 1990 105 s, 513 s before); `mix test` 10,214 passed.
- **The crashes:** the first two cold runs reached about 21 GB, and the kernel's OOM killer took the terminal (13:09, 14:49). Rows sent from the tasks each carried their own copy of the law's changes, and since `4899571c` they travel packed. The runs that passed ran in a `systemd-run` unit capped at 14 GB.
