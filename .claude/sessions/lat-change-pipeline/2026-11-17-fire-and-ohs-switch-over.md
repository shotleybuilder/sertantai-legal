---
session: "Fire and OH&S: Switch-over"
status: closed
opened: 2026-11-17
closed: 2026-11-17
outcome: success
family: "Fire and OH&S (round)"

summary: >
  Step 13 for the Fire and OH&S round: every difference between the new and old labels was explained, and the five families switched. 139 laws were written from their merged changes, and the switched families were refolded (388); --stored shows 0 rows differing in all four, and lat.stale --strict --switched shows 0 of 527. 167 rows whose text is gone but whose repeal no source holds keep their old label as known limits (Decision 1 b), with 25 small rule breaches; the step close passes every gate, Checked rows and Stale laws.

decisions:
  - what: "Fix the parked shadow-cause-misses-container first (this step's own code)"
    why: "the shadow would otherwise list rows repealed with their Part as 'none dated' and send the hand looks after false classes"
    result: "Label.reaching/3, the fold's own container reading; labels unchanged (21398df5)"
  - what: "lat.label_switch --apply takes a round (Rounds.switched?/2)"
    why: "the setting holds family names, never a round's; kept in Rounds because StageSplitTest and VersionCoverageTest refused a scope in the fold version"
    result: "the round applied in one run, 139 written"
  - what: "Decision 1 (b): name the 167 text-gone rows as known limits, parked with the Amending-law reader and Sources"
    why: "the law's text shows the rows gone but their repeals sit in schedules not read (SI 1974/2013, SI 1993/1897, SI 1999/2024) or stale; a fold rule would guess the history (repealed since the row's start); switching them as they are would say in force"
    result: "they keep their old label, repealed today; 192 known-limit rows in all (1fd1c6c3); label_rules 0 breaches"
  - what: "Refold the three switched families in the same write"
    why: "label.ex, label_source.ex and known_limits.ex are in FoldVersion: their labels went stale with no change to their values"
    result: "388 written, --stored 0 differing; EP 924 s, Occupational 168 s, Maritime 200 s"

metrics:
  shadow: { rows: 27206, agree: 13446, differ_today: 4993, history_only: 8767 }
  rules: { first: 9, no_made_period: 9, after: 0, legacy_unconfirmed_apart: 99 }
  text_gone: { strict_rows: 648, in_force_new: 167, laws: 9, no_repeal: 132, other_territory_only: 35, mqa_1954: 88 }
  known_limits: { rows: 192, text_gone: 167, no_made_period: 9, container: 13, maker_no_date: 3 }
  checked_rows: { total: 744, match: 696, known: 47, upstream: 1 }
  golden: "27/27"
  dry_run: { laws: 139, not_folded: 0, rows: 26467, differ: 13912, periods_old: 44495, periods_new: 50103 }
  apply: { round: 139, ep: 122, occupational: 149, maritime: 117, failed: 0, stored_differ: 0, stale_switched: "0 of 527" }
  timings: { shadow_cold_s: 600, apply_round_s: 209, apply_ep_s: 924 }
  tests: { mix_test: "11283 passed, 2 skipped" }
  tokens: { agent: 0 }

lessons:
  - title: "Scan the text-gone rows before trusting the shadow's repeal causes"
    detail: "The shadow's 'no repeal held' counts only rows the old path had repealed (142). A scan of rows whose text is '[Repealed]' or dots found 167 in force on the new label, 35 of them with a repeal held for another territory only, under no cause that named them. label_rules has no rule for it."
    tag: data
  - title: "A first strict filter matters: empty text is not text gone"
    detail: "The first text-gone scan took empty text as gone and counted 2,264 rows (headings with children). Only '[Repealed]' or a run of dots is the law's text gone: 648 rows, 167 in force."
    tag: data
  - title: "The pre-commit hook's credo diff fills /tmp"
    detail: "96 repo copies (14.5 GB) of a 20 GB tmpfs stopped every shell command mid-step; nothing was lost, but a background run could have been. Parked as Tooling: credo-diff-copies-left-in-tmp."
    tag: tooling
  - title: "Every fold-version edit in a step costs the switched families a refold; batch them before one write"
    detail: "Three fold-version files changed (the shadow's evidence, the known-limits list); one combined write refolded 388 laws in about 22 min, where separate ones would have cost it twice."
    tag: tooling

