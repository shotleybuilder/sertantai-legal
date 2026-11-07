---
session: 'Label tools run time (#191)'
status: active
opened: '2026-11-07'
---

# Session: Label tools run time (#191) (ACTIVE)

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
- ⬜ The pass: ✅ restore point `label-tools-rebuild`, weighted rebuild 232.6 s, digest of 285 laws identical; ⬜ cold and warm diffs, stale, golden, tests, wall times (the first cold run died with the terminal at 14:4x; re-run detached)
- ⬜ Close: WORKFLOW and RULES lines, session, commits on the branch, fast-forward on Jason's go (no push)

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
