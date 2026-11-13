---
session: 'Fire and OH&S: Making laws'
status: closed
opened: '2026-11-13'
closed: '2026-11-13'
family: Fire and OH&S (round)
step: Making laws
outcome: success
summary: 'Step 0 for the first QQ round (five families, 219 live UK laws): every law decided from its own text,
  giving 133 making, 65 not making and 21 with no verdict (9.6%). 91 bodies were fetched; 39 making laws were parsed
  into LAT (34 of them offshore safety-zone orders, read making as designations by Jason''s Decision 1) and UK_asp_2024_14
  re-parsed; the round''s 100 parser-stale laws were re-stamped with 0 rows changed. Every making law holds rows,
  and the step close passes but for EP''s 22 parked checked rows.'
decisions:
- what: Offshore Installations (Safety Zones) Orders read making (Decision 1, b)
  why: a zone has legal effect of its own (the Petroleum Act 1987 s.23 forbids entry); all 34 are in force
  result: the :designation kind; 34 orders making, 34 parsed (1,035 rows with the other 6 laws)
- what: 'Fire and Rescue National Framework Order 2012: its review stands, making (Decision 2)'
  why: the Framework has effect the shall/must rule cannot see; review outranks text
  result: no write; text verdict none, in the checked fixture as nil
- what: NI Explosives (Hazard Information and Packaging for Supply) Regulations 2009 reviewed to making (Decision
    3)
  why: live duties (reg. 5A(1)); the enrichment said empowering
  result: making.review; is_making true; fractalaw to be told
- what: Fire Precautions (Factories, Offices, Shops and Railway Premises) Order 1989 reviewed to not making (Decision
    4)
  why: its one requirement is an exemption from a fire certificate
  result: making.review; is_making false; not parsed
- what: UK_asp_2024_14 recorded making and re-parsed (Decision 5, a)
  why: a parked Making laws bug; its text grew after its step
  result: is_making true; 7 scope rows re-stamped; its changes rebuilt and labels refreshed (EP is switched)
- what: Five misfiled laws refiled (Decision 6)
  why: 'none is EHS law; Jason: change or remove the family, with planning as family II for the trunk-road orders'
  result: '2 trunk-road orders to TRANSPORT: Roads & Vehicles with PLANNING & INFRASTRUCTURE as family II; 3 families
    removed; none parsed'
- what: The round re-parses its 100 parser-stale laws in this step (plan change, Jason)
  why: RULES family-re-parses-its-parser-stale-laws gives it to Making laws; the plan had left it out and the step
    close failed on it
  result: text diff 0 rows changed; re-parse 26,518 rows before and after, enrichment 8,812 kept; Stale laws PASS
metrics:
  laws:
    live_uk: 219
    not_uk: 80
    making: 133
    not_making: 65
    no_verdict: 21
    no_verdict_pct: 9.6
    is_making_disagreeing: 47
  sources:
    bodies_fetched: 90
    fetch_failed: 1
    no_provisions_upstream: 15
  parse:
    laws: 40
    rows: 1035
    errors: 0
  restamp:
    laws: 100
    rows: 26518
    rows_changed: 0
    enriched_kept: 8812
  checks:
    checked_laws: 72
    agree: 70
    decided_by_jason: 2
    report_runs_identical: true
    tests: 10806
    failures: 0
    step_close: Stale laws PASS; Checked rows 22 failing (parked in EP)
  cost:
    days: 1
    plan_changes: 1
    agent_tokens: 0
    commits: 2
