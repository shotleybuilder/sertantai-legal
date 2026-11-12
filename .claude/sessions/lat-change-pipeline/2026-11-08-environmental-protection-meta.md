---
session: 'LAT Change Pipeline: Environmental Protection — Meta Session'
type: meta
status: active
opened: '2026-11-08'
family: '💚 ENVIRONMENTAL PROTECTION'
---

# Session: LAT Change Pipeline: Environmental Protection — Meta Session (ACTIVE)

## Problem

Environmental Protection is the third family through the LAT Change Pipeline, and the last run before production hardening (Maritime Safety retrospective, Decision 3). It was chosen because its law is of a different kind from OH&S and Maritime Safety: Welsh, Scottish and Northern Ireland law, and EU retained environmental law. The register holds 395 live UK laws in the family, of which 59 have LAT rows; Making laws will add more. This session runs the delivery step by step and records each step's status for the retrospective. It stays ACTIVE until the family is switched over.

## Todo

- ✅ Making laws (step 0): 116 making, all with LAT rows (63 parsed); 21 no verdict (5%); closed 2026-11-08
- ✅ Sources: gate PASS after a build, 1,422 needs held or absent; 16 register statistics re-scraped (2 laws became revoked: 114 live making); closed 2026-11-08
- ✅ Feed reader: 11,674 effects, our faults 0, 6,386 placed; Decisions 1–4; three reader faults fixed; closed 2026-11-09
- ✅ Markup reader: 3,251 changes, our faults 0 (from 134); a scoped law read for its scope; three reader-side fixes; Decisions 1–4; closed 2026-11-09
- ✅ Commencement reader: 35,518 rows, our faults 0 on stored rules (from 9,954), leftovers 23 → 0; ten reader forms, two check errors, an order-store overlap fixed; Decisions 1–2; closed 2026-11-09
- ✅ Extent reader: 8,243 changes, our faults 0 (from 295), causes not named 231 → 0 (139 known); bound by the law's text 45% → 74%; 15 wordings, the powers parser, a check error and one wrong bound fixed; Decisions 1–6; closed 2026-11-10
- ✅ Amending-law reader: gate PASS, 240 groups named (from 230 of 280 not named); A 2,950 → 3,192, L 536 → 391; 13 misread classes fixed (an Order's articles, a Schedule's paragraphs, repeals-table items, quotes numbered in titles, levels, the modification wording); Maritime's parked group named; Decisions 1–2; closed 2026-11-10
- ✅ Merge: gate PASS (721 groups; EP 99 and OH&S's parked 83 named, 0 Merge faults in review); one agent pass found 2 classes; `joined_instruction` fixed (Decision 3) and two gate causes; Decisions 1–3; one rebuild of three families; closed 2026-11-10
- ✅ Evidence: gate PASS (59 groups named: EP 43, OH&S's parked 14, Maritime's 3; the table's order right, 154 wrong values the readers'); one agent pass found one class, the feed's "in accordance with" placeholder date, fixed in the table (Decision 4) with one rebuild of three families; Decisions 1–4; closed 2026-11-11
- ✅ Label fold: gate PASS for EP (13 → 0), OH&S (parked 1 → 0), Maritime; Decisions 1–9 (never before its maker, made period, versions, containers, Windsor checked, by-order dates unknown, pending by design); one agent pass found 2 fold classes, made gate checks and fixed; golden 27/27; closed 2026-11-11
- ✅ Measures: every published figure audited (same, moved with its commit, or parked); every check replicates at seed 1011; 4 gates or verdicts moved since their steps parked with them (Sources 69, Extent 2, Amending 4, one Making laws verdict); the inline reads of lat.sources and lat.vocabulary moved into tested modules; no agent pass; closed 2026-11-11
- ✅ Store and build: all 445 digests identical; 0 stale after 106 stale on older commencement readings were re-read and rebuilt; build time accepted (122 laws, about 5½ min, 1 worker); 6 gates pass, 3 fail as parked in Measures; restore copies moved to the restore schema, `--conflicts` order fixed; no agent pass; closed 2026-11-11
- ✅ Labels side by side: 69,136 periods, 0 breaking the table's rules; 35,766 rows = 13,229 agree + 17,872 differ today + 2,366 history only + 2,299 no stored timeline (baseline saved); territory alone the largest class (7,736); two runs identical; no code, no agent pass; closed 2026-11-12
- ✅ Switch-over
- ⬜ Retrospective and housekeeping (PENDING: `2026-11-10-environmental-protection-retrospective.md`, preliminary conclusions from the Amending-law reader day; then the review tooling session)

## Dependencies

- ✅ Maritime Safety switched (2026-11-07); retrospective closed with the order of work before Family 3 (Decision 3)
- ✅ The work before Family 3: the Mines Regulations 2014 → HSWA repair, #192, #191, #193, #194, #195, the commencement catalogue in the parallel read, and the parked owner bugs (pushed e2cbf9f5)
- ✅ Process: `session-start` "Step session", `docs/lat-change-pipeline/WORKFLOW.md` ("Running a new family"), `AIMS.md`, `RULES.md`

## How this session runs

- Each step is its own session, `.claude/sessions/lat-change-pipeline/<date>-environmental-protection-<step-name>.md`, titled "Environmental Protection: <Step name>". It is created when the step is reached, and starts in plan mode.
- This session holds only: which step is running, each step's status row, the decisions that cross steps, and pointers. Step detail stays in the step session.
- Each step's parked bugs (`open_bugs` by `step:`) and RULES.md's open decisions are read into that step's plan.
- Scope: the family's UK laws. The register's family also holds 23 Australian laws, which legislation.gov.uk does not publish; they are outside the pipeline.

## Step status

One row per step, filled when the step session closes. Agent tokens are those of agent checks and agent-run plan items.

| Step | Session | Opened | Closed | Days | Pass rule met | Plan changes | Bugs parked | Agent tokens | Commits |
|---|---|---|---|---|---|---|---|---|---|
| Making laws | making-laws | 2026-11-08 | 2026-11-08 | 1 | yes, all 6 | 0 (one classifier phrase moved to the commencement reader's words by the architecture test) | 2 (Commencement reader: EU "enter into force"; LAT parser: snapshot tables) + 3 not-making laws with rows (LAT parser, parking list) | 0 | 2 |
| Sources | sources | 2026-11-08 | 2026-11-08 | 1 | yes, all 5 | 0 (the explained-differences fixture wired within the pass rule) | 2 (Register: statistics capped at 1,000; LAT parser: rows for 2 now-revoked laws) | 0 | 2 |
| Feed reader | feed-reader | 2026-11-08 | 2026-11-09 | 2 | yes, all 6 | 0 (one law's body fetched, Decision 1, within the sources-held rule) | 3 open (Sources: scoped law needs its body; Feed reader: same-date stages, removal stage territory) + Tooling (credo-diff leftovers, #197); 4 fixed | 86,078 | 2 |
| Markup reader | markup-reader | 2026-11-09 | 2026-11-09 | 1 | yes, all 7 | 0 (the agent's new class fixed by Decision 3, a second cold catalogue run, within the pass rule) | 1 open (Tooling: the catalogue's full cold run is slow, #198) + 2 parking items (Feed reader: example rotation check; Markup reader: Z-number pattern names); 4 fixed | 152,593 | 5 |
| Commencement reader | commencement-reader | 2026-11-09 | 2026-11-09 | 1 | yes, all 6 | 0 (two fixes after the stored check — an order-store overlap, schedule-only rules — and one order form, within the pass rule; a second catalogue dry run) | 4 open (Commencement reader: order list wrong law, cited-orders overlap, fresh read without schedule effects, amenders list); 3 fixed (2 parked from OH&S/Maritime) | 0 | 2 |
| Extent reader | extent-reader | 2026-11-09 | 2026-11-10 | 2 | yes, all 6 | 0 (a second fix round and a second catalogue dry run after write 2, within the pass rule) | 1 open (Register: titles holding their year) + OH&S's stale build (existing parked bug) | 0 | 2 |
| Amending-law reader | amending-law-reader | 2026-11-10 | 2026-11-10 | 1 | yes, all 7 | 0 (the catalogue's three level classes fixed by Decision 2 and a quote-title class found after write 2, within the pass rule; write 3 of 3 laws on Jason's go; two zero-diff re-reads for the reader version) | 0 new; 2 fixed (the modification wording, Maritime's gate group); unnumbered list items re-parked; OH&S gate 91 → 88 | 0 | 2 |
| Merge | merge | 2026-11-10 | 2026-11-10 | 1 | yes, all 6 (OH&S U 16 → 17: the fix's one place left apart, by the fix's rule) | 0 (the agent's two classes become gate groups, and the fix, within the pass rule: Decision 3) | 4 open (Amending-law reader: list items read twice, whole-law rule makes no change; Feed reader: `#made` records; Markup reader: note citation read short); 2 fixed (OH&S gate, the lent-event class) | 179,044 | 2 |
| Evidence | evidence | 2026-11-10 | 2026-11-11 | 2 | yes, all 6 | 0 (the agent's class fixed in the table by Decision 4, within the pass rule; the rebuild's bare "OH&S" also built 40 laws of three other OH&S families, kept) | 4 open (Commencement reader: order in list read whole, order item read partial, clause exception date unread; Amending-law reader: as-it-applies territory read short); 2 fixed (OH&S gate, the feed Type error as a known limit) | 155,068 | 2 |
| Label fold | label-fold | 2026-11-11 | 2026-11-11 | 1 | yes, all 6 | 0 (the agent's two fold classes made gate checks and fixed by reach, within the pass rule; Decisions 7–9 after the review) | 6 open (Register: Welsh SIs under UK names; Commencement reader: undated insertion unjoined, territorial by-order read qualified; Amending-law reader: Part revoked read as whole law; Feed reader: Other-qualification territory, Title locator); 7 fixed (OH&S gate, undated change before its law, J6, J4, Windsor, SI 1998/1258, HSWA s.78) | 427,919 | 2 |
| Measures | measures | 2026-11-11 | 2026-11-11 | 1 | yes, all 5 | 0 (no agent pass by Jason's word at the start: the plan's hand check replaced before approval) | 4 open (Sources: 69 failures; Extent reader: 2 causes; Amending-law reader: 4 groups; Making laws: UK_asp_2024_14 verdict); 1 fixed (the inline reads in lat.sources and lat.vocabulary) | 0 | 2 |
| Store and build | store-and-build | 2026-11-11 | 2026-11-11 | 1 | yes, all 6 | 0 (one extra re-read mode, cited orders, for 3 orders the named-law mode does not find; within the step's "re-read in the mode that wrote them") | 1 open (Making laws: making.resolve copies to public); 2 fixed (restore copies, `--conflicts` order) | 0 | 2 |
| Labels side by side | labels-side-by-side | 2026-11-12 | 2026-11-12 | 1 | yes, all 5 | 0 | 0 new; 1 parking item (Switch-over: territory-only differences first) | 0 | 1 |
| Switch-over | switch-over | 2026-11-12 | 2026-11-12 | 1 | yes, all 7 (checked rows: 22 changed by earlier steps, parked) | 0 (Decisions 1–3 with leave; two over-reaches of Decision 3's fix caught by golden and the checked rows and narrowed to its stated intent; 59 parser-stale laws re-parsed on Jason's go) | 6 open (Register: Welsh SIs twice; Amending-law reader: territorial stages as stages; Switch-over: shadow misses containers; Commencement reader: partial order dates in full, 22 checked rows; Label fold: Windsor NI insertion, 2 rows; and the 2 known-limit classes) + 2 fixed in-step | 0 | 3 |