bugs:
  - pattern: "The shadow names a cause's evidence only from changes on the row itself, so a row dated or repealed by its container's change reads '(none dated)' (SSI 1999/1 reg.47(8)(a), repealed with Part II by SSI 2011/139)"
    category: shadow-cause-misses-container
    module: ChangeVocabulary.LabelShadow (lat.label_shadow evidence), Label.reaching/3
    affected: "at least 332 rows of EP's causes (SSI 1999/1 266; EPA 1990 66)"
    fix: "the shadow's evidence is Label.reaching/3: the changes reaching the row and those whole on a Part or Chapter holding it, as the fold reads them"
    step: Switch-over
    status: fixed
  - pattern: "A row whose text is gone in the law ('[Repealed]' or dots only) has no held repeal for every territory it covers, so the new label reads in force (Mines and Quarries Act 1954 s.63, repealed by SI 1974/2013 Sch.1 Pt.I; Explosives Act 1875 s.119, only its NI repeal held)"
    category: text-gone-no-repeal-held
    module: "Amending-law reader (repeals schedules not read: SI 1974/2013, SI 1993/1897, SI 1999/2024, Petroleum Act 1998 Sch.5) and Sources (SI 1974/2013, SI 1974/1885 schedules stale)"
    affected: "167 rows in 9 laws (MQA 1954 88, Explosives Act 1875 32, 1971 c.61 16, 1962 c.58 12, 1987 c.12 8); named known limits (Decision 1 b)"
    fix: "read each repealing law's repeals schedule (fetch the stale ones) so the repeal is held with its date and territory; then the rows leave the known-limits list"
    step: Amending-law reader
    status: open
  - pattern: "A Part or Chapter row takes the law's start, in force and undated, while every provision it holds is prospective by order (asc 2025/4 Pt 2, Pt 3 and their Chapters, Pt 4)"
    category: container-in-force-before-its-rows
    module: ChangeVocabulary.Label.Containers (close/2 closes on repeals only)
    affected: "13 rows in 1 law; named known limits"
    fix: "a container row is in force only from its first held row's in-force day, prospective until then"
    step: Label fold
    status: open
  - pattern: "An amending law with no making date in the register is credited before it existed (1971 c.61 s.10 repealed from 1971 by 1982 c.23, not in the register; 1962 c.58 s.40(2) by 1984 c.12, dated 2020-12-31; 1969 c.10 s.23(5) by 1980 c.65, no date)"
    category: amending-law-no-making-date
    module: Register (uk_lrt md_date; missing record)
    affected: "3 rows; named known limits"
    fix: "add 1982 c.23 to the register and correct the making dates of 1984 c.12 and 1980 c.65"
    step: Register
    status: open
  - pattern: "The shadow names a status or date cause's evidence by today's period start and a change's full date only, so a staged change (dated from its first stage) or a row in force from its start and amended later reads 'none dated' (Pipe-lines Act 1962 s.9(7); NISR 1997/195 reg.10(2))"
    category: shadow-cause-dates-todays-period
    module: ChangeVocabulary.LabelShadow (deciding/3)
    affected: "about 27 rows of causes; wording only, labels right"
    fix: "match a change's stage dates too, and for prospective→in force the period where the row came into force"
    step: Switch-over
    status: open
  - pattern: "The pre-commit hook's `mix credo diff` leaves a full copy of the repo in /tmp/credo-diff-<timestamp> (about 160 MB) on every commit and never removes it; /tmp is a 20 GB tmpfs (RAM), so 96 copies (14.5 GB, 2026-11-14 to 17) filled the Claude temp quota and stopped every shell command mid-step"
    category: credo-diff-copies-left-in-tmp
    module: .githooks/pre-commit (credo diff step, line ~179)
    affected: "96 copies, 14.5 GB of tmpfs (cleared by hand 2026-11-17, Jason's go)"
    fix: "after mix credo diff, remove the /tmp/credo-diff-* copy it made (trap on exit), or point credo diff's work dir at a cleaned location"
    step: Tooling
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_source.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/rounds.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/known_limits.ex
  - backend/lib/mix/tasks/lat.label_shadow.ex
  - backend/lib/mix/tasks/lat.label_switch.ex
  - backend/config/config.exs
  - backend/data/reports/switch-over/fire-and-ohs-known-limits.md
  - backend/data/reports/switch-over/fire-and-ohs-* (shadow, rules, samples, scans, dry run, apply, stored, step close)
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/switch-over-check/SKILL.md

