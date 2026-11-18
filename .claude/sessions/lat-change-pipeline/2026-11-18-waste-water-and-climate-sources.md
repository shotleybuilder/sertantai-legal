---
session: 'Waste, Water and Climate: Sources'
status: closed
opened: '2026-11-18'
closed: '2026-11-18'
outcome: success
family: Waste, Water and Climate (round)
step: Sources

summary: >
  The round's Sources gate passes: 565 laws, 4,523 needs held or absent upstream, 0 failures, 0 register
  differences, two runs identical, after one build, six fetch rounds (2,673 documents, the switched
  families' included) and a re-scrape of 119 laws' register statistics. Sources now needs an amending
  Act's order list where its own clause leaves provisions to orders, searching for the list by the
  register's title or the Act's own. The step close fails only on 224 laws stale for the Commencement
  and Extent readers, parked with them.

decisions:
  - what: "Decision 1 (b): an amending Act's order list only for Acts whose own clause leaves provisions to orders"
    why: "every listed order (a) added about 1,300 needs over five families, past the stop; the by_order / provision_by_order rules show which Acts' orders date anything"
    result: "216 needs in the round, 298 Fire and OH&S, 242 Occupational, 51 Maritime, 315 EP (556c5d6a)"
  - what: "Decision 2 (a): fetch the switched families' 117 own failures in this step, no rebuild"
    why: "under 15 minutes of fetching; a fetch moves no label"
    result: "all four switched families' gates PASS"
  - what: "Decision 3 (a): re-scrape all 119 register differences"
    why: "116 were the register behind; Jason accepted the two doubtful revocations until the Register fixes LiveStatus"
    result: "119 applied, 21 live statuses moved (14 newly revoked), the dry run's 21 law for law; 2 capped Water Acts explained"

metrics:
  gate: { laws: 565, needs_baseline: 1324, needs_after_build: 4523, failures: 0, register_differences: 0 }
  fetches: { rounds: 6, fetched: 2673, failed_unrecovered: 0 }
  build: { laws: 565, changes: 92537, seconds: 365, rebuilt_after_rescrape: 23 }
  rescrape: { laws: 119, live_changed: 21, newly_revoked: 14, doubtful: 2 }
  golden_extended: { pass: 41, of: 50, new_failures: 0 }
  mix_test: { passed: 11510, failures: 0, skipped: 2 }
  step_close: { sources: PASS, checked_rows: PASS, stale_laws: 224 }

lessons:
  - title: Most amending Acts are not in the register, so a title search needs the Act's own text
    detail: "fetch round 2's 5 order-list searches failed on no register title; Commencement.Order.title/1 from dc:title (as lat.commencement does) fixed them, less a repealed Act's '(repealed …)' note (515de15f)"
    tag: data
  - title: Keep the register-differences dry run as a script
    detail: "three rounds rewrote it from scratch; backend/scripts/sources/register_dry_run.exs now prints LiveStatus's reasons and has --apply, so the dry run and the apply are the same code (Jason 2026-11-18)"
    tag: tooling
  - title: Read LiveStatus's evidence before a re-scrape, not only its verdict
    detail: "the evidence (law_regions, revoked_regions, basis) showed two one-territory revocations read as whole when the law's regions were unknown; the verdicts alone looked plausible"
    tag: data
  - title: Each fetch round and rebuild reveals a few more needs
    detail: "searched order lists name orders, new introductions name parents, refreshed feeds point to newer backlog, a rebuild points to one more Schedule; expect rounds to shrink (1,154, 107, 27, 27, 1), not to end in one"
    tag: data
  - title: Read a stale list from its header line, not a guessed offset
    detail: "starting the per-law lines one line late missed 2 of the 23 feed/text-stale laws; they were caught by the re-check and rebuilt under the same restore point"
    tag: tooling

bugs:
  - pattern: "A Welsh title yields rules on both UK_uksi_2009_995 and UK_wsi_2009_995 (WSI 2015/1394 reg.2(6))"
    category: law-identity-two-types
    module: register / sources
    affected: 1 law pair
    fix: "moved to the Register: the register holds two rows for one Welsh SI (UK_uksi_2009_995 and UK_wsi_2009_995, the same title, both ENVIRONMENTAL PROTECTION); not Sources code (Waste, Water and Climate: Sources, 2026-11-18)"
    step: Sources
    status: fixed
  - pattern: "The register holds two rows for one Welsh SI, UK_uksi_2009_995 and UK_wsi_2009_995 (Environmental Damage (Prevention and Remediation) (Wales) Regulations), so a Welsh title yields amending rules on both (WSI 2015/1394 reg.2(6))"
    category: law-identity-two-types
    module: register (uk_lrt rows for one law under two type codes)
    affected: 1 law pair (Environmental Protection)
    fix: "keep the row legislation.gov.uk files the instrument under (wsi/2009/995) and retire the other, by type_code+year+number"
    step: Register
    status: open
  - pattern: "asp 2002/5's introduction states no Royal Assent date (empty DateText, no EnactmentDate)"
    category: royal-assent-not-stated-upstream
    module: (legislation.gov.uk)
    affected: 1 law
    fix: "named in RULES Known limits (Waste, Water and Climate: Sources, 2026-11-18): an upstream gap, not a fault"
    step: Sources
    status: fixed
  - pattern: "40 of the round's amending laws are not held (92 changes); NISR 1993/452 has no body held; SI 1993/2406 not held"
    category: amending-laws-not-held
    module: sources
    affected: 40 laws, 92 changes; 2 orders
    fix: "right by design in Sources (Waste, Water and Climate: Sources, 2026-11-18): all 91 changes of the 39 laws have no operation, which no label reads; the Commencement reader's list counts them (re-raised there as held-amenders-counts-non-text-changes). NISR 1993/452 has no provisions upstream (NumberOfProvisions 0); SI 1993/2406 is on the Offshore Safety Act 1992's own order list (the Commencement reader's orders_missing)"
    step: Sources
    status: fixed
  - pattern: "Commencement.HeldAmenders counts the amenders of every stored change, so its not-held list holds laws whose changes have no operation, which no label reads (Fire and OH&S: 39 laws, all 91 changes nil-op, e.g. SI 2005/849, 13 changes)"
    category: held-amenders-counts-non-text-changes
    module: Commencement.HeldAmenders (amenders/1)
    affected: 39 laws, 91 changes (Fire and OH&S)
    fix: "count only the changes with an operation, as Sources does (Sources.Held text changes)"
    step: Commencement reader
    status: open
  - pattern: "An Occupational amending SI's text is not held, so its changes have no bound (SI 2006/475, none:law_not_held, 2 changes)"
    category: amending-text-not-held
    module: lat.sources (Occupational)
    affected: 2 changes (Occupational)
    fix: "a known limit (Waste, Water and Climate: Sources): legislation.gov.uk holds no XML for SI 2006/475 (its body a stored 404, counted absent by Sources)"
    step: Sources
    status: fixed
  - pattern: "The Water Industry (Scotland) Act 2002's commencement orders are not held, so its changes to EPA 1990 are undated (s.53(2), (4), (5), (5A)) or dated from its enactment (s.45(10))"
    category: amending-act-orders-not-held
    module: sources
    affected: 5 EPA rows lose a dated change; asp 2002/3's 12 changes on EPA
    fix: "Sources needs an amending Act's order list's orders where its feed names none and its own clause leaves provisions to orders (Decision 1 b, 556c5d6a); fetched in this step's rounds"
    step: Sources
    status: fixed
  - pattern: "Environmental Protection's sources gate after this step's rebuilds: EU 2019/1010's Schedules not fetched (for EU Directive 2010/63), SI 2018/369's Schedules stale (for EA 1995): the backlog needs the rebuilt changes add"
    category: sources-fetch-failures-swept-each-step
    module: mix lat.sources --fetch
    affected: 2 documents (Environmental Protection)
    fix: "fetched in this step's rounds (Waste, Water and Climate: Sources, 2026-11-18); Environmental Protection's gate PASS after round 3 (switched-environmentalprotection-7.txt)"
    step: Sources
    status: fixed
  - pattern: "LiveStatus calls a law wholly revoked from one territory's revocation when the law's own regions are unknown (law_regions nil): SI 2008/2164 (UK extent) revoked for N.I. only by SI 2026/1053; SI 1998/3084 (E+W) revoked for England by SI 2009/46, Wales only in part"
    category: live-status-whole-from-one-territory
    module: LiveStatus (decide_whole, law_regions nil)
    affected: 2 laws in the round's dry run (229 LAT rows)
    fix: "with law_regions unknown, fall back to the law's recorded extent (geo_extent) before calling a one-territory revocation whole; else territorial with application_unknown"
    step: Register
    status: open
  - pattern: "The round's 210 laws built at Waste, Water and Climate: Sources are stale for the Commencement reader (their commencement reads predate the build), so the step close's Stale laws fails"
    category: built-before-commencement-read
    module: mix lat.commencement (the mode that wrote them), then build
    affected: 210 laws (Waste, Water and Climate)
    fix: "re-read the round at its Commencement reader step, then rebuild; the close re-checks"
    step: Commencement reader
    status: open
  - pattern: "The round's 126 laws built at Waste, Water and Climate: Sources are stale for the Extent reader (their amending laws' extent reads predate the build), so the step close's Stale laws fails"
    category: built-before-extent-read
    module: mix lat.amending --extents --amending A,B, then build
    affected: 126 laws (Waste, Water and Climate; 112 also stale for the Commencement reader)
    fix: "re-read the amending laws' extents at the round's Extent reader step, then rebuild; the close re-checks"
    step: Extent reader
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/sources.ex
  - backend/lib/sertantai_legal/scraper/sources/held.ex
  - backend/lib/mix/tasks/lat.sources.ex
  - backend/test/sertantai_legal/scraper/sources/sources_test.exs
  - backend/scripts/sources/register_dry_run.exs
  - backend/test/fixtures/sources/explained.json
  - backend/data/reports/sources/waste-water-and-climate-*.txt
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md

depends_on:
  - 2026-11-17-waste-water-and-climate-making-laws

enables:
  - "Waste, Water and Climate: Feed reader (step 2)"
---

# Session: Waste, Water and Climate: Sources (CLOSED)

## Problem

Step 1 of the second QQ round. Every document the round's 565 laws with LAT rows need is held locally or known absent upstream: own text, feed, the amending laws' territory, introductions and enabling Acts, dates and backlog. 373 of the laws were parsed in step 0 and have no stored feed, and none has been built, so the territory, dates and backlog needs are not yet visible.

Plan (approved 2026-11-18): `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`, `coverage-from-lgu`.
- **Time box:** two days.
- **Meta:** `2026-11-17-second-qq-round-meta.md`.

## Todo

- ✅ Open the step session and its meta row; parked bugs read in (two-row Welsh SI moved to the Register, asp 2002/5 a known limit); baseline gate (`-0.txt`)
- ✅ Fix Sources' own gaps, test first: the 39 not-held amenders all nil-op (right by design; re-parked with the Commencement reader); SI 2006/475 absent upstream; an amending Act's order list (Decision 1 b, 556c5d6a); reach measured; Decision 2 (a) fetches the switched families' 117
- ✅ Fetch round 1 (Jason's go): 786, 784 fetched, 2 feeds 500 then fetched on retry; gate 1,557 needs, 14 failing (orders from the searched lists), 119 register differences (`-2.txt`)
- ✅ Restore point `sources-waste-water-and-climate-build`; build the round once: 565 laws, 92,537 changes, 365 s (3 workers), 0 failed, 109 laws with no changes; full-needs gate 4,279 needs, 1,155 failing (`-3.txt`)
- ✅ Full-needs gate; fetch rounds until 0 failures: rounds 2–4 (1,594, 238, 27 fetched; the 5 order-list searches fixed, 515de15f); the round 0 failing documents (`-5.txt`), the four switched families PASS; EP's parked backlog fetched; NAS update done (`--data-only`, 1.9 GB; Jason 2026-11-18)
- ✅ Register differences: 119; dry run (116 behind, 1 a new effect, 2 capped; 21 live changes, 2 doubtful, parked with the Register); Decision 3 (a), restore point, all 119 re-scraped; rounds 5–6 (27 + 1); 2 capped explained; 23 laws rebuilt and 2 Maritime labels refolded (restore point `sources-waste-water-and-climate-rebuild`); round gate PASS (`-9.txt`)
- ✅ Checks: two gate runs identical; `mix test` 11,510 pass; architecture tests, Credo; extended golden 41/50 (same 9); step close: Sources PASS, Checked rows PASS, Stale laws 224 (parked: Commencement reader 210, Extent reader 126)
- ✅ Close: WORKFLOW Sources (an amending Act's order list, amenders from text changes, the kept dry-run script, the round's figures); RULES Known limits (asp 2002/5, SI 2006/475, NISR 1993/452); meta row; session close, index; commits by path

## Pass rule (fixed)

1. Every needed document is held, or missing with a reason (no XML upstream, a stored 404, out of scope); no fetch failure is left.
2. A held copy older than legislation.gov.uk's latest fails until refetched or explained.
3. Each stored feed matches the register's change statistics, or the difference goes to Jason (re-scraped or explained in `explained.json`).
4. The counting rules are unit-tested (the amender and order-list fixes included); two gate runs give the same report.
5. Every parked Sources bug is fixed, moved with a pointer, or named a known limit; the switched families' parked documents are held.
6. `mix test` 0 failures; architecture tests before any write; Credo ratchet clean; hooks pass.
7. Extended golden: no failure outside the baseline 9 (41/50).
8. `mix lat.step_close --family "Waste, Water and Climate" --step "Sources"` recorded; a failure is parked with its owner.

**Stop:** needs after the build over about 5,000 documents (3 hours' fetch), or a fix moving a switched family's needs by more than 50, go to Jason before the fetch.

The extended golden (50) and every family's checked-row fixtures are frozen.

## Dependencies

- ✅ Waste, Water and Climate: Making laws closed (544 making; 565 laws with rows), pushed 44f5fa9e

## Parking list

- Register: law-identity-two-types — two register rows for one Welsh SI (SI 2009/995) (frontmatter).
- Commencement reader: held-amenders-counts-non-text-changes — its not-held list counts amenders of nil-op changes (frontmatter).
- Sources: a Schedule paragraph's `LatRef.ancestors` lack the Schedule, so a feed order commencing "Schedule 7" is not matched to Sch.7 para.21 (`related?/2`); since 556c5d6a it falls back to the order list, so nothing is lost. Noted, not raised.
- Commencement reader: built-before-commencement-read — 210 round laws stale for the reader since the build (frontmatter).
- Extent reader: built-before-extent-read — 126 round laws stale for the reader since the build (frontmatter).
- Register: live-status-whole-from-one-territory — LiveStatus calls SI 2008/2164 and SI 1998/3084 wholly revoked from one territory's revocation (frontmatter).
- Commencement reader: `Order.title/1` keeps a repealed Act's note ("Control of Smoke Pollution Act 1989 (repealed 27.8.1993)"), so its title search misses; Sources strips it on its own side. One law seen. Noted, not raised.

## Parked bugs read in

| Bug | Where from | Here |
|---|---|---|
| `amending-laws-not-held`: 40 amending laws not held (92 changes); NISR 1993/452, SI 1993/2406 | Fire and OH&S: Commencement reader | todo 2 (code), fetched todo 5 |
| `amending-text-not-held`: SI 2006/475 | Fire and OH&S: Extent reader | todo 2, fetched todo 5 |
| `amending-act-orders-not-held`: asp 2002/3's orders | Fire and OH&S: Labels side by side | todo 2 (code) |
| `sources-fetch-failures-swept-each-step`: EP's 2 Schedules | Fire and OH&S: Store and build | fetched todo 5 |
| `law-identity-two-types`: SI 2009/995 two rows | Fire and OH&S: Amending-law reader | moved to the Register (not Sources code) |
| `royal-assent-not-stated-upstream`: asp 2002/5 | Fire and OH&S: Store and build | a known limit (RULES, todo 8) |

## Baseline (2026-11-18, read-only, `-0.txt`)

| Need | Needed | Held | Failing |
|---|---|---|---|
| own text | 565 | 500 | 3 not fetched, 62 stale |
| feed | 561 | 14 | 371 not fetched, 176 stale |
| territory | 86 | 71 | 15 |
| introduction | 38 | 16 | 22 not fetched |
| enabling parent | 6 | 6 | 0 |
| dates | 21 | 12 (+6 absent) | 3 |
| backlog | 46 | 38 | 8 not fetched |
| royal assent | 1 | 1 | 0 |

1,324 needs, 660 failing; 259 feeds differ from the register (most not fetched). Only the round's laws built earlier carry territory, dates and backlog needs.

## The parked bugs, measured (todo 2)

- **`amending-laws-not-held` (Fire and OH&S, now 39 laws, 91 changes): right by design in Sources.** Every one of the 91 changes has no operation (applied, modified, extended: no label reads them). Sources counts the amenders of text changes. `Commencement.HeldAmenders` counts every change, so its "not held" list is over-wide: that is the Commencement reader's list, not a Sources gap. Re-parked with the Commencement reader (todo 8).
- **NISR 1993/452:** its body is held, with `NumberOfProvisions="0"` (a scanned print). **SI 1993/2406** is on the Offshore Safety Act 1992's own order list, which the Commencement reader lists and fetches (`orders_missing.txt`). Neither is a Sources gap.
- **`amending-text-not-held` (SI 2006/475): right by design.** The body is a stored 404 (no XML upstream), which Sources counts as absent. A known limit.
- **`amending-act-orders-not-held` (asp 2002/3): a Sources gap, fixed test first, not yet committed.** `Sources.commencing/2` took an amending Act's orders only from its own feed. asp 2002/3's feed names none, so EPA 1990 s.53's undated changes needed nothing. Now, where the feed names no order for the provisions, every order on the Act's list (`Commencement.Orders.cached/1`) is needed, with its Schedules. Where no list is held, the list is needed (`:orders`), and `--fetch` searches for it (`Orders.for_act/4`). Four tests (`sources_test` "gap A or B: an Act whose feed names no order …").

**Reach (read-only, needs the fix adds; the round is not built yet, so its figure will grow):**

| Family | Added needs | Failing of them | Order lists to search |
|---|---|---|---|
| Waste, Water and Climate | 239 | 150 | 5 |
| Fire and OH&S | 362 | 219 | 17 |
| OH&S: Occupational | 307 | 175 | 17 |
| Maritime Safety | 75 | 37 | 7 |
| Environmental Protection | 341 | 193 | 17 |

That is past the stop (more than 50 in a switched family), hence Decision 1.

Apart from the fix, the switched gates also fail on 117 documents of their own, mostly amending laws' bodies stale since 2026-11-13: Fire and OH&S 30, Occupational 25, Maritime 5, EP 57 (`fire-and-ohs-13.txt`, `switched-*-5.txt`). Hence Decision 2.

## Decisions

### Decision 1. How far should an amending Act's order list reach? — DECIDED (b), 2026-11-18

- **Question.** When an amending Act's own feed names no order for an undated (or unrecorded) change, which of its orders does Sources hold?
- **Aim:** `binds-on-date`: an undated change is dated by the order that commenced it. `coverage-from-lgu`: a need only where a gap points to it.
- **What the stored rules show.** The Commencement reader has read most amending Acts' own clauses (`commencement_rules`). For EP's 17 Acts, 11 leave provisions to orders (`by_order` / `provision_by_order`, as asp 2002/3: "the rest … on such day as the Scottish Ministers may by order appoint"). 6 date every provision themselves (made-relative, Royal Assent or staged), so their orders date nothing.
- **Options:**
  - (a) **As built:** every order on the list. About 1,300 more needs over five families, about 770 fetches and 63 list searches.
  - (b) **Only the Acts whose own clause leaves provisions to orders:** the list's orders for an Act with a stored `by_order` or `provision_by_order` rule. An Act whose clause is unread needs its list only. A need appears once the clause is read, and the next step close's Sources gate sweeps it (`sources-fetch-failures-swept-each-step`). Fewer fetches. Which order commences which provision stays the order reader's.
  - (c) **Take the fix out and re-park it,** sized at these figures, for a later Sources step.
- **Recommendation:** (b). It holds the orders an undated change can be dated by and no others. It reads the reader's stored output, as Sources already reads extent rules, and never re-decides a provision.

**Decided (b)** (Jason, 2026-11-18).

### Decision 2. The switched families' own 117 failures — DECIDED (a), 2026-11-18

- **Question.** Fetch them in this step (fetch only, no rebuild), or park them?
- **Aim:** `coverage-from-lgu`.
- **Options:**
  - (a) Fetch them in this step's fetch rounds, with the Decision 1 orders. No rebuild: a fetch moves no label, and each family's next pass reads them.
  - (b) Park one entry per family with Sources, for its next pass.
- **Recommendation:** (a). It is under 15 minutes of fetching, and the gates then pass on what is held. The rebuild stays out of scope, as planned.

**Decided (a)** (Jason, 2026-11-18).

### Decision 3. Re-scrape the round's register statistics? — DECIDED (a), 2026-11-18

- **Question.** 119 stored feeds differ from the register's change statistics. Re-scrape them through the register's own stage, and which?
- **Aim:** `coverage-from-lgu` (the register's figures are legislation.gov.uk's); `binds-on-date` (the re-scrape re-decides live status).
- **The dry run** (`backend/scripts/sources/register_dry_run.exs`, no write; `waste-water-and-climate-register-dry.txt`, the 21 live changes with their reasons in `-register-dry-live.txt`):
  - 116 laws: the fresh figure equals the stored feed. The register is behind.
  - The Control of Pollution Act 1974: fresh 648 against the feed's 647. legislation.gov.uk added one effect today, and the dry run rewrote the feed, so the law needs a rebuild.
  - The Water Industry Act 1991 (feed 2,271) and the Water Resources Act 1991 (feed 1,120): the fresh figure equals the stored register figure (841 and 887). This is the known cap (register-stats-capped-at-1000, as EPA 1990), so a re-scrape changes nothing, and they go into `explained.json`.
  - **Live status: 21 of the 119 change.** Of the 21:
    - 6 move between in force and part revoked;
    - 1 becomes territorial: SI 1991/111, revoked in E and S, in force in W;
    - 14 become revoked, holding 853 LAT rows between them.
  - Read against each law's feed, 12 of the 14 revocations are right:
    - a devolved law revoked by its own legislature (NISR 1996/217, NISR 2003/259, SSI 2001/206, SSI 2004/289);
    - a Scottish-titled SI revoked by an SSI (SI 1991/346);
    - E, W and S all covered (SI 1989/744);
    - a UK-level revoker (SI 1992/575, 1998/1165, 2000/2911, 2004/639, 2005/2088, 2005/2748).
  - **2 look wrong**, because the law's own regions are unknown (`law_regions` nil), so one territory's revocation is taken as whole:
    - **SI 1998/3084**, the Water (Prevention of Pollution) (Code of Practice) Order (E+W, 6 rows): revoked for England by SI 2009/46 and only in part in Wales (WSI 2011/1012).
    - **SI 2008/2164**, the Batteries and Accumulators (Placing on the Market) Regulations (UK, 223 rows): revoked for N.I. only, by SI 2026/1053.

    This is the Register's code (`LiveStatus`), so the bug is parked (live-status-whole-from-one-territory).
- **Options:**
  - (a) Re-scrape all 119, accepting the two doubtful revocations until the Register fixes `LiveStatus`.
  - (b) Re-scrape 115:
    - leave out SI 1998/3084 and SI 2008/2164, explained in `explained.json` with a pointer to the parked bug;
    - leave out the two capped Water Acts, explained as capped.

    Then rebuild every law whose feed moved (`lat.stale`), and re-gate.
  - (c) Re-scrape none and explain all 119. That leaves the register a round behind legislation.gov.uk.
- **Recommendation:** (b). It writes only figures and decisions the dry run shows to be right, and it leaves no wrong live status in the register. The 14 newly revoked laws' rows join the class already parked with the LAT parser (rows-for-revoked-law, SI 1994/232).

**Decided (a)** (Jason, 2026-11-18): all 119 re-scraped. SI 2008/2164 and SI 1998/3084 are taken as revoked until the Register fixes `LiveStatus` (live-status-whole-from-one-territory, parked). The apply runs as the kept script's `--apply` (`LawParser.persist_direct`, as the scrape page), after restore point `sources-waste-water-and-climate-rescrape` (`legal_register`, 19,813 UK rows).

**Decision 1 (b), built** (`Sources.Held.by_order/1` reads the Act's own-clause rules; five tests). Reach, read-only (the needs the fix adds; failing = not fetched or stale):

| Family | Added needs | Failing | Order lists to search |
|---|---|---|---|
| Waste, Water and Climate (unbuilt) | 216 | 126 | 2 |
| Fire and OH&S | 298 | 178 | 11 |
| OH&S: Occupational | 242 | 128 | 6 |
| Maritime Safety | 51 | 16 | 3 |
| Environmental Protection | 315 | 170 | 11 |

Under (a) it was 1,374 needs and 63 searches. Most of what is left comes from large Acts that do leave provisions to orders (e.g. the Environment Act 1995).

## Fetch rounds

The full log of each round, the re-scrape and the rebuild is in `backend/data/reports/sources/waste-water-and-climate-fetch-rounds.md`.

| Round | Fetched | Failed | Gate after |
|---|---|---|---|
| 1 | 786 | 2, then fetched on retry | 1,557 needs, 14 failing (`-2.txt`) |
| Build | 565 laws, 92,537 changes, 365 s | 0 | 4,279 needs, 1,155 failing (`-3.txt`) |
| 2 (with the switched families) | 1,594 | 5 order-list searches: title fix 515de15f, then searched | 107 failing (`-4.txt`) |
| 3 | 238 | 0 | 0 failing documents; 119 register differences (`-5.txt`) |
| 4 (switched) | 27 | 0 | Fire and OH&S and Occupational PASS |
| Re-scrape (Decision 3 a) | 119 laws | 0 | 27 failing (`-6.txt`) |
| 5 | 27 | 0 | PASS (`-7.txt`) |
| Rebuild | 23 laws; 2 Maritime labels refolded | 0 | 1 failing (`-8.txt`) |
| 6 | 1 | 0 | **PASS**, 4,523 needs (`-9.txt`) |

The NAS data sync ran after round 4 and again after round 6.

## Checks (todo 7)

- **Repeatable:** two gate runs (`-9.txt`, `-10.txt`) are byte-identical (`cmp`).
- **Tests:** `mix test` 11,510 passed, 0 failures, 2 skipped (`waste-water-and-climate-mix-test.log`). The architecture tests passed before each DB write (23). Credo diff clean. Commit 515de15f passed its hooks.
- **NAS:** second data sync done, exit 0 (61,281 files, `-nas-2.log`).
- **Extended golden:** 41/50, the same 9 FAIL lines as the baseline (`diff` empty; `waste-water-and-climate-golden-extended.txt`).

## Step close (2026-11-18)

`mix lat.step_close --family "Waste, Water and Climate" --step "Sources"` (`backend/data/reports/sources/waste-water-and-climate-step-close.log`):
- PASS Sources: 4,523 needs, 0 failures, 0 register differences
- PASS Checked rows: 744 (696 match, 47 known, 1 upstream)
- FAIL Stale laws: 224. These are the round's laws built here, stale for the readers that have not yet run for the round: 98 for the Commencement reader alone, 14 for the Extent reader alone, 112 for both. Parked with the Commencement reader (210) and the Extent reader (126) (frontmatter), as at Fire and OH&S.

**Docs changed:** WORKFLOW Sources (an amending Act's order list and its search title; amenders counted from text changes; the kept register-differences script; the round's figures). RULES section 11 Known limits: one row for asp 2002/5, SI 2006/475 and NISR 1993/452. Decision 3 is a one-off choice, not a rule.