lessons:
- title: Read a step's RULES before planning it, not only its last session
  detail: The plan copied Environmental Protection's todos and missed RULES family-re-parses-its-parser-stale-laws
    (added after EP's step). The step close caught it (100 stale laws) and it cost one plan change. A step's plan
    reads its RULES section for duties as well as its parked bugs.
  tag: tooling
- title: A round shows a family class that one family hides
  detail: One family's designation is a one-law known limit (SSI 2026/57). The Offshore Safety family has 34 safety-zone
    orders, all worded alike, so it became a form with a decision. Rounds turn known limits into measured classes.
  tag: data
- title: A lead-in's verb is in its items
  detail: Text.instruction leaves out sub-provisions with their own id, so "shall–" with its items read as a bare
    requirement (SSI 2006/475 art. 3). Read the items with the lead-in.
  tag: data
bugs:
- pattern: mix making.resolve copies legal_register to making_backfill_snapshot_<YYYYMMDD> in public before an apply
    (the restore-tables-in-public class)
  category: restore-points
  module: Mix.Tasks.Making.Resolve
  affected: 1 task
  fix: Restore.copy!/4 into restore.making_resolve_<stamp>__legal_register; restore_test fails on any CREATE TABLE
    AS outside Restore
  step: Making laws
  status: fixed
- pattern: 'UK_asp_2024_14 (Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024) read no verdict
    (''changes and powers'') at the step; today it reads making (28 own requirements, first s.17(1)) against a stored
    is_making false, with no LAT rows: its stored text grew after the Sources re-scrape'
  category: making-verdict-stale-text
  module: data (Making.record, lat.reparse)
  affected: 1
  fix: recorded making and re-parsed (Decision 5)
  step: Making laws
  status: fixed
- pattern: Six laws decided not making from their text still hold LAT rows (nisr_2012_177, ssi_2010_393, uksi_1974_2013,
    uksi_2006_1521, uksi_2023_284, uksi_2023_861)
  category: not-making-with-rows
  module: LatArchive discard
  affected: 6
  fix: discard their rows with the LAT parser, as Environmental Protection's three
  step: LAT parser
  status: open
- pattern: mix lat.reparse left lat_reparse_<tag> snapshot tables in public again (lat_reparse_making_fire_and_ohs[_cm],
    lat_reparse_restamp_fire_and_ohs[_cm])
  category: restore-points
  module: Scraper.LatReparse.snapshot!/2
  affected: 4
  fix: 'as issue #189 (Restore.copy!/4); Jason to drop the four tables'
  step: LAT parser
  status: open
  issue: 189
- pattern: Five laws were misfiled in the Fire families (A30 and A5 trunk-road orders, City of Sheffield (Mayoral
    Referendum) Order 2012, Isles of Scilly (Members' Allowances) Order 1991, UK_ukpga_1924_5 Multiple Choices)
  category: register-misfiled
  module: uk_lrt.family
  affected: 5
  fix: refiled by UPDATE uk_lrt (Decision 6); the family graph edges not yet rebuilt (the family-QA skills' rebuild
    endpoint)
  step: Register
  status: fixed
- pattern: The family graph edges are not rebuilt after the Decision 6 refile of five laws
  category: register-edges
  module: the family-QA rebuild endpoint
  affected: 5
  fix: call the rebuild endpoint with the Phoenix server up
  step: Register
  status: open
artifacts:
- backend/lib/sertantai_legal/scraper/making_laws.ex
- backend/lib/mix/tasks/making.resolve.ex
- backend/test/sertantai_legal/scraper/making_laws_test.exs
- backend/test/sertantai_legal/scraper/making_laws_checked_test.exs
- backend/test/sertantai_legal/restore_test.exs
- backend/data/reports/making-laws/fire-and-oh-s.csv
- backend/data/reports/lat-reparse/making_fire_and_ohs.csv
- backend/data/reports/lat-reparse/restamp_fire_and_ohs.csv
- docs/lat-change-pipeline/RULES.md (section 0)
depends_on:
- 2026-11-13-round-scope.md
- 2026-11-13-fire-and-ohs-meta.md
enables:
- 'Fire and OH&S: Sources'
---

# Session: Fire and OH&S: Making laws (CLOSED)

## Problem

Step 0 for the first QQ round. It covers five families: FIRE; FIRE: Dangerous and Explosive Substances; and OH&S: Gas & Electrical Safety, Mines & Quarries and Offshore Safety. The round holds 219 live UK laws, and none has a making verdict read from its own text. The first read-only run gives:
- 95 making;
- 28 not making;
- 96 with no verdict (44%), 91 of those because their body is not held.

Every making law needs LAT rows, so that later steps can place changes on them.

## Todo

- ✅ Open the step session and its meta row; read the parked bugs in
- ✅ `making.resolve` writes its copy to the restore schema (`restore.making_resolve_<stamp>__legal_register`); a test in `restore_test.exs` fails on any `CREATE TABLE … AS` outside `Restore` (red on the old code; `lat_reparse` parked, #189)
- ✅ Read-only report run; two classifier forms fixed with tests by kind (a "shall–" lead-in read with its items; an aside of two parts); reach: 2 laws in the round, 0 in Environmental Protection and Maritime Safety
- ✅ Fetch the missing bodies (Jason's go): 91 laws, 1 failed (UK_ukpga_1924_5, "Multiple Choices": none upstream)
- ✅ Two report runs compared with `cmp` (identical); decisions written and decided (1 b; 2–4 as recommended; 5 a; 6 refile); checked laws into the fixture at close
- ✅ Restore point `making-laws-fire-and-ohs`; two reviews; `--apply` (198 verdicts round, 373 EP, 0 errors); refile of 5 laws; parse of 40 laws from the store (1,035 rows, 0 errors, labels refreshed)
- ✅ Rows: every making law holds rows (SI 1989/76 reviewed not making); 6 not-making laws with rows parked; step close: Stale laws PASS after the 100 parser-stale laws re-stamped (plan change; 0 rows changed), Checked rows 22 (parked in EP)
- ✅ Close: pass rule re-run (10,806 tests, 0 failures), RULES section 0, meta row, commits

## Pass rule (fixed)

1. The rule is unit-tested by kind, with any new forms the round shows.
2. The classifier agrees with every checked law held in the round. Those laws are added to `making_laws_checked_test.exs`, and each disagreement is decided by Jason.
3. All 219 live UK laws are accounted for, and the no-verdict list is at most 10%.
4. Two runs give a byte-identical CSV.
5. Every law decided making has LAT rows after the parse, or is named with a reason.
6. `mix test` passes with 0 failures, and the architecture tests pass before any write. Credo is clean and the hooks pass.
7. `mix lat.step_close --family "Fire and OH&S" --step "Making laws"` is recorded. Making laws has no gate, so it runs the checked rows and the round's stale laws.

**Golden and fixtures.** Golden (27 provisions) is untouched. The checked laws of Maritime Safety and Environmental Protection are frozen.

**Agents.** No agent QA.
- The summariser (Haiku) reads the long report and the logs.
- The clerk (Sonnet) does the paperwork and commits by path.
- The fixer is not used: Making laws is not one of its steps.

**Out of scope.**
- Other steps' code (bug-raise).
- Fetches beyond bodies.
- `lat_reparse` tables in public (LAT parser, #189).
- Australian laws: 80, which legislation.gov.uk does not publish.

**Time box.** One day.

## Parked bugs read in (step Making laws)

1. `making.resolve` copies `legal_register` to `making_backfill_snapshot_<date>` in public. It is fixed here (todo 2).
2. UK_asp_2024_14 (Environmental Protection, switched). It had no verdict at its step, and now reads making because its stored text grew, but it holds no rows. A decision for Jason, below.

## Dependencies

- ✅ Tooling: round scope (f4afb7e0)
- ✅ The plan, approved 2026-11-13

## Results so far (2026-11-13)

- **Report:** `backend/data/reports/making-laws/fire-and-oh-s.csv`, logged in `fire-and-oh-s-fetch.log`. After the classifier fixes, the scratchpad run gives:

  | Verdict | Laws |
  |---|---|
  | making | 99 |
  | not making: changes only | 93 |
  | no verdict | 27 (12%; the bound is 10%) |

- **The 27 no-verdict laws:**
  - 15 have no provisions upstream (scanned prints: 6 NI regulations, 2 Mines regulations, 4 Petroleum orders of 1924–37, 2 trunk-road orders, 1 more);
  - 7 are Offshore Installations (Safety Zones) Orders with no operative provision (Decision 1);
  - 4 are consequential orders with changes and powers;
  - 1 has no text.
- **Checked laws:** 72 in the round, 70 agree. The other two are Decisions 2 and 3.
- **Read by hand:** every law decided making on one or two requirements.
  - Two were misreads, now fixed as general forms:
    - SSI 2006/475 art. 3 is a saving, "shall– (a) remain in effect, (b) be deemed";
    - SI 1974/2013 reg. 6 is "shall, except …, or …, be construed".
  - The Fire Safety Act 2021 s.2(5) duty to consult stands as a requirement.
  - SI 1989/76 is Decision 4.
- **Reach of the fixes:** in the round, 2 laws move to not making, and nisr_2004_63 and uksi_1998_2451 each lose one counted requirement. Re-run read-only, Environmental Protection and Maritime Safety move no verdict. EP shows only UK_asp_2024_14 (Decision 5) and two laws no longer live.
- **Against the stored `is_making`:** 13 differ.
  - 7 making laws hold no rows, so they are candidates for the parse: apni_1929_13, eudr_2013_30, eur_2019_1148, nisr_2013_48, ssi_2005_342, uksi_1989_76 (Decision 4) and uksi_2012_332 (Decision 6).
  - 6 laws read not making but hold rows: nisr_2012_177, ssi_2010_393, uksi_1974_2013, uksi_2006_1521, uksi_2023_284 and uksi_2023_861. They are parked with the LAT parser, as in EP.

## Decisions for Jason

**Decision 1: the Offshore Installations (Safety Zones) Orders.** The round has 34. Each establishes 500-metre zones around named installations, and most revoke earlier orders. The text states no "shall": the offence of entering a zone is the Petroleum Act 1987's (s.23). Today 27 read "changes only" (their revocations) and 7 read no verdict, so the list stands at 12%. Aim: `binds-on-date` and `unknown-over-guess`.
- (a) A designation form ("A safety zone is established") reads not making. The duty is the Act's, and the order only says where it applies. All 34 orders are decided, and the list drops to 20 (9%).
- (b) Making, as designations with legal effect (like SSI 2026/57 by review). 34 small orders are parsed into LAT, zones that come and go.
- (c) Leave them as a known limit. The list stays at 12%, so pass rule 3 fails and a new plan is needed.

**Recommendation: (a).**

**Decision 2: Fire and Rescue Authorities (National Framework) (England) Order 2012.** Its review says making. Its text only gives the Framework effect ("shall have effect as a revision"), so it reads no operative provision. It holds rows.
- (a) The review stands: making, as SSI 2026/57, with the rows kept.
- (b) Correct the review to not making.

**Recommendation: (a).** Its effect is the Framework's, and the review outranks the text.

**Decision 3: Explosives (Hazard Information and Packaging for Supply) Regulations (NI) 2009.** Fractalaw's enrichment says "empowering". The text holds live duties: reg. 5A(1) says a supplier "shall not advertise … unless …". It holds rows, and enrichment outranks the text, so it would stay stored as not making, with rows.
- (a) A human review records making, and fractalaw is told.
- (b) Leave the enrichment as it is.

**Recommendation: (a).**

**Decision 4: Fire Precautions (Factories, Offices, Shops and Railway Premises) Order 1989.** It reads making on one provision: art. 5(1) says "a fire certificate shall not … be required for …". That is an exemption, not a requirement. The order designates premises under the Fire Precautions Act 1971.
- (a) A review records not making, a one-law wording and a known limit.
- (b) Making, and parsed.

**Recommendation: (a).**

**Decision 5: UK_asp_2024_14, the Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024** (Environmental Protection, switched; a parked Making laws bug). Its text grew after its step, and it now reads making with 28 own requirements, but it holds no rows.
- (a) Record making, parse its scope, and refresh its labels.
- (b) Leave it, named a known limit.

**Recommendation: (a).** It is one law.

**Decision 6: laws misfiled in the round's families.** These are the A30 and A5 trunk-road orders, the City of Sheffield (Mayoral Referendum) Order 2012, the Isles of Scilly (Members' Allowances) Order 1991 and UK_ukpga_1924_5 ("Multiple Choices").
- (a) Record their text verdicts, but keep them out of the parse. Park them with the Register for refiling.
- (b) Treat them as round laws: the Sheffield order is parsed.

**Recommendation: (a).**

## Parking list

- LAT parser: six laws decided not making still hold LAT rows: nisr_2012_177, ssi_2010_393, uksi_1974_2013, uksi_2006_1521, uksi_2023_284 and uksi_2023_861.
- Register: five laws are misfiled in the Fire families (Decision 6).

## Jason's decisions (2026-11-13)

1. **Safety zones: (b) making.** The designation form `@designation` ("safety zone(s) is/are (hereby) established") is a new kind, `:designation`, and reads making. All 34 orders are in force, by the register and by legislation.gov.uk. 15 have had zones revoked by later orders, but none is revoked whole.
2. **Decisions 2–4 as recommended:**
   - Fire and Rescue National Framework Order 2012: its review stands, making;
   - NI Explosives (Hazard Information) Regulations 2009: a review records making, and fractalaw is told;
   - Fire Precautions Order 1989: a review records not making.
3. **Decision 5: (a).** UK_asp_2024_14 is recorded as making and parsed. Environmental Protection is switched, so the parse refreshes its labels itself (`LabelRefresh`).
4. **Decision 6: the misfiled laws are refiled.**
   - The two trunk-road orders go to "💚 TRANSPORT: Roads & Vehicles", with family II "💚 PLANNING & INFRASTRUCTURE".
   - The Sheffield, Isles of Scilly and "Multiple Choices" laws have their family removed.
   - None of the five is parsed.

## Final report (two runs byte-identical)

| Verdict | Laws |
|---|---|
| making | 133 (34 by the designation form) |
| not making: changes only | 65 |
| no verdict | 21 (9.6%), of which: |
| · no provisions upstream | 15 |
| · changes and powers | 4 |
| · no operative provision | 1 (FRA National Framework Order 2012; its review stands) |
| · no text | 1 ("Multiple Choices", 404 upstream) |

- **Reach of the designation form:** Environmental Protection and Maritime Safety each move no verdict.
- **Tests:** compile with warnings as errors, the architecture, making-laws and restore tests (138) and `credo diff` all pass before any write.
- **The parse:** 40 laws, from the store. These are the 39 making laws in the round with no rows (34 safety-zone orders, apni_1929_13, eudr_2013_30, eur_2019_1148, nisr_2013_48 and ssi_2005_342) and UK_asp_2024_14. The Sheffield order and SI 1989/76 are left out.

## Apply and parse (2026-11-13)

- **Restore point** `making-laws-fire-and-ohs`, covering legal_register, legal_articles, lat_label_timeline, provision_changes, provision_change_claims and lat_events.
- **Reviews:** nisr_2009_273 recorded as making, uksi_1989_76 as not making.
- **Text verdicts:** `--apply` recorded 198 for the round and 373 for Environmental Protection, with 0 errors.
- **Refile:** the five misfiled laws were moved (Decision 6).
- **Parse:** `lat.reparse --store only` for 40 laws (tag `making_fire_and_ohs`) gave 1,035 rows and 0 errors. All 40 have `labels_refreshed`. UK_asp_2024_14's changes were rebuilt, and its 7 scope rows came back unchanged.
- **First step close:** Checked rows had 22 failing (the set parked in EP) and Stale laws had 100 (the round's laws parsed by older code). RULES `family-re-parses-its-parser-stale-laws` gives the stale laws to this step, so their re-parse was added as a plan change, with Jason's go:
  - the text diff showed 0 rows changed across 100 laws and no territory findings;
  - a restore point was taken, `making-laws-fire-and-ohs-restamp`;
  - the re-parse (tag `restamp_fire_and_ohs`) gave 26,518 rows before and after, kept the 8,812 enriched rows, and had 0 errors.
- **Second step close:** Stale laws PASS; Checked rows FAIL, 22 (parked in EP's Measures).
- **Full suite:** 10,806 tests, 0 failures.
- **For Jason:**
  - drop the four `lat_reparse_*` tables in public (#189);
  - tell fractalaw about the NI Explosives 2009 review (Decision 3).
- **Docs changed:** RULES section 0 (the designation form, a lead-in read with its items, the two-part aside, the known limits, and the round's figures).