depends_on:
  - 2026-11-17-fire-and-ohs-labels-side-by-side.md

enables:
  - "Fire and OH&S: Retrospective"
---

# Session: Fire and OH&S: Switch-over (CLOSED)

## Problem

This is step 13 for the Fire and OH&S round. Its five families are FIRE, FIRE: Dangerous and Explosive Substances, OH&S: Gas & Electrical Safety, OH&S: Mines & Quarries and OH&S: Offshore Safety. The step explains every difference between the round's new and old labels, then writes the round's `lat_label_timeline` from its merged changes (AIMS `binds-on-date`).

- **Baseline** (Labels side by side), 139 laws and 27,206 rows: 10,656 agree, 6,968 differ today, 8,225 differ in history only, and 1,357 have no stored timeline.
- **Parked on this step:** `shadow-cause-misses-container` (from Environmental Protection). The shadow misses a row's Part or Chapter as evidence.
- **Plan:** `~/.claude/plans/gleaming-doodling-matsumoto.md`.

## Todo

- ✅ Open the session and the meta row; run `label_checked --list` and `lat.stale --list` for the round early
- ✅ Code, TDD, one commit (21398df5): the shadow looks at the row's containers (parked bug); `label_switch --apply` takes a round
- ✅ Causes and rules: `label_shadow` and `label_rules` for the round, saved to `switch-over/`
- ✅ Hand looks: 12 seeded rows for each cause naming no evidence; large classes profiled by law and rule; classes over 100 rows as decisions for Jason
- ✅ Rules and checks: `--list` each breach; small classes named in `fire-and-ohs-known-limits.md`; `label_checked`; golden from inputs
- ✅ Dry run → Jason → restore point → five names in `:label_families` → `--apply` for the round and refold the switched families
- ✅ After the apply: `--stored` 0 differing; `lat.stale --strict --switched` 0; `mix test`, Credo; the step close
- ✅ Docs and close: WORKFLOW step 13, the skill, the meta row; commits by path, no push

## Pass rule (fixed at plan)

1. `label_shadow` sorts every differing row by cause, and the report is saved.
2. Each cause naming no evidence gets a hand look at 12 seeded rows. A class over 100 rows goes to Jason.
3. `label_rules` finds 0 breaches outside the named known limits.
4. `label_checked` matches every row, apart from known rows, upstream rows and other families' parked regressions.
5. Golden scores 27/27 from inputs.
6. The dry run folds all 139 laws, with 0 rule breaks.
7. **After the apply:**
   - `--stored` shows 0 rows differing, with no law failed;
   - `lat.stale --strict --switched` shows 0;
   - `mix test` and Credo are clean.
8. **Step close:** every gate, Checked rows and Stale laws PASS.

**The stop:** more than 5 new classes, or a class over 100 rows with no evidence, goes to Jason before any fix.

## Dependencies

- ✅ Fire and OH&S: Labels side by side, closed and pushed (af088e6b)
- ✅ The switched families refolded (388 laws, `--stored` 0)

## Parking list

