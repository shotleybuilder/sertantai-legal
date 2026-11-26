---
session: 'Waste, Water and Climate: Extent reader'
status: closed
opened: '2026-11-26'
closed: '2026-11-26'
outcome: success
family: 'Waste, Water and Climate (round)'

summary: >
  Where the round's amending laws' changes apply is now read from their own words: the check PASSes (our faults 669 → 0, causes 135 → 0 not named, 302 known), bound by the law's text 40.9% → 68.4%. Fixed in the session, test first: same-extent and apart-from wordings, conditional extensions, the powers parser's named Act over a wrong link, five one-law forms, three older catalogue misreads and a savings statement; four writes, three cold catalogue dry runs, the four switched families PASS, golden 27/27.
  The step close passes every reader gate; checked rows (46, the Commencement reader's) and stale labels (565, Store and build's) are parked with their owners.

decisions:
  - what: "Decision 1: the Act an SI's powers clause names wins over a citation link pointing to another law, where the register holds the title once"
    why: "NISR 2017/88's link pointed to 1972 c.28 for the ECA 1972, binding 69 NI changes to E+W+S"
    result: "Diffed over 2,830 held introductions: 3 laws move, all gains (RULES powers-named-act-wins-over-a-wrong-link)"
  - what: "Decision 2: fix the five one-law wordings over the triage size now, as forms"
    why: "Each bore 10+ changes; an extension qualified within its place reads as the place (its upper bound), purpose limits are fractalaw's"
    result: "UpperBounds, AmendmentsOf, SameItems, PlaceApartFrom, ThoseProvisions modules; RULES extension-qualified-within-its-place-reads-as-the-place"
  - what: "Decision 3: fix the three older misreads the catalogue held (TULRCA 1992 s.301, 1981 c.22 s.97, 1996 c.44 s.14) now"
    why: "Read so since 2026-11-07; the catalogue dry run showed them as losses"
    result: "ExceptSame and the in_part regex; 5 held examples moved on accept"
  - what: "Decision 4: sweep Sources' 113 failures in this step (the plan had missed the rule)"
    why: "RULES sources-fetch-failures-swept-each-step; Jason chose to fetch now"
    result: "113 fetched, 0 failed, Sources PASS; one reading (NISR 2025/33) re-written, one law rebuilt"

metrics:
  check: { faults_before: 669, faults_after: 0, causes_before: 135, not_named_after: 0, known: 302 }
  bound_by_law_text: { baseline: "40.9%", after_write_1: "64.6%", final: "68.4%" }
  yardstick: { agree: 13257, law_wider: 2591, law_narrower: 136, law_narrower_baseline: 219, disjoint: 2, feed_only: 1437, law_only: 2086, neither: 6984 }
  catalogue: { new_patterns: 27, held_moved: 5 }
  writes: 4
  golden: "27/27"
  mix_test: 12749
  step_close: { sources: PASS, feed_reader: PASS, markup_reader: PASS, commencement_reader: PASS, extent_reader: PASS, checked_rows: "FAIL 46 (Commencement reader, parked)", stale_laws: "FAIL 565 (labels only; change register 0)" }

lessons:
  - title: The plan missed a standing rule's sweep
    detail: "RULES sources-fetch-failures-swept-each-step makes the Sources sweep the first todo after a failing close; the plan left it out and the step close found it. Read the previous close's FAIL lines into the plan."
    tag: tooling
  - title: A fetch can stale a reading
    detail: "Fetching NISR 2025/33's schedules added 2 extent rows; re-run the extent gate after any Sources fetch, before the close."
    tag: data
  - title: Read the check after every write
    detail: "Check 2 found a savings statement withholding two whole laws (195 changes), hidden under other causes before; it cost a third write."
    tag: tooling
  - title: A held catalogue loss may be an old misread
    detail: "Three dry-run losses had been read so since 2026-11-07; read_at on the stored rules told them apart from this session's fixes."
    tag: data
  - title: Switched families' rebuild surfaces other steps' drift
    detail: "Checked rows moved 46 with no extent reading changed: the Commencement reader's splits; trace a moved row's fields before owning it."
    tag: data

