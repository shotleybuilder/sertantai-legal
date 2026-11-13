---
session: 'Fire and OH&S: Sources'
status: closed
opened: '2026-11-13'
closed: '2026-11-13'
family: Fire and OH&S (round)
step: Sources
outcome: success
summary: 'The Sources gate passes for the Fire and OH&S round after one build: 139 laws, 1,173 needs held or absent upstream, 0 failures, 0 register differences, two runs identical. The scoped-law body
  fix (Sources.own_paths/2) brought in Fire Precautions Act 1971''s body. Jason''s Decision 1 (b) also refetched and rebuilt the three switched families (all gates PASS), and Decision 3 (c) applied their
  3 laws'' moved labels.'
decisions:
- what: Fetch and rebuild the three switched families in this step (Decision 1, b)
  why: their gates had failed again, mostly sources stale by age (Occupational 330, EP 71, Maritime 24); Jason chose to clear them now rather than park
  result: 404 fetched, 0 failed; 388 laws rebuilt; gates PASS (1,226 / 1,369 / 675 needs)
- what: Re-scrape the round's 13 laws' register statistics (Decision 2, a), and the 2 switched laws the refreshed feeds moved
  why: every fresh figure equalled the stored feed; the register was behind
  result: 0 differences; SI 1994/232 became revoked, rightly (rows parked, LAT parser)
- what: Apply all three moved switched laws' labels (Decision 3, c)
  why: Jason's choice; two take new 2026 amendments, SI 2008/2337 takes a refreshed feed's per-regulation revocation
  result: --stored 0 differ in both families; SI 2008/2337 14 sub-rows in force, parked with the Label fold
- what: A scoped law's own-text need is its body
  why: the build and the readers read the body; a fragment-only law built 0 changes silently
  result: 'Fire Precautions Act 1971: 249 changes; EP and Maritime gates unchanged'
metrics:
  needs:
    laws: 139
    baseline: 568
    after_fix: 565
    after_build: 1157
    final: 1173
    failures: 0
    absent: 43
  fetched:
    round_1: 227
    retry: 2
    round_2: 225
    round_3: 3
    after_rebuild: 1
    switched: 408
    failed: 0
  build:
    laws: 139
    changes: 29288
    seconds: 49
    no_changes: 22
  switched:
    rebuilt_laws: 388
    label_rows_moved: 28
    stale_stamps_refreshed: 24
  register:
    differences: 15
    rescraped: 15
    became_revoked: 1
  checks:
    gate_runs_identical: true
    tests: 10808
    failures: 0
    golden: 27/27
    checked_rows_changed: 22
    step_close: Sources PASS; Checked rows 22 (EP); Stale laws 49 (Commencement reader)
  cost:
    days: 1
    plan_changes: 1
    agent_tokens: 0
lessons:
- title: The index closes a bug only on 'fixed'
  detail: open_bugs matches exact pattern text and ignores 'moved'; a moved bug stays open unless its entry is marked fixed (with a note) and a new open entry is raised under the new step
  tag: tooling
- title: A refreshed feed can change an effect's form, not only its count
  detail: SI 2008/2337's whole-law revocation became per-regulation revocations with no level, so a rebuild moved a revoked law's sub-rows to in force; check --stored after any switched rebuild before applying
  tag: data
- title: The register re-read rewrites feeds after the build
  detail: the dry-run StagedParser :amended_by wrote Petroleum Act 1998's feed after the round's build, so lat.stale flagged it; rebuild after the re-scrape, as WORKFLOW says, even when the counts already
    matched
  tag: data
bugs:
- pattern: 'An SI''s introduction counts as held when its enabling cache file exists, even as `[]` with no introduction stored (e.g. SI 2004/929, 1998/2241: 12 Maritime amenders), so the Sources gate passes
    with their powers unreadable'
  category: enabling-cache-empty-counts-held
  module: lib/mix/tasks/lat.sources.ex (status/2, :introduction)
  affected: 12 laws (Maritime Safety)
  fix: 'held only with the made introduction in the CLML store, or a parse that found provisions — fixed at Environmental Protection: Sources (Sources.introduction_status/2), re-logged under this exact
    pattern 2026-11-13'
  step: Sources
  status: fixed