- Switch-over: `shadow-cause-dates-todays-period`: the shadow names a status cause's evidence by today's period start and a change's full date only, so staged changes (Energy Acts 2004, 2013) and a row in force from its start but amended later (NISR 1997/195) read "none dated" (about 27 rows; wording only)
- Label fold: `container-in-force-before-its-rows`: a Part or Chapter row takes the law's start while every row it holds is prospective (asc 2025/4, 11 rows)
- Tooling: `credo-diff-copies-left-in-tmp`: the pre-commit hook leaves a 160 MB repo copy in /tmp per commit (96 copies, 14.5 GB, filled the temp quota; cleared 2026-11-17)
- Register: `amending-law-no-making-date`: an amending law with no making date in the register (1982 c.23 not held; 1980 c.65 no date; 1984 c.12 dated 2020-12-31), so the fold credits it before it existed (3 rows)
- Amending-law reader / Sources: `text-gone-no-repeal-held`: Decision 1

## Early checks

- **Checked rows:** 744 in all: 696 match, 47 known, 1 upstream. PASSED, so there is no regression since Labels side by side. Report: `switch-over/fire-and-ohs-checked-early.txt`.
- **Stale:** the round's 139 laws are stale only on `labels_version` (old-path labels, for this step). None is parser-stale, so nothing needs a re-parse before the apply.
  - The run compiled todo 2's fold edit, so it also counts the 388 switched laws as `fold_version` stale. That is expected; they are refolded at the apply.
  - Report: `switch-over/fire-and-ohs-stale-early.txt`.

## Code (21398df5)

- **The shadow's evidence** is `Label.reaching/3`: the changes reaching the row (`reaches?/2`), plus those whole on a Part or Chapter holding it. It reads them as the fold does (the same `within/2` and own-Part rule) and returns each change as stored.
  - `LabelSource.rows/1` gives each row its `containers`.
  - Fold-version edit: the labels are unchanged, but the switched families are refolded at the apply.
- **The round apply.** `lat.label_switch --apply --family "Fire and OH&S"` passes when every family of the round is in `:label_families` (`Rounds.switched?/2`).
  - It first went in `LabelSwitch`; `StageSplitTest` and `VersionCoverageTest` caught `Rounds` entering the fold version, so it moved to `Rounds`.
- **Checks:** `mix test` 11,281 passed, with the 2 architecture failures fixed and re-run. Credo added no issues.

## Causes and rules (first run)

The shadow and the rules are saved in `switch-over/` as `fire-and-ohs-shadow.txt` and `fire-and-ohs-rules.txt`. The samples are in `fire-and-ohs-samples/` (seed 1317). The scans are `fire-and-ohs-scan*.txt` and `fire-and-ohs-text-gone-in-force.tsv`. The first, cold run took about 10 min.

- **Shadow:** 27,206 rows. 13,446 agree, 4,993 differ today and 8,767 differ only in history. Every cause naming no evidence ("none dated", "no repeal held", "undated") is under 400 rows.
- **Rules:** 9 rows breach, all `no_made_period` (asp 2012/8). 99 `legacy_unconfirmed` rows are listed apart.

## Hand looks (seed 1317; classes profiled by law)