bugs:
  - pattern: "The extent preview counts a repeated unread row (same items, another source provision) as added, which the write drops: 3 laws show as changing every preview (e.g. ukpga 1982/48 s.79 by s.81)"
    category: preview-counts-duplicate-rows
    module: AmendingLaw.Extent.Write (preview diff)
    affected: 3 laws, no bound
    fix: "Compare the preview's rows as the write dedups them (kind, place, items)"
    step: Extent reader
    status: open
  - pattern: "1980 c.65's other Part statements left withheld: s.92 (dots before the words), s.101 (except so far as they repeal), s.125 (only sections … of the Part), s.133 (apart from this section), s.172; its 19 changes with no amending provision stay withheld"
    category: one-law-part-statements
    module: AmendingLaw.Extent (Units, Lists)
    affected: 19 changes, 1 law
    fix: "Under the triage size: named known; a form each if a later family reaches them"
    step: Extent reader
    status: open
  - pattern: "An Act stating extent lists only (\"the following … extend to Northern Ireland\", \"… do not extend to Scotland\") and no default gives its other provisions no bound (e.g. 1992 c.43 s.56: 14 changes)"
    category: list-only-act-no-default
    module: AmendingLaw.Extent.Default
    affected: 32 Acts read so; 14 round changes
    fix: "A rule for Jason: whether a list-only Westminster Act's other provisions take the whole UK less what the lists take away"
    step: Extent reader
    status: open
  - pattern: "OSRPA 1963's commencements by SI 1964/191 now read partial with no commencing law, so 32 checked rows lose 'in force 1964 by SI 1964/191' (in_force_partial) and the staged repeal by SI 1992/3004 opens a period later (e.g. ukpga 1963/41 s.18, s.10(2)); surfaced by this step's rebuild of the switched families, the extent readings unchanged"
    category: order-commencement-read-partial
    module: Commencement (order reader, its split 2026-11-24)
    affected: 32 checked rows, 1 law (Occupational)
    fix: "Trace SI 1964/191's rules before and after the order and clause reader splits; the covered-market exception (art.1) is a known minor caveat, not a partial start"
    step: Commencement reader
    status: open
  - pattern: "REACH (eur 2006/1907) Title 15A rows gain a UK period from 2020-12-18 by SI 2020/1577 before the GB period of 2020-12-31: the amendment to an earlier amending provision (SI 2019/758 Sch.2A, as inserted) dated by the amending SI's own date, not IP completion day; 14 checked rows; the extent readings unchanged"
    category: earlier-amending-provision-dated-by-amender
    module: Commencement.Amending (or Merge's date choice)
    affected: 14 checked rows, 1 law (Environmental Protection)
    fix: "An insertion into an amending provision not yet in force takes the earlier provision's date (IP completion day), as the checked rows hold"
    step: Commencement reader
    status: open
  - pattern: "The round's 126 laws built at Waste, Water and Climate: Sources are stale for the Extent reader (their amending laws' extent reads predate the build), so the step close's Stale laws fails"
    category: built-before-extent-read
    module: mix lat.amending --extents --amending A,B, then build
    affected: 126 laws (Waste, Water and Climate; 112 also stale for the Commencement reader)
    fix: "Written and rebuilt by writes 1–4; the change register 0 stale"
    step: Extent reader
    status: fixed
  - pattern: "The extent catalogue's fixture is behind the store: it read 4,239 laws on 2026-11-15, the store now holds 5,807 — a cold run shows 23 new patterns and higher counts, none gone"
    category: fixture-behind-store
    module: test/fixtures/extent_patterns
    affected: 1568
    fix: "Cold dry run and --accept (27 patterns)"
    step: Extent reader
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/extent/ (upper_bounds, amendments_of, same_items, place_apart_from, those_provisions, except_same)
  - backend/test/sertantai_legal/scraper/amending_law/extent/waste_water_climate_forms_test.exs
  - backend/test/fixtures/extent_patterns/
  - backend/data/reports/extent-reader/wwc/

depends_on:
  - 2026-11-20-waste-water-and-climate-commencement-reader
  - 2026-11-25-extent-reader-step-procedures

enables:
  - "Waste, Water and Climate: Amending-law reader"
---

# Session: Waste, Water and Climate: Extent reader (CLOSED)

## Problem

Step 5 of the round. 1,556 laws the round's builds read have stale extent readings (571 on old reader code, 985 never read), 401 builds are stale on the extent reader, and the gate shows our faults 669 and 135 causes to review before any write. The step writes every stale reading, then fixes misreads by cause until the check passes in code.

## Todo

- ✅ 1. Measure: session and baselines (read-only): the round's gate, yardstick, sweep and census; the switched families' check baselines; `none:law_no_powers`
- ✅ 2. Measure: write 1 and rebuild (restore point; `lat.reread --family "Waste, Water and Climate" --run`, 1,556 laws, Jason's go); check, golden, census again
- ✅ 3. Find: the fetch list (introductions and Acts not held), fetched once on Jason's go
- ✅ 4. Find: triage by cause, widest first, with the parked bugs' reach and the yardstick's narrower and disjoint changes; Decisions
- ✅ 5. Fix by cause, test first, widest reach first; preview each (`--preview --stale --family`); pre-flight
- ✅ 6. Fix: catalogue — cold dry run to a scratch copy, held moves to Jason, `--accept`
- ✅ 7. Settle: write 2 and rebuild after the last reader commit; golden; the check PASS; switched families rebuilt and checked; `mix lat.step_close`
- ✅ 8. Close: RULES, WORKFLOW §5, the skill's history, gotchas; meta row; commits by path; step report; no push unless asked

## Pass rule (fixed)

The approved plan is `~/.claude/plans/gleaming-doodling-matsumoto.md` (2026-11-26).

1. After the last write and rebuild, `mix lat.extent_check --family "Waste, Water and Climate"` prints PASS: our faults 0; no sweep miss in a `read:` form; every no-bound cause reaching the round named (`feed-speaks` or reviewed).
2. The feed yardstick recorded before and after; every `law_narrower` and `disjoint` change read and decided or in a named cause; `lat.measures` publishes it.
3. `ExtentPatternsTest` passes; every form fixed has a unit test; the catalogue dry-run first; held expectations move only on Jason's decision.
4. A powers-parser change diffed over every held introduction: gains only, each other change checked in its text.
5. The switched families (Fire and OH&S, Environmental Protection, Maritime Safety, Occupational) rebuilt and checked: no worse than baseline, or moved only by the fixed classes.
6. Golden 27/27 at every Settle.
7. `mix test` 0 failures; Credo diff and hooks clean.
8. Step close recorded: every reader gate through this step PASS; Stale laws 0 for the extent reader's reason.

**Triage size:** 10 changes, or two or more laws. **Frozen:** `golden.exs`, the checked-row fixtures, `extent_patterns/expected.json`'s held expectations.

## Parked for this step

The 11 open Extent reader bugs (no GitHub issues), each handled as the plan's table says: the round's 126 stale laws (write 1); the catalogue fixture behind the store (todo 6); the rest triaged by reach against the triage size (todo 4); SI 2006/475 is Sources'.

## Dependencies

- ✅ Waste, Water and Climate: Commencement reader (closed 2026-11-23)
- ✅ Extent reader readiness review, stamps, step procedures (closed 2026-11-25)

## Parking list

- Commencement reader: order-commencement-read-partial — OSRPA's SI 1964/191 commencements read partial (32 checked rows)
- Commencement reader: earlier-amending-provision-dated-by-amender — REACH Title 15A dated 2020-12-18 by SI 2020/1577 (14 checked rows)

- Extent reader: list-only-act-no-default — an Act with lists and no default gives its other provisions no bound (32 Acts; a rule for Jason)

- Extent reader: preview-counts-duplicate-rows — the preview counts a repeated unread row as added (3 laws, no bound)
- Extent reader: one-law-part-statements — 1980 c.65's other Part statements withheld (19 changes)

## Baseline (todo 1, before any write)

Reports: `backend/data/reports/extent-reader/wwc/baseline-*.txt`.

| Measure | Round | Fire and OH&S | Env. Protection | Maritime Safety | Occupational |
|---|---|---|---|---|---|
| Check | FAIL | FAIL | FAIL | FAIL | FAIL |
| Our faults | 669 | 3 | 3 | 1 | 0 |
| Causes not named | 135 | 1 | 2 | 0 | 1 |
| `none:law_no_powers` (changes) | 1,431 | 54 | 111 | 27 | 20 |
| Time (warm) | 8 s | 1m30 | 1 s(*) | 33 s | 42 s |

(*) the family's register name is `ENVIRONMENTAL PROTECTION`; `--family "Environmental Protection"` is refused.

Round: 565 family laws with LAT, 26,493 text changes by 1,162 amending laws. Bound by the law's text 10,833 (40.9%); follows enactment 5,933; unread statements 506; known 647, unreviewed 135. The switched families passed on 2026-11-15; their few faults since come from shared amending laws read by later reader code (write 1 re-stamps those the round's builds read).

Sweep (53 s): 267 uncaught sentences in 136 laws (252 shapes); 0 in a `read:` form. Census (`data/reports/extent-census/wwc-baseline`, 15 s): silent candidates missing 10, place 10, whole missing 5, quote missing 3; unnamed refs 79 in 13 laws; noise audit 18 of 228 read as statements (other 14, procedure 2, cases 1, outside UK 1). Read against the stored reading, so before write 1 these mix old and new code.

## Write 1 (todo 2)

Restore point `wwc-extent-before-write-1` (extent_rules, provision_changes, provision_change_claims, lat_events). `lat.reread --run --tag wwc-extent-write-1`: extents 1,556 laws 289 s; build 862 s; stale 13 s (19m26 in all). Reports `backend/data/reports/reread/wwc-extent-write-1-*.txt`.

- Round's change register: 0 stale (was 401 on the extent reader). Store-wide the extent reader's reason is 499 builds (other families, behind on shared amending laws).
- Check 1 (`wwc/check-1.txt`): our faults 669 → 0; causes not named 135 → 51 (known 274); bound by the law's text 10,833 → 17,106 (64.6%); no powers 1,431 → 1,364.
- Yardstick: agree 12,904, law wider 2,466, law narrower 220, disjoint 71, feed only 1,762, law only 2,030, neither 7,040; no bound where the feed speaks 1,597.

## Triage (todo 4)

Widest first, read in the laws' text. Classes:

| # | Class | Reach (changes) | Owner | Plan |
|---|---|---|---|---|
| A | Introductions not held: SI 2018/374 (255+14), 2019/93 (37), 2019/74 (23+3), 2019/558 (2), 1996/2019; laws not held SI 1995/2586 (4), 2000/323 (1) | ~340 | Find (fetch list) | fetch once, Jason's go |
| B | A default with "apart from the provisions listed below" unread: CCA 2008 s.99(1) "This Act, apart from the provisions listed below, extends to the whole of the United Kingdom" — its powers place SI 2013/1119 nowhere (25) | 25+, CCA's own changes | this reader | fix |
| C | Same-extent wordings not read: "has the same extent as the Act or instrument amended" (SI 2018/374 reg.2), "Any provision of these Regulations amending a provision … has the same extent as the provision being amended" (SI 2019/74 reg.2), "Unless otherwise stated, each amendment … has the same extent as the provision amended" (SI 2025/412 reg.1), "But where this Act amends … the amendment or repeal has the same extent" (2004 c.36 s.35) | 4+ laws | this reader | fix |
| D | "so far as it amends/affects any enactment which extends (does not extend) to X" on a listed item, read as unread, is a same-extent item: 1992 c.43 s.56(4)(e), (5)(c) (54+15); 1991 c.28 s.4 "amendments … to enactments extending to Scotland shall continue to extend to Scotland" (10) | ~80, 2+ laws | this reader | fix |
| E | "These Regulations extend to Northern Ireland only insofar as they deal with …" read as default NI (SI 2018/98 reg.1(3)): a conditional extension read as an only | 74 narrower + 14 | this reader (misread) | fix: GB default, NI conditional → the NI part withheld |
| F | legislation.gov.uk's introduction cites ECA 1972 as "1972 c.28" (Employment Medical Advisory Service Act): NISR 2017/88 placed E+W+S, disjoint from its NI targets | 69 disjoint | legislation.gov.uk error | Decision 1 |
| G | Purpose-limited "extend also to X, but only so far as required for …" / "so far as it gives effect to amendments of [Act]": 2014 c.21 s.93 (68), 1991 c.60 s.4 (19) | 87, 2 laws | this reader | Decision 2 |
| H | Per-provision lists left unread in 1980 c.65 (11) and smaller one-law wordings (~30 causes of 1–7) | ~90 | this reader | under triage size → known, unless a class above reads them |
| I | Law narrower than the feed, read right: SI 2001/3148 "Regulations 3 to 11 extend to England only" (15), SI 2013/3135 by PPCA 1999 s.7 (77), WSI 2015/1417 by EPA 1990 Part II (17) | ~110 | — | known: the law's text wins |

G splits: 1991 c.60 s.4 "This Act so far as it gives effect to amendments of the Environmental Protection Act 1990 extends to Great Britain" names the amended Act, so it reads exactly (the `amends` column): a fix, with D. Only 2014 c.21 s.93 is purpose-limited.

## Decisions

### Decision 1: the European Communities Act cited by the wrong chapter (NISR 2017/88)

- **Question:** legislation.gov.uk's introduction to the Drainage (EIA) Regulations (NI) 2017 names "section 2(2) of the European Communities Act 1972" but its citation link points to 1972 c.28, the Employment Medical Advisory Service Act. The powers parser follows the link, so the rule is placed in England, Wales and Scotland (that Act's extent): 69 changes to Northern Ireland laws get a territory disjoint from where they are. 350 other SIs cite the Act correctly.
- **Aim:** `binds-on-date` (a wrong territory is worse than none); `fix-where-owned`.
- **Options:**
  - (a) the powers parser checks a citation against the Act the text names: where the linked law's title isn't the one named, the named title wins (the parser's existing register title lookup). A general fix, diffed over every held introduction.
  - (b) a named known limit (a legislation.gov.uk error, one law); its 69 changes keep the wrong bound.
  - (c) a Northern Ireland rule extends no further than Northern Ireland. Rejected: it contradicts the signed-off rule that a devolved instrument's competence doesn't confine its insertions (V1-04), and moves 120 readings.
- **Recommendation:** (a).
- **Decided:** (a), Jason 2026-11-26.

### Not a decision: a purpose-limited extension (2014 c.21 s.93)

"Sections 61 and 62 and Schedule 8 extend also to Scotland, but only so far as required for the purposes of regulations applying as mentioned in section 61(11)(b)" (68 changes). The stored rules have no partial mark, so reading it would give Scotland in full, wider than the law. The step's aim decides it: a statement that can't be read fully gives no territory. It stays withheld, named `known:`, and is parked with the Extent reader as the purpose-limited class with its reach.

## Find and fix (todos 3–5)

- **Golden after write 1:** 27/27 (`wwc/golden-1.txt`, 17 min: the golden laws' amending laws read from their text).
- **Fetch (todo 3, Jason's go):** the introductions of SI 2018/374, 2019/93, 2019/74, 2019/558 and 1996/2019 fetched and parsed (2018/374 under 2004 c.20, PPCA 1999 and ECA 1972; 2019/93 and 2019/558 under EUWA 2018). SI 1995/2586 and SI 2000/323 are not on legislation.gov.uk (404): `known:` (5 changes).
- **Fixes, test first** (`WasteWaterClimateFormsTest`, `EnablingProvisionsTest`, `EnablingCacheTitlesTest`):
  - B: a default "apart from the provisions listed below" is read; the listed provisions are read where they are (CCA 2008 s.99(1) → UK). `Default.exceptions/3`.
  - C: three same-extent wordings ("Unless otherwise stated, …", "Any provision … amending …", "… the Act or instrument amended"). `Forms.amendments_same`.
  - E: a conditional extension ("extend to Northern Ireland only insofar as …") is never a plain default; the law is withheld (`unread *`). `Forms.extends`.
  - F (Decision 1): the Act the words name wins over a marker linking another law, where the register knows the title (`EnablingProvisions.marked/4`, `last_act/3`). A title the register holds for two laws identifies neither (`EnablingCache.titles/1`). The powers diff over every held introduction (1,178 of 2,830): 3 laws move, all gains (NISR 2017/88 and 2017/86 → ECA 1972 c.68 from c.28 and c.62; SI 2010/340 from `uksi_1972_68`). A first try without the ambiguity rule moved SSI 2008/339 to a wrong register duplicate (`UK_ukpga_2002_13`, titled as the asp): caught by the diff.
- **Not fixed, withheld:** D (1992 c.43 sch.1/2 items: most of its 69 changes carry no amending provision, so reading the items places none), G (1991 c.60 s.4, both sentences needed; 2014 c.21 s.93 purpose-limited), 1980 c.65 and 1991 c.28 lists. One-law wordings over the triage size: Decision 2.
- **Catalogue moves seen in `ExtentPatternsTest`** (6, for todo 6): CCA 2008 unread → default (gain); SI 2018/98 default NI → unread (the fix) and its "But … do not extend" relabelled; SI 2015/168 "They extend to NI only in so far as …" default NI → none (withheld); SI 2017/702 not read → its same statement read with unread exceptions (withheld); Interpretation Act 1978 s.24's conditional NI → none.
- J (found by the census's whole-missing sentences): "They extend to …" after "These Regulations may be cited as …" was never resolved to the law where the text carries the provision's number and its first paragraph's ("1 1 These Regulations …"): `Units` allowed one leading number. The hand-built test documents carry none, so the Environmental Protection test (SI 2018/575) passed while the real law read none. 7 of the round's SIs (2010/1102, 2012/811, 2018/575, 2021/513, 2021/561, 2021/917, 2026/714), which fell back to their powers: wider than stated where the powers reach further (SI 2026/714: E+W stated, UK by powers). Fixed, with a test on the words as held.
- The census's other silent candidates (missing 10, place 10, quote missing 3) are one-law list items read as a stated "so far as relating to …" (1986 c.44 s.68, 1989 c.29 s.113, 1991 c.22 s.169, 1994 c.21 s.68, 2005 c.15 s.179(g)) or the finder reading a list the reader holds (1980 c.65 s.47 s.32 and s.46 read only S, as the text says): withheld or right, under the triage size each.
- **Preview over the round's 1,591 stale laws** (`wwc/preview-2.{txt,json}`, 7m18, nothing written): 19 would change. The fixed classes: CCA 2008 default UK; SI 2018/374, 2019/74, 2025/412 same `*`; SI 2018/98 withheld; NISR 2017/88 powers E+W+S → UK; SI 2010/340 powers; SI 2018/575, 2020/1444, 2021/513, 561, 917, 2026/714 their stated default; SI 2019/93, 2019/558 powers (fetched). Withheld more (conditional statements, safe): Interpretation Act 1978 (`unread *` for its conditional NI), 1982 c.48 s.79, 1991 c.22 sch.9, SI 2017/1012 regs 1–8, 61–69, 134, 138.

### Decision 2: one-law wordings over the triage size, withheld

- **Question:** five Acts' own wordings leave their changes with no bound, each a single law's form and each over the 10-change triage size: 1992 c.43 s.56 (69: Schedules 1 and 2 "so far as they affect any enactment which does not extend to Scotland", but most of its changes carry no amending provision to place them), 2014 c.21 s.93 (68: "extend also to Scotland, but only so far as required for the purposes of regulations …"), 1991 c.60 s.4 (19: two sentences by amended Act and by a list of enactments' sections), 1980 c.65 Part lists (11), 1991 c.28 s.4 (10: "shall continue to extend to Scotland"). All are withheld, never a wrong bound; the feed is silent on them.
- **Aim:** `binds-on-date` (no wrong territory); `fix-where-owned`; rabbit-hole triage (one-law wordings are named, not chased).
- **Options:**
  - (a) name each `known:` with its reason, and park them with the Extent reader as sized one-law wordings (two of them, 2014 c.21 and 1992 c.43, can't be read right in the stored rule shape: a purpose-limited part, and changes with no amending provision);
  - (b) write a form for each now (four bespoke forms, a write and a catalogue run more).
- **Recommendation:** (a). They are withheld, not wrong, and each is one law's wording.
- **Decided:** (b), Jason 2026-11-26: fix all five now (a form each, then the catalogue dry run again and write 2).

### Decision 2 fixes (test first: `waste_water_climate_forms_test.exs`, 12 tests)

- **Upper bounds** (new `Extent.UpperBounds`, in `Units.unlettered`): 1991 c.28 s.28(5) "so much of … as relates to enactments extending to E+W shall extend also to E+W" → also E+W on s.4(2), (4), (10), s.27, Schs.2, 10, 11; 2014 c.21 s.93(2) "extend also to Scotland, but only so far as required for the purposes of …" → also S on ss.61, 62, Sch.8. Both read as the place stated, narrowed by the amended row's own extent; the purpose limit is fractalaw's (RULES, conditionals).
- **Targets by law amended** (new `Extent.AmendmentsOf`): 1991 c.60 s.4(5)–(7) "This Act, so far as it gives effect to amendments of …" → six target statements (PCA 1967, the two 1975 Acts UK; EPA 1990 GB; COPA 1974 ss.30D(1), 31(2)(b)(iv) and the Water (Fluoridation) Act 1985, Sch.1, Scotland only).
- **Items that follow their enactment** (new `Extent.SameItems`): 1992 c.43 s.56(4)(e), (5)(c) "Schedules 1 and 2, so far as they affect any enactment which does not extend to Scotland" → same extent, never withheld; s.56(6) "so far as is necessary to give effect to paragraph (c)" stays withheld.
- **"In this Part of this Act sections …"** (`Units.in_part`): 1980 c.65 s.195(3) read as not Scotland. Left withheld in 1980 c.65 (under the triage size, named): s.92 (dots before the words), s.101 (except so far as they repeal), s.125 ("only sections …" of the Part), s.133 (apart from this section), s.172, Sch.26, Sch.28 Pt III, Sch.32 Pt V. The 11 Sch.2 changes are freed; its 19 changes with no amending provision stay withheld.
- Extent, enacted_by and architecture tests: 489 pass.
- Preview 3 (`data/reports/extent-reader/wwc/preview-3.{txt,json}`): 1,591 laws read, 24 would change — preview 2's 19, unchanged, plus the five Decision 2 laws. Catalogue dry run 2 running cold (`catalogue-dry-2.txt`).

### Decision 3: the catalogue's held moves (dry run 2, cold, 945 s)

- Dry run 2 (`catalogue-dry-2.txt`): 5,815 laws, 4,097 sentences, unclassified 0, sweep misses in a read form 0; 27 new patterns, 7 no longer seen (read now); 6 held examples read differently.
- The 27 new patterns: plain readings (applies 5, default 3, list 3, target 2: 1991 c.60), none 5, withheld 9. From laws first read since the fixture fell behind the store, and today's fixes. All safe to accept.
- The 6 held examples, judged in the law's text:
  - gains, move the held class: 1978 c.30 s.24 (an interpretation rule, no extent: `none`); CCA 2008 s.99 (`default:E+W+S+NI`, today's fix); SI 2017/702 reg.2 (still withheld, `unread:other_provision`: its exception is another law's).
  - losses, the held class is right: 1992 c.52 s.301(1) "extends to England and Wales and (apart from section 212A(6)) to Scotland" read E+W (should be E+W+S); 1981 c.22 s.97(2) ss.93, 95(6) "apply to Northern Ireland" lost (held also NI); 1996 c.44 s.14 "Except for the repeals and amendments in paragraphs 3 and 4 of Schedule 1 …, which have the same extent as the Acts …, this Act extends to Scotland only" lost its same-extent list. Not today's: the stored readings of 2026-11-07/09 already read them so. Reach: 1981 c.22 no changes; 1992 c.52 one (Maritime Safety); 1996 c.44 one (ENVIRONMENTAL PROTECTION); none in the round.
- **Question:** what to do with the three losses before `--accept`?
- **Aim:** where a law's changes apply is read from its own words (fix where owned; right by design).
- **Options:** (a) accept the 27 patterns, move the 3 gains, keep the 3 losses held and park them as Extent reader bugs (2 changes, outside the round); (b) fix the 3 losses now, test first, then one more cold dry run (~16 min) before the accept.
- **Recommendation:** (b). They are this reader's own misreads, small, and the held class already says what is right; since 2026-11-19 a step fixes its own small classes rather than parking them. The cost is about an hour with the extra dry run.
- **Decided:** (b), Jason 2026-11-26: fix the three losses now, test first, then dry run 3 before the accept.

### Decision 3 fixes (test first: 3 more tests, 15 in the forms test)

- **A place with a provision carved out** (new `Extent.PlaceApartFrom`, in `Units.unlettered`): 1992 c.52 s.301(1) → default E+W+S, s.212A(6) not Scotland.
- **"but apart from those provisions this Act does not extend to P"** (new `Extent.ThoseProvisions`): 1981 c.22 s.97(2) → ss.93, 95(6) also NI; Sch.6 (so far as it repeals provisions which applied to NI) same extent; default E+W+S.
- **A default's leading same-extent exception** (new `Extent.ExceptSame`): 1996 c.44 s.14(4) → Sch.1 paras 3, 4 same extent; Sch.2 ("the related entries") withheld; default S.
- The catalogue classes a sentence by its first statement: 1981 c.22 and 1996 c.44 now `default:E+W+S` and `default:S` (true of the sentence; the lists held beside it, unit-tested). 1992 c.52's sentence is rewritten, so its old example id goes and two new ones come. These are the held moves Decision 3 makes.
- Extent, enacted_by and architecture tests: 492 pass; Credo diff clean. Preview 4 and dry run 3 running.
- Preview 4: the same 24 laws as preview 3. Dry run 3 (cold): unclassified 0, sweep misses in a read form 0; the 1992 c.52 misread pattern gone. `--accept` (warm, 1.3 s): 27 patterns accepted; the 5 held examples moved (1978 c.30 → none; 1981 c.22 → default:E+W+S; 1996 c.44 → default:S; CCA 2008 → default:E+W+S+NI; SI 2017/702 → unread:other_provision) with `FeedPatterns.encode`; rerun: 0 new, 0 gone, 0 differing. Committed `06b594a3` (hooks).

## Write 2 (todo 7)

- Full suite before the write: 12,749 passed, 0 failures (204 s).
- Jason's go 2026-11-26. Restore point `wwc-extent-before-write-2` (extent_rules 13,236; provision_changes 400,477; provision_change_claims 3,267,600; lat_events 98,670). `mix lat.reread --family "Waste, Water and Climate" --run --tag wwc-extent-write-2` running (`write-2.txt`).
- Write 2 (14 m: extents 31 s, warm from the preview; build 799 s, 565 laws, 0 failed): change register stale 0 (565 stale for labels only, as after write 1).
- Golden 27/27 (`golden-2.txt`).
- Check 2 (`check-2.txt`): our faults 0; sweep misses in a read form 0; **causes not named 41** (from 51) → FAIL on naming only. Bound by the law's text 68.4% (from 64.6%). Yardstick: agree 13,257, law wider 2,591, law narrower 136 (from 220), disjoint 2 (from 71).
- Triage of the 41: most are changes with no amending provision known (2014 c.21 68, 1992 c.43 54, 2003 c.37, 1984 c.54, SI 2018/98 15, …): no provision to look up, no wrong bound. One misread over the triage size: **K, a savings or supplementary statement withholding the whole law** — "Transitional or saving provision made by these Regulations has the same extent …" (SI 2019/93, 37), "Any supplementary provision made by these Regulations in relation to any enactment or instrument has the same extent …" (SI 2005/2035, 158): `Unread`'s savings rule needed a leading article. Fixed test first (17 in the forms test); 441 targeted pass; Credo clean. Preview 5 and dry run 4 running; write 3 needs Jason's go.
- Write 3 (Jason's go; restore point `wwc-extent-before-write-3`): extents 19 s, build 770 s, 565 laws, 0 failed. Golden 27/27. Check 3: our faults 0, sweep 0, not named 38 (the savings laws now follow their enactment).
- The 38 named in `withheld.json` (all `known:`): no amending provision (2014 c.21 68, 1992 c.43 54, SI 2018/98 15 with its conditional NI, and the one-law rest); SI 1995/2586 and 2000/323 not on legislation.gov.uk; SI 2014/3075 Finance Act 1973 s.56 by design; SI 2007/611 and 2013/139 powers-parser one-law wordings; SI 2023/1185 powers placed nowhere (1); 1992 c.43's 14 with an amending provision: a list-only Act, no default — a rule for Jason (parked `list-only-act-no-default`, 32 Acts).
- **Check 4: PASS** (our faults 0; sweep misses 0; no-bound causes not named 0; known 302).
- Switched families: restore point `wwc-extent-before-switched`; each `lat.reread --family F --run`, then its check, running.

## Step close (todo 7)

`mix lat.step_close --family "Waste, Water and Climate" --step "Extent reader"` (`step-close.txt`): FAIL.
- PASS Feed reader, Markup reader, Commencement reader, **Extent reader**.
- FAIL Sources 113 (92 not fetched, 21 stale; as at the Commencement reader's close). RULES `sources-fetch-failures-swept-each-step` made the sweep this step's first todo; the plan missed it. Decision 4.
- FAIL Checked rows 46 (PASS at the Commencement reader's close): all in switched families, moved by this step's rebuild of them, the extent readings unchanged (SI 1964/191 holds none; SI 2020/1577, 2019/758, 1992/3004 read 2026-10-26/27). OSRPA 1963 32 (SI 1964/191's commencements now `partial: true`, no commencing law), REACH 14 (a UK period from 2020-12-18 by SI 2020/1577): both the Commencement reader's, raised and parked.
- FAIL Stale laws 565: labels only (Store and build); the change register 0 (263 at the last close).

### Decision 4: the Sources sweep this step missed

- **Question:** the Sources gate fails on 113 documents not fetched (92) or stale (21). The rule says the step after a failing close fetches them first; the Commencement reader passed them to this step, and this step's plan missed the fetch. Fetch now, or pass it on?
- **Aim:** `coverage-from-lgu`; don't skip agreed steps.
- **Options:** (a) fetch now (`mix lat.sources --family "Waste, Water and Climate" --fetch`), rerun the Sources gate, and read any newly held amending law's extent with a fourth write and rebuild (~30 min more); (b) pass it to the Amending-law reader as its first todo: its re-read chain reads the extents of any newly held law and rebuilds the round anyway.
- **Recommendation:** (b), named in the step report as missed here. The fetch is the same either way, and (b) avoids a rebuild the next step repeats.
- **Decided:** (a), Jason 2026-11-26: fetch now, rerun the Sources gate, and a fourth write and rebuild if a newly held amending law needs reading.

### The Sources sweep and write 4 (Decision 4)

- `mix lat.sources --family "Waste, Water and Climate" --fetch` (8½ min): 113 fetched, 0 failed; the Sources gate PASS (`sources-fetch.txt`).
- Step close 2 (`step-close-2.txt`): Sources PASS; the Extent reader gate failed on 1: NISR 2025/33's reading went stale once its schedules were fetched (2 rows added).
- Write 4: restore point `wwc-extent-before-write-4`; NISR 2025/33 written (NI by its enabling powers, 4 rows); NISR 2023/212, the one law it changes, rebuilt (64 changes).
- Check 5 (`check-5.txt`): PASS, our faults 0, nothing unnamed; bound by the law's text 68.4%.

## Docs changed

RULES (two rules, the known-limits row), WORKFLOW §5, the extent-reader-check skill's history, the extent gotchas.

## Step report

PASSED (each reader gate through this step; checked rows and stale labels parked with their owners). The four tables were given in the terminal, 2026-11-26.