- pattern: 'Schedules of amending laws not held (KS): SI 2019/720 Sch 2''s substituted CLP articles make new numbers that get no insertion (Art 2(15), 37(7)-(9), 52(5)-(6)); EPA 1975 Sch.15 (HSWA s.28(9))'
  category: upstream (CV-S09)
  module: CLML store / Amendment.Reader
  affected: CLP-wide; HSWA s.28(9)
  fix: 'Sources part done: both schedules held (uksi/2019/720/schedules, ukpga/1975/71/schedules); reading them re-raised to the Amending-law reader (amending-schedules-held-not-read)'
  step: Sources
  status: fixed
- pattern: 'S01 sources gate fails today: 103 needed documents not fetched (OH&S, 2026-10-30), 96 of them EU amenders of REACH (70) and CLP (26) — territory bodies and introductions; 7 UK. CV-S01 passed
    with 0; the needs grew with later steps and nothing re-ran the gate'
  category: workflow / sources gate
  module: mix lat.sources (CV-S01); CV-S11 'sources check re-run after each rebuild'
  affected: 103
  fix: 'superseded by the later OH&S Sources gate entry (ohs-gate-sources, 112 then 330), decided at Fire and OH&S: Sources Decision 1'
  step: Sources
  status: fixed
- pattern: 'Schedules of amending laws are held but not read for their insertions: SI 2019/720 Sch 2''s substituted CLP articles make new numbers that get no insertion (Art 2(15), 37(7)-(9), 52(5)-(6));
    Employment Protection Act 1975 Sch 15 (HSWA s.28(9))'
  category: amending-schedules-held-not-read
  module: Amendment.Reader
  affected: CLP-wide; HSWA s.28(9)
  fix: read the amending law's schedules (held in the store) as its instructions
  step: Amending-law reader
  status: open
- pattern: 'A law with LAT rows became revoked when its register statistics were re-scraped (SI 1994/232 Batteries and Accumulators (Containing Dangerous Substances) Regulations, revoked by SI 2008/2164,
    not yet applied to the text): LAT holds rows only for live making laws'
  category: rows-for-revoked-law
  module: LAT parse / discard (LatScope.exclude!/2 or a revoked-law discard)
  affected: '1 law, 60 rows (FIRE: Dangerous and Explosive Substances)'
  fix: discard the rows of laws decided revoked (archive first), as for not-making laws
  step: LAT parser
  status: open
- pattern: 'A whole law revoked provision by provision with no level stated keeps its sub-rows in force: the refreshed feed lists SI 2009/716''s revocation of SI 2008/2337 as reg.1–7 (was one whole-law
    effect), so 14 sub-paragraphs (reg.1(1), reg.2(a) …) of a revoked law read in force (labels written, Decision 3 (c))'
  category: revocation-listed-per-provision
  module: Label.reaches?/2 (or the feed reader's level for a revocation)
  affected: '1 law, 14 rows (OH&S: Occupational / Personal Safety)'
  fix: a revocation's level is the provision when the law is revoked whole or every top-level provision is revoked by the one law; then it reaches the rows under it
  step: Label fold
  status: open
- pattern: 'Sources counts a scoped law''s stored fragment as its own text, but the build (Build.body/1) and the readers need the body, so a scoped law with no body is skipped silently: 0 changes (Aggregates
    Tax (Scotland) Act 2024, scoped to s.64: its 132 feed effects unread until its body was fetched)'
  category: scoped-law-body-not-needed
  module: Sources.needs/2 (own text via LatScope.fetch_paths/3), lat.sources
  affected: 82 scoped laws without a stored body (register, 2026-11-08); 1 in Environmental Protection (fetched, Decision 1)
  fix: 'Sources.own_paths/2: a scoped law''s own-text need is its body (read by Sources.Held.law/1); Fire Precautions Act 1971''s body fetched, 249 changes; the other scoped laws fail their family''s gate
    at its Sources step'
  step: Sources
  status: fixed
- pattern: 'OH&S Sources gate: 112 parts not held (introductions and territory bodies not fetched, 3 own bodies stale), as at 2026-11-08'
  category: ohs-gate-sources
  module: sources (mix lat.sources --fetch)
  affected: 112
  fix: 'fetched (310, then 2) and the family rebuilt (Decision 1 b, Fire and OH&S: Sources); gate PASS, 1,226 needs'
  step: Sources
  status: fixed