| Cause | Rows | Finding |
|---|---|---|
| history: new prospective from the law's making | 5,581 | the rule `made-law-prospective-until-start` (LR-39); the old path had no made period |
| today: territory E+W→W | 929 | asc 2025/4 901 (a Welsh Act): `devolved-law-applies-in-its-territory` |
| today: territory E+W→E | 227 | SI 2025/797 and SI 2022/547, both "(England)" in the title: the same rule |
| today: changed_by old none | 488 | the Petroleum Acts 1998 (425) and 1987 (63): the commencing order, as `changed-by-one-law-for-compliance` says |
| today: in_force_from new undated | 368 | the Mines and Quarries (Tips) Act 1969 (228) and the Pipe-lines Act 1962 (136): no source dates their start, so it is unknown (`unknown-over-guess`); the old path took Royal Assent |
| today: old unknown, new in force | 280 | rows the old path held no period for (Pipe-lines Act 1962 86, and others); the new periods read right (for example, the 1971 Act s.12(1) repealed and re-inserted by SI 1995/738 on the same day) |
| today: status repealed→in force (no repeal held) | 142 | **Decision 1**: the law's text is gone but no repeal is held |
| status prospective→in force (none dated) | 34 | NISR 1997/195 and 2001/348 (20 rows): in force from the law's own start, where the old path left them prospective, so the new label is right and only the shadow's wording is off. asc 2025/4's Parts and Chapters (13 rows): in force undated while their sections are prospective, so the new label is wrong (`container-in-force-before-its-rows`, 11 rows, named) |
| in force→repealed / repealed (saved) (none dated) | 9 | Parts closed by their children's repeals (`Label.Containers`): right |
| in_force_from later / earlier (none dated) | 7 | staged changes dated from their first stage (`Label.Stages`: the Pipe-lines Act 1962 s.9(7), repealed in part from 2004-09-01 and wholly from 2004-10-05): right; the shadow's wording only |
| in_force_from old undated, new none dated | 4 | 3 undated repeals read from the repealer's making (`never-before-its-maker`): right. The 1971 Act s.10 is repealed from 1971 by 1982 c.23, which isn't in the register (`amending-law-no-making-date`) |

**Credited before its maker** (a scan over every period): 3 rows, all makers the register holds no making date for. Named.

## Decision 1: rows whose text is gone but whose repeal isn't held (for Jason)