- pattern: 'The Sources gate fails today for EP: 69 failures (47 feeds stale by age alone, fetched over 30 days ago; 4 backlog documents stale; 18 backlog Schedules needed since the read pass and the Evidence
    rebuild, not fetched, e.g. UK_nisr_2020_304 for UK_nisr_2011_239). It passed with 0 on 2026-11-08'
  category: sources-gate-not-rerun
  module: mix lat.sources --family F --fetch (ask Jason)
  affected: 69
  fix: 'fetched (70, then 2) and the family rebuilt (Decision 1 b, Fire and OH&S: Sources); gate PASS, 1,369 needs'
  step: Sources
  status: fixed
- pattern: 'The round''s 49 laws built at Fire and OH&S: Sources are stale for the commencement reader (their commencement reads predate the build), so the step close''s Stale laws fails 49'
  category: built-before-commencement-read
  module: mix lat.commencement (the mode that wrote them), then build
  affected: 49 laws (Fire and OH&S)
  fix: re-read the round at its Commencement reader step, then rebuild; the close re-checks
  step: Commencement reader
  status: open
artifacts:
- backend/lib/sertantai_legal/scraper/sources.ex (own_paths/2)
- backend/lib/sertantai_legal/scraper/sources/held.ex
- backend/test/sertantai_legal/scraper/sources/sources_test.exs
- backend/data/reports/sources/fire-and-ohs-*.txt, switched-*.txt, fire-and-ohs-build.log, fire-and-ohs-step-close.log
- docs/lat-change-pipeline/WORKFLOW.md (Sources)
depends_on:
- 2026-11-13-fire-and-ohs-making-laws.md
enables:
- 'Fire and OH&S: Feed reader'
---

# Session: Fire and OH&S: Sources (CLOSED)

## Problem

Step 1 of the Fire and OH&S round. Every document the round's 139 laws with rows need is held locally or known absent upstream: own text, feed, the amending laws' territory, introductions and enabling Acts, dates and backlog. The baseline has 568 needs with 228 failing, and only the 40 OH&S laws have been built, so most territory, dates and backlog needs are not yet visible.

Plan (approved 2026-11-13): `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`, `coverage-from-lgu`.
- **Time box:** one day.
- **Meta:** `2026-11-13-fire-and-ohs-meta.md`.

## Todo