**Question.** 167 rows in 9 laws have their text gone in the law: "[Repealed]" in 100 rows and dots only in 67. The old label says repealed. The new label says in force, because no source we read holds a repeal for every territory the row covers.
- 132 rows have no repeal at all.
- 35 have one for another territory only (the Explosives Act 1875 s.119, repealed for NI in 2006; the GB repeal isn't held).

| Law | Rows | Where the repeal is stated |
|---|---|---|
| Mines and Quarries Act 1954 | 88 | the repeals schedules of SI 1974/2013, SI 1993/1897 and SI 1999/2024, and the Employment Act 1989, cited in legacy notes |
| Explosives Act 1875 | 32 | SI 1974/1885, and the Explosives Regulations 2014 for GB |
| Mineral Workings (Offshore Installations) Act 1971 | 16 | 1982 c.23, SI 1993/1823 |
| Pipe-lines Act 1962 | 12 | – |
| Petroleum Act 1987 | 8 | Petroleum Act 1998 Sch.5 |
| 4 others | 11 | – |

The cause is upstream:
- Sources: SI 1974/2013's and SI 1974/1885's schedules are stale (an open Sources bug);
- the Amending-law reader: repeals schedules not read (an open bug);
- pre-1991 repeals the feed doesn't list.

Legacy notes only hint where to look; they never label a row.

**Aim.** `binds-on-date`: a user asking whether MQA 1954 s.63 binds them today would be told yes. It was repealed in 1975.

**Options.**
- **(a) A fold rule, with leave (Label fold).** A row whose text is gone, with no held repeal removing it in each of its territories, reads repealed from its start, maker unknown, as `undated-repeal-with-text-gone` does for a held undated repeal. Today is right, but the history is wrong for the years it was in force (MQA s.63 would read repealed since 1954). It is one fold function and a test, and the switched families would refold again.
- **(b) Name the 167 rows as known limits (recommended).** The switch keeps their old labels: repealed today, with the old path's dates. The root class is parked with the Amending-law reader and Sources, and the rows leave the list when those steps read the repeals.
  - Nothing is guessed, and it uses the mechanism the switch already has.
  - It is above the 100-row triage size, which is why it needs your say.
  - The old dates are not checked (MQA's 2015-05-26 is not the 1975 repeal).
- **(c) Switch them as they are, in force, and park.** Not recommended: 167 rows would go live saying in force when the law's text says repealed.

**Recommendation: (b).** Today's status stays right, and the real fix is reading the repeals at their source, which belongs to two earlier steps.

## Known limits (to name in `fire-and-ohs-known-limits.md`)

- `no_made_period`: asp 2012/8 ss.101, 113, 117, 122 and 123 (9 rows). This is the Label fold's named form (RULES, Label forms below triage).
- `container-in-force-before-its-rows`: asc 2025/4 Parts and Chapters (11 rows; Label fold).
- `amending-law-no-making-date`: Pipe-lines Act 1962 s.40(2), Mines and Quarries (Tips) Act 1969 s.23(5), and the 1971 Act s.10 (3 rows; Register).

**Decision 1: (b)**, Jason 2026-11-17. The 167 rows are named as known limits, with 25 small rule breaches. That is 192 rows in `fire-and-ohs-known-limits.md`, registered in `KnownLimits` (1fd1c6c3). The `text-gone-no-repeal-held` class is parked with the Amending-law reader and Sources.

**Temp quota (2026-11-17).** Shell commands stopped mid-step because `/tmp` (a tmpfs) was full. The cause was 96 repo copies left by the pre-commit hook's `credo diff` (14.5 GB), plus the scratchpad's old dumps (968 MB). Both were cleared with Jason's go, and the hook bug is parked (Tooling).

## Rules and checks (after the known limits)

- **Rules:** 27,206 rows, 0 breaching, PASSED. 99 `legacy_unconfirmed` rows are listed apart (`fire-and-ohs-rules-after-limits.txt`).
- **Checked rows:** 744 in all: 696 match, 47 known, 1 upstream. PASSED (`fire-and-ohs-checked.txt`).
- **Golden from inputs:** 27/27 (`fire-and-ohs-golden.txt`).

## Dry run

`label_switch --family "Fire and OH&S"`: 139 laws folded, 0 not, with 0 rule breaks. Of 26,467 rows, 13,912 differ, and the periods go from 44,495 to 50,103. Files: `fire-and-ohs-dry-run.txt` and `.csv`.

| Today | Old | New |
|---|---|---|
| In force | 24,175 | 24,341 |
| Partly in force | 41 | 110 |
| Prospective | 1,209 | 762 |
| Repealed | 486 | 556 |
| Repealed (saved) | 272 | 364 |

## The write (Jason's go, 2026-11-17)

- **Restore point** `fire-and-ohs-switch-over-apply`: `lat_label_timeline`, `lat_change_log`, `provision_changes`, `provision_change_claims` and `lat_events`.
- **The five names** added to `:label_families` (8ddd92d2).
- **The applies:** `--apply` for the round, then EP, Occupational and Maritime, whose labels were stale on the fold version after 21398df5 and 1fd1c6c3. Log: `fire-and-ohs-apply.txt`.
- **Applied:** 527 laws written, 0 failed.

| Family | Laws | Time |
|---|---|---|
| Fire and OH&S | 139 | 209 s |
| EP | 122 | 924 s |
| Occupational | 149 | 168 s |
| Maritime | 117 | 200 s |

## After the apply

- **`--stored`:** 0 rows differ in every family.
  - Fire and OH&S: 139 laws, 26,133 rows, 50,103 periods.
  - EP: 122 laws, 34,802 rows.
  - Occupational: 149 laws, 18,453 rows.
  - Maritime: 117 laws, 24,285 rows.

  Saved in `fire-and-ohs-stored.txt` and the `-stored-*.csv` files.
- **`lat.stale --strict --switched`:** exit 0, with 0 of 527 switched laws stale. The change register shows 0 of 544 stale.
- **`mix test`:** 11,283 passed, 2 skipped.

## Step close (2026-11-17)

`mix lat.step_close --family "Fire and OH&S" --step "Switch-over"` passes. Every step's gate passes: Sources, the Feed, Markup, Commencement, Extent and Amending-law readers, Merge, Evidence and the Label fold. So do the Checked rows, and Stale laws: Fire and OH&S has 0 stale laws, and the switched families 0 of 527. Report: `switch-over/fire-and-ohs-step-close-2026-11-17.txt`.

## Docs changed

- **WORKFLOW step 13:** a Fire and OH&S note.
- **The `switch-over-check` skill:** its history, and the text-gone scan for every family.
- **No RULES entry.** Decision 1 b names rows as known limits under the existing mechanism, and decides no new rule.