- ✅ Open the step session and its meta row; baseline `backend/data/reports/sources/fire-and-ohs-0.txt`; parked bugs read in (empty introduction fixed, KS schedules moved, the 103 entry moved); Decision 1 written
- ✅ Fix `scoped-law-body-not-needed`, test first: `Sources.own_paths/2` (a scoped law needs its body), read by `Sources.Held.law/1`; round own needs 142 → 139, Fire Precautions Act 1971 body now needed (`-1.txt`: 565 needs, 229 failing); EP and Maritime gates unchanged by it
- ✅ Fetch round 1 (Jason's go): 229, 227 fetched, 2 feeds 502 then fetched on retry; gate 567 needs, 0 failing after retry, 12 register differences (`-2.txt`)
- ✅ Restore point `sources-fire-and-ohs-build`; build the round once: 139 laws, 29,288 changes, 49 s (22 laws with no changes; Fire Precautions Act 1971 249 from its body); full-needs gate 1,157 needs, 225 failing (`-3.txt`)
- ✅ Full-needs gate; fetch rounds until 0 failures: round 2 225 fetched, 0 failed; round 3 the 3 enabling Acts the introductions named; gate 1,172 needs, 0 failing, 43 absent (13 dates, 30 backlog), 13 register differences (`-5.txt`). Switched families (plan change 1): fetching
- ✅ Register differences: 13; dry run (every fresh figure = the feed); Decision 2 (a): restore point `sources-fire-and-ohs-rescrape`, 13 re-scraped, SI 1994/232 became revoked (rightly; rows parked, LAT parser); no feed moved, no rebuild; round gate PASS, 1,172 needs, 0 failures, 0 differences (`-6.txt`)
- ✅ Pass: two gate runs identical; `mix test` 10,808 pass; step close: Sources PASS, Checked rows 22 (parked in EP), Stale laws 49 (parked: Commencement reader)
- ✅ Close: WORKFLOW Sources (scoped body; the round and the switched families), meta row, commits

## Pass rule (fixed)

1. Every needed document is held, or missing with a reason (no XML upstream, 404, out of scope); no fetch failure is left.
2. A held copy older than legislation.gov.uk's latest fails until it is refetched or explained.
3. Each stored feed matches the register's change statistics, or each difference goes to Jason (re-scraped or explained in `explained.json`).
4. The counting rules are unit-tested (the scoped-body fix included); two gate runs give the same report.
5. `mix test` 0 failures; architecture tests and the ratchet clean; hooks pass.
6. `mix lat.step_close --family "Fire and OH&S" --step "Sources"` recorded; a failure is parked with its owner.

Golden (27) and every family's checked-row fixtures are frozen.

## Dependencies

- ✅ Fire and OH&S: Making laws closed (133 making, 139 laws with rows)

## Parking list

- Commencement reader: built-before-commencement-read — the round's 49 built laws stale for the commencement reader (frontmatter).
- Label fold: revocation-listed-per-provision — SI 2008/2337's 14 sub-rows read in force under a per-regulation revocation with no level (frontmatter).
- LAT parser: rows-for-revoked-law — SI 1994/232 became revoked at the re-scrape and holds 60 rows (frontmatter).
- Amending-law reader: amending-schedules-held-not-read — SI 2019/720 Sch 2 and Employment Protection Act 1975 Sch 15 are held; reading them for insertions is the reader's.

## Baseline (2026-11-13, read-only)

| Need | Needed | Held | Failing |
|---|---|---|---|
| own text | 142 | 116 | 26 stale |
| feed | 138 | 3 | 39 not fetched, 96 stale |
| territory | 133 | 104 | 20 not fetched, 9 stale |
| introduction | 76 | 47 | 29 not fetched |
| enabling parent | 13 | 12 | 1 |
| dates | 13 | 8 (+3 absent) | 2 |
| backlog | 53 | 46 (+1 absent) | 6 |

568 needs, 228 failing; 30 feeds differ from the register's change statistics (most not fetched yet). Fire Precautions Act 1971 is scoped (4 fragments) and holds no body, so it would build 0 changes (the parked `scoped-law-body-not-needed`).

## Decisions

### Decision 1. The switched families' Sources gates — DECIDED (b), 2026-11-13

- **Question.** The Sources gates of the three switched families fail again: Occupational / Personal Safety 330 failures (112 on 2026-11-08), Environmental Protection 71 (69 on 2026-11-11). Maritime Safety fails too: 24 (it passed on 2026-11-04). Most are feeds and bodies stale by age (fetched over 30 days ago), plus needs added by later steps. Fetch and rebuild them now, or park them?
- **Aim:** `coverage-from-lgu`, and scope held (a step's work stays in its step).
- **Options:**
  - (a) Park one bug, "a switched family's sources age out", for production hardening (Store and build): a recurring refresh, followed by a rebuild and a switch-over re-check of the laws whose sources moved. Size: 330 + 71 + 24 failures.
  - (b) Fetch the three families' failures and rebuild their changes now. A fetch alone leaves their stored changes one feed behind; the rebuild moves switched labels, which needs a switch-over re-check inside this step.
- **Recommendation:** (a). The refresh is a standing job for switched families, not a Sources fix for this round; (b) does Store and build and Switch-over work inside a Sources step.

**Decided (b)** (Jason, 2026-11-13): fetch the three switched families' failures and rebuild their changes in this step.

## Plan change 1 (Decision 1 b, 2026-11-13)

The approved plan held the switched families out of scope; Jason's Decision 1 (b) brings them in. Added to todos 4–6, and to the pass rule:
- **Fetch:** `mix lat.sources --family F --fetch` for Occupational / Personal Safety (330), Environmental Protection (71) and Maritime Safety (24), with rounds until each gate is 0 failures, as for the round.
- **Rebuild:** one restore point of `provision_changes,provision_change_claims,lat_events` before any build (the round's and the three families'); then `mix lat.vocabulary --build --family F` for each, under `systemd-run … MemoryMax=12G`.
- **Labels:** a rebuild writes only the change tables; the switched labels in `lat_label_timeline` move only at `mix lat.label_switch --family F --apply`. So the re-check is a dry run, read-only: `mix lat.label_switch --family F --stored` (rows differing from the stored timeline, law by law), `mix lat.label_checked --list` and `mix lat.vocabulary --golden` (27/27). Whether to apply, and what to do with any rows that move, is Decision 3, with a restore point of `lat_label_timeline` before any apply.
- **Pass rule, added:** each switched family's Sources gate passes (0 failures, its register differences re-scraped or explained); golden 27/27 after the rebuilds; the switched families' label movement is reported and decided (Decision 3).

## Register differences (2026-11-13)

After three fetch rounds the round's gate has 0 failures and 13 feeds differing from the register's change statistics (`-5.txt`). Dry run: the 13 laws' statistics re-read through the register's own stage (`StagedParser` `:amended_by`), no database write. Every fresh figure equals the stored feed: the register is behind, with no capped law this time.

| Law | Register stored (effects / laws) | Fresh = feed |
|---|---|---|
| UK_asp_2012_8 | 320 / 17 | 321 / 18 |
| NISR 1995/340 | 52 / 6 | 54 / 7 |
| NISR 1995/345 | 44 / 6 | 47 / 7 |
| NISR 1995/87 | 3 / 2 | 6 / 3 |
| NISR 2004/63 | 3 / 3 | 13 / 4 |
| NISR 2014/224 | 12 / 3 | 63 / 4 |
| Pipe-lines Act 1962 | 175 / 47 | 182 / 48 |
| Petroleum Act 1998 | 391 / 45 | 393 / 46 |
| SI 1989/971 | 47 / 13 | 48 / 14 |
| SI 1994/232 | 8 / 3 | 7 / 2 |
| SI 1997/735 | 20 / 13 | 22 / 14 |
| SI 2002/2665 | 14 / 7 | 16 / 8 |
| SI 2015/385 | 15 / 8 | 17 / 9 |

### Decision 2. Re-scrape the 13 laws' register statistics? — DECIDED (a), 2026-11-13

- **Question.** Write the fresh change statistics for the 13 laws through the register's own path?
- **Aim:** `coverage-from-lgu`: the register's statistics are the check that each stored feed is complete.
- **Options:**
  - (a) A restore point of `legal_register`, then `persist_direct` with the `:amended_by` stage only (as Maritime and Environmental Protection), printing each law's live status before and after (the stage runs `LiveStatus`, which can re-decide it); rebuild any law whose stored feed moved in the dry run; re-gate.
  - (b) Leave them, each explained in `explained.json` as "register behind the feed".
- **Recommendation:** (a). 13 small writes; the gate then compares like with like, and a law the re-read finds revoked is caught now, not at Switch-over.

## Switched families (plan change 1, 2026-11-13)

| Family | Gate before | Fetched | Gate after fetch | Register differences | Re-scraped |
|---|---|---|---|---|---|
| OH&S: Occupational / Personal Safety | 330 failing | 310, 0 failed | 1,224 needs, 0 failing | 1 (SI 2012/632: 14 → 17) | yes, live unchanged |
| Environmental Protection | 71 | 70, 0 failed | 1,367 needs, 0 failing | 1 (SI 2015/1947: 81 → 91) | yes, live unchanged |
| Maritime Safety | 24 | 22, 0 failed | 675 needs, 0 failing, PASS | 0 | — |

The two differences came from the refreshed feeds; each was dry-run first (fresh = feed) and re-scraped under the Decision 2 restore point.

**Rebuilds** (restore point `sources-fire-and-ohs-build`): Occupational 149 laws in 32 s, EP 122 in 191 s, Maritime 117 in 21 s. After them, Occupational and EP each needed one new 2026 amender (SI 2026/1153 for SI 2012/632; SI 2026/1171 for SI 2015/1947), body and introduction: fetched, and the two laws rebuilt. Gates: Occupational PASS (1,226 needs), EP PASS (1,369), Maritime PASS (675); 0 failures, 0 register differences each (`switched-*-4.txt`, Maritime `-3.txt`).

**Labels, read-only** (`mix lat.label_switch --family F --stored`, the switch's rows against the stored timeline; csvs in the scratchpad):

| Family | Rows | Differ | Laws |
|---|---|---|---|
| OH&S: Occupational / Personal Safety | 18,453 | 21 | SI 2008/2337 (14), SI 2012/632 (7) |
| Environmental Protection | 34,802 | 7 | SI 2015/1947 (7) |
| Maritime Safety | 24,285 | 0 | — |

- **SI 2012/632 and SI 2015/1947:** new effects from two 2026 amenders (SI 2026/1153, SI 2026/1171; not in the register yet), dated 6 and 25 November 2026 and one in 2027. These are right.
- **SI 2008/2337** (a CHIP amendment, revoked by SI 2009/716): the old feed held one whole-law revocation (`*`), which reached every row (repealed, saved). The refreshed feed lists the revocation regulation by regulation (reg.1–7), with no level stated. By `a-change-whose-level-no-source-states` it reaches no sub-paragraph, so 14 rows (reg.1(1), reg.2(a) …) would go back to in force. This is wrong: the law is revoked whole.

### Decision 3. Apply the switched labels that moved? — DECIDED (c), 2026-11-13

- **Question.** Write the new labels for the three laws whose rows moved after the rebuild?
- **Aim:** `binds-on-date`: the labels answer "does it bind me on the date I pick".
- **Options:**
  - (a) A restore point of `lat_label_timeline`, then `LabelRefresh.run/1` for UK_uksi_2012_632 and UK_uksi_2015_1947 (what `lat.label_switch --apply` runs per law; 14 rows, new amendments), and `--stored` re-run to show 0 differing on them. SI 2008/2337 keeps its stored labels, and the misread is parked with the Label fold: `revocation-listed-per-provision`, a whole law revoked provision by provision with no level, whose sub-rows stay in force.
  - (b) Apply nothing now. The three laws differ from their changes until the Label fold's next step.
  - (c) Apply all three, the 14 wrong rows included.
- **Recommendation:** (a). The two right updates go in now; the wrong one is held and parked with its owner.

**Decided (c)** (Jason, 2026-11-13): apply all three. Restore point `sources-switched-labels` (`lat_label_timeline`); `LabelRefresh.run/1` for SI 2008/2337, SI 2012/632 and SI 2015/1947, all `:ok`. `--stored` re-run: Occupational 18,453 rows, 0 differ; EP 34,802, 0 differ. SI 2008/2337's 14 sub-rows now read in force; the misread is parked with the Label fold (`revocation-listed-per-provision`).

**After the rebuilds:** golden 27/27; checked rows 744: 674 match, 47 known, 1 upstream, 22 changed (the same 22 parked in Environmental Protection; none new). `mix lat.stale --strict --switched`: 49 built laws stale for the commencement reader (the next steps' input), 1 law text, 1 feed.

**Stale after the rebuilds** (`mix lat.stale --list`): 24 switched laws' labels stale by stamp only (19 Occupational, 5 EP: fold inputs or build time moved by the fetches and rebuilds; `--stored` 0 rows differing). Jason: refresh. `LabelRefresh.run/1` for the 24, all `:ok`; `mix lat.stale --strict --switched`: switched families 0 of 388. Two of the round's laws were change-register stale after the re-scrape (Petroleum Act 1998: its feed rewritten by the register re-read; NISR 2012/177: law text): rebuilt (1,783 and 29 changes). The Petroleum Act's rebuild needed one backlog Schedule (SI 2018/797): fetched. The 49 laws stale for the commencement reader are the next steps' input.

## Pass (2026-11-13)

- Round gate PASS: 139 laws, 1,173 needs, 0 failures, 0 register differences; two runs identical (`-11.txt`, `-12.txt`).
- Switched gates PASS: Occupational 1,226, EP 1,369, Maritime 675.
- `mix test`: 10,808 passed, 0 failures (2 skipped).
- Golden 27/27; checked rows 22 changed (the set parked in Environmental Protection).

## Step close (2026-11-13)

`mix lat.step_close --family "Fire and OH&S" --step "Sources"` (`backend/data/reports/sources/fire-and-ohs-step-close.log`):
- PASS Sources
- FAIL Checked rows: 22, the set parked in Environmental Protection
- FAIL Stale laws: 49, the round's laws built here, stale for the commencement reader; parked with the Commencement reader (frontmatter)

**Docs changed:** WORKFLOW Sources (a scoped law needs its body; the round and the switched families). No new rule for RULES.
