---
session: 'CV-S05: Extent and Application Reader'
status: active
release: v0.1
opened: '2026-10-22'
bugs:
  - pattern: "The extent check fetched from legislation.gov.uk unasked: the shared powers step (`lat.amending` with_powers) re-fetches an SI's made introduction whenever the enabling cache holds nothing parsed for it (retry_empty)"
    category: tooling
    module: mix lat.amending (with_powers) / mix lat.extent_check
    affected: "about 65 introductions fetched 2026-10-24 (SIs with no parsed powers); only data/cache/enabling written"
    fix: "with_powers(e, law, cached: true): the enabling cache only; the check always passes it; `--extents --cached` for re-reads"
    status: fixed
  - pattern: "Stored extent_rules stale against the extent reader (written before the CV-S05 forms); 13 family amending laws never stored"
    category: extent reading
    module: extent_rules (mix lat.amending --extents)
    affected: "OH&S: 62 stale, 13 not stored, of 444 amending laws"
    fix: "re-read the family's amending laws (--cached), then rebuild (2026-10-24: our faults 0)"
    status: fixed
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S05: Extent and Application Reader (ACTIVE)

## Problem

Step 5 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Where an amending law's changes apply, from its own text: its extent clause, its application clause, else its enabling powers, else its legislature's competence.

The session does not close until its results pass.

## Todo

- ⬜ Define what good looks like (the acceptance check): a hand-checked sample from the OH&S core family, and the measures, each defined in words with a test
- ⬜ The extent/application/powers catalogue (every sentence in held amending laws, classed by form × reading; fixtures + test)
- ⬜ Build the acceptance check; run it (ask Jason before any long run)
- ⬜ Checked on a sample of each wording read (CV-07 built four rounds, checked only by golden)
- ⬜ Act wordings not read: "Parts I and III of this Act … extend to …"; "except for Part N, which extends to …"; "the same part or parts … as the provision to which it relates" (CV-07)
- ⬜ Enabling-power parser: 6 other unparsed forms and 1 with no enacting formula (CV-07 agent sample); SI 1999/3232 matched to "ECA 1972 s.80, Sch.9" (a multi-law citation marker misread)
- ⬜ The competence rule (a devolved SI's competence doesn't confine its insertion, V1-04) confirmed on cases beyond Forestry Act s.1(1A)
- ⬜ SI 2012/760: its made introduction (held) names no enabling provisions (from CV-S01)
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01–S04 closed PASS on OH&S (CV-S04 2026-10-24)

## What good looks like (PROPOSED 2026-10-24, awaiting Jason)

Shaped on CV-S04's agreed approach and stopping rule. The unit is each OH&S amending law (356 of them), and each text change's territory claim.

1. **Every amending law accounted for (our faults 0).** Each law has one extent basis: own clause, application clause, enabling powers, competence, or none (with its reason). Our fault means one of:
   - the text holds an extent or application clause and we read none, or read a lower tier;
   - powers are read where the SI states its extent;
   - competence is used where powers were read;
   - a stored row is stale against the reader.

   The reasons for none are counted classes: no clause and no powers read, parent not held, no enacting formula.
2. **The catalogue first (don't skip):** every extent and application sentence in held amending laws, plus every powers clause, classed by form × reading, with real examples as fixtures and a test. Fix by count, and record pending forms with their reason.
3. **The check:** `mix lat.extent_check --family F`, built here.
   - Rows: which tier each amending law's basis came from.
   - Changes: which text changes have territory from the law and which have an extent bound, and why the rest have neither.
4. **Agent check on 50 + 50:** 50 amending laws stratified by tier, and 50 text changes. Each is checked against the law's own words and its parent Act's extent clause.
5. **Golden all-pass, tests, repeatable** (the same seed gives the same sample).

**Pass (CV-S04's stopping rule):** rows show our faults 0; golden is all-pass; the agent sample has no NEW defect, and every remaining gap sits in a counted pending class. Later families extend the catalogue.

## Agreed (Jason 2026-10-24: "Agree, start with the catalogue")

The definition of good above stands as agreed.

## The catalogue: design

Built on the CV-S04 shape (`Commencement.SentencePatterns`, `mix lat.commencement_patterns`).

- **Population:** every held body of a type whose extent the reader reads (`Extent.Store.reads?`): 3,369 laws (ukpga 639, uksi 2,062, ssi 219, nisr 177, wsi 139, asp 64, nisi 29, nia 16, asc 11, anaw 9, apni 4). One law at a time.
- **Units:** each top-level provision's sentence speaking of extent ("extend(s) to", "does not extend", "same extent as") or of whole-instrument application ("apply / have effect in relation to …").
- **Form:**
  - `kind`: extent or application;
  - `subject`: whole (this Act / these Regulations), following (a list below), parts, named, this (this section), amendments ("an amendment or repeal … has the same extent as the enactment"), or other;
  - `verb`: extends, not_extends, same_extent, applies, not_applies, or other;
  - `lead`: except, apart_from, subject_to, or none;
  - `place`: one place, a list, same, or none;
  - `only` and `also`.
- **Outcome**, what `Extent.read/1` made of it: `default:<code>`, `list:<kind>:<code>`, `applies:<code>`, a `part_not` list, or `unread` (the sentence is there but no reading took it).
- **Examples:** a pruned law XML (the provision holding the sentence, plus the ids of the Parts and sections that `parts/3` and the introductions need), read alone with `Doc.new/2` + `Extent.read/1`.
- **Files:** `test/fixtures/extent_patterns/{patterns,examples,expected}.json`, `ExtentPatternsTest`; module `AmendingLaw.Extent.Patterns` (pure); task `mix lat.extent_patterns` (read-only, writes only the fixture directory).
- **Powers clauses:** an SI's introduction isn't held. The enabling cache keeps only the parsed provisions (2,805 laws); the CLML store holds 55 introductions. A text-level powers catalogue needs the introductions stored (a fetch; Jason to decide). Without them, the powers side is catalogued by parse outcome only.

## NAS backup (2026-10-24, Jason: "also check NAS backup … in case we've fallen behind")

- **Behind:** the last full snapshot was 2026-10-19, and 12 of legal's tables had never been in the list, `amendment_rules`, `extent_rules` and the change store among them. 6,540 project files were newer than the last sync, including all of `cache/amendment-index`.
- **Fixed** (`ac634118`): the 12 tables are added. A new extras sync (`project-data/extras/`) covers the Claude memory, `.claude/memory`, `docs/qq`, `backend/priv/scraper` and `priv/metrics`. Left out (Jason): `.env` and `scripts/sync`'s May delta dumps.
- **Run:** `nas-backup.sh --archive` (the 10-19 snapshot to `archive/`). The new snapshot holds 41 tables, and 29,456 project files (1.4 GB) are synced. Then `--data-only` for the extras. No errors.
- **Not done (housekeeping, for Jason):** the database holds about 4.5 GB of old snapshot tables (`lat_reparse_*`, `live_status_snapshot_*`).

## The catalogue: built (2026-10-24)

- `AmendingLaw.Extent.Patterns` (pure):
  - units are each top-level provision's subsections (else the provision), so lists stay with their statement;
  - Schedule and Schedule-Part containers are skipped where their paragraphs or Parts are units;
  - quoted words and amending instructions ("insert—") are ignored;
  - application counts only where the law, or a part of it, applies;
  - the outcome classes are listed in its moduledoc.
- `Extent.statement/1` (new, public): what one sentence states in the reader's own terms, so the catalogue never re-implements the reader.
- `mix lat.extent_patterns` (read-only, one law at a time) and `ExtentPatternsTest`. An example is held only where its sentence reads the same in the flattened law as in the whole one.
- **Trial on 6 laws, already finding gaps:**
  - EPA 1990 s.164 ("Only the following provisions of this Act … extend to Northern Ireland") is not read, so EPA has no extent;
  - Access to Justice Act 1999 s.109 ("Sections 32 to 34 and 73(2) extend to Scotland") is unread inside the clause;
  - WSI 2013/755 ("An amendment … made by this Order has the same extent as the provision to which it relates") is not read;
  - provision-level wordings ("This section applies only to England", "Subsections (3) to (13) above do not extend to Scotland").
- Fixed while building:
  - a binding-to-`false` filter in a comprehension;
  - the self-subject test was case-sensitive, so no "These Regulations apply …" was counted.

## Catalogue run 1 (2026-10-24, Jason: "Run it"; about 25 min)

- **Size:** 3,357 laws, 2,781 sentences, 566 patterns, 986 examples, unclassified 0. 39 laws have a sentence that reads differently alone (not held). The fixtures hold no effect ids.
- **By outcome:**

  | outcome | sentences |
  |---|---|
  | default | 732 |
  | unread: in clause | 506 |
  | unread: provision extent | 472 |
  | unread: not read | 421 |
  | none (mentions) | 247 |
  | applies | 157 |
  | unread: provision application | 130 |
  | list | 84 |
  | another default | 14 |
  | unread application | 10 |
  | other provision | 5 |
  | part_not | 2 |
  | corresponds | 1 |

**Fixes by count (`Extent.read/1`; the reader's tests are 31, all passing):**
- **A, amendments' same extent:** "The amendments and repeals in Schedules 20 and 21 have the same extent as the enactments to which they refer" gives `{:same, nil, refs}`. "… made by this Act / Order" gives `["*"]`, every amendment the law makes, used only where no other list names the provision. "… made by the following provisions— …" takes the listed provisions. Never read with exceptions after it or in its subject; never "bind the Crown to the same extent", "as if".
- **B, named provisions' own extent, wherever stated:** "Sections 107 and 116A of this Act extend to Scotland only" gives `:only`; "… extend to Scotland" (with no only or also) gives `:named`, which widens a default or decides where there is none; "do not extend" gives `:not`.
  - Read only as plainly stated. Never another law's provisions ("… of that Act shall continue to extend", "the 1989 Act shall cease to extend"), a mention ("so far as they extend"), "so much of … as relates", a subject with exceptions (brackets included: "(except paragraph 12)"), or a qualified or excepted tail (", except that—", "so far as they amend—", "(apart from this section)").
- **C, list headings:** with "namely", ", and no others,", "shall extend".
- **D, a Part's own clause:** "This Part (of this Act) shall (not) extend to …" (through B).
- **H, a citation clause's list:** "These Regulations— (a) …; (b) …; and (c) extend to Scotland only".
- **Places:** "England and Wales, and Scotland" (a comma before the "and").
- **Bug found:** `from_rows/1` dropped `:not` lists, so a stored "Part III … does not extend to Scotland" read back as nothing. Fixed.
- **Catalogue diff:** 134 examples changed. All were reviewed against their text (over-reads found in review and excluded, as above) and re-accepted.

**Left as counted classes (not read):**
- provision-level application ("This section applies only to England");
- compound sentences (the second half: "Sections 28 and 33 do not extend to Scotland and sections 34 and 35 extend to Scotland only");
- a number in words ("Section twenty-three");
- Schedule paragraphs' own extent ("This Part of this Schedule shall extend to Scotland only");
- qualified or excepted extents.

## Catalogue run 2 (2026-10-24, Jason: "Run")

- **By outcome:** list 84 → 528; unread in clause 506 → 253; unread not read 421 → 322; unread provision extent 472 → 335. Unchanged: default 732, applies 157, none 247, provision application 130.
- 113 new patterns accepted; 18 no longer seen.
- **Found and fixed after the run:**
  - **EPA 1990 s.164**, the family's own: "Only the following provisions of this Act (together with this section) extend to Northern Ireland, namely— …" now gives default E+W+S, and the unqualified items (Part V, s.3(5), s.141 …) also extend to Northern Ireland. "Where any enactment amended or repealed by this Act extends to any part of the United Kingdom, the amendment or repeal extends to that part" is every amendment's same extent. The repealed-text dots (". . .") no longer end the list.
  - **A provision's territorial versions** gave the same sentence twice; the second copy read as `another_default`, and both shared one example id. Each sentence is now read once per provision.
- **Code:** `fb6d8bfe` (hooks passed). The reader's tests are 32; the related suites pass (4,061).
- **Not run again yet:** the catalogue keys still show EPA's old class until the next run, which can go with the next fixes. The stored `extent_rules` are stale against the reader; they are re-read at the check step (ask first).

## The check: `mix lat.extent_check` (built 2026-10-24)

- **Amending laws** (the family's stored text changes' `by`): each law's basis as the reader reads it now (clause, lists, application, powers, competence, or none with why). Our faults: stored `extent_rules` that differ from the reading now (`stale`) or are missing (`not_stored`). Beside it: the law's own extent sentences left unread, by catalogue class.
- **Text changes** (inserted, substituted, repealed, repealed_in_part, renumbered): where the territory comes from (`territory:law`, `bound:law`, `territory:feed` / `markup`), or none and why.
- `--sample FILE --n --seed`: stratified, for the agent.
- **Dry run before the re-read:** 444 amending laws, 4,953 text changes. FAIL with our faults 75 (62 stale, 13 not stored).
  - Basis: clause 102, powers 96, competence 73, none (no powers) 61, none (type not read: EU) 60, lists 29, none (no clause) 16, application 6, not held 1.
  - Changes: bound by the law 3,383; none (law's type not read) 573; none (no powers) 524; none (provision not named) 132; not named 88; competence only 79; territory from the law 47; none (no clause) 45; no amending law 42; same 20; markup 17; feed 1.
- **A slip, mine:** the dry run fetched about 65 SI introductions from legislation.gov.uk unasked. The shared powers step re-fetches where the enabling cache parsed nothing. Fixed: the check reads the cache only, and re-reads take `--cached`. Logged as a bug (fixed).

## Re-read, rebuild, check 1, golden (2026-10-24, Jason: "Okay for all 3")

- **Restore point** `cv-s05-before-extent-reread` (`extent_rules`, `provision_changes`, `provision_change_claims`).
- `mix lat.amending --extents --cached` on the 444 family amending laws: 383 read (60 EU types aren't read, 1 not held), 42 parent Acts read first. No errors, no fetch.
- `mix lat.vocabulary --build --family "OH&S: Occupational"`: 149 laws, no errors.
- **Check (seed 5 sample): PASS, our faults 0.**
  - Basis: clause 102, powers 98, competence 73, none (EU type) 60, none (no powers) 59, lists 29, none (no clause) 16, application 6, not held 1.
  - Unread own sentences: 79 laws (66 in the clause, 66 not read, 22 other provision, 3 another default, 3 list, 1 application).
  - Text changes (4,953):

    | territory from | changes |
    |---|---|
    | bound by the law | 3,385 |
    | none: law's type not read (EU) | 573 |
    | none: no powers | 496 |
    | none: not named | 143 |
    | none: competence only (insertions, V1-04) | 79 |
    | none: same as the enactment, or not named | 69 |
    | none: provision not named | 54 |
    | territory from the law | 47 |
    | none: no clause | 45 |
    | none: no amending law | 42 |
    | markup | 17 |
    | none: law not held | 2 |
    | feed | 1 |

- **Golden 27/27.**

## Agent check, seed 5 (round 1): laws 31 OK / 15 WRONG / 4 doubtful; changes 43 OK / 7 WRONG — FAIL (16 NEW)

NEW defects. N9 and N15 were verified by me (code and stored rows); the rest are as the agent reports them, with its evidence:
- **N1:** an amending instruction's inserted words are read as the law's own application (2020/1577 reg.15 "After regulation 1 insert— … These Regulations apply to Northern Ireland"). The REACH changes then carry NI; the feed says UK. (`ApplicationClause`, via `Extent.application`)
- **N2:** an application clause inserted later (2008/2852 reg.1A, 2020) is applied to the law's own 2008 changes.
- **N3:** a list heading's body runs on into qualified items and other Acts' sections (1977/45 s.65(10)); "subsections (1), (3) … of this section" becomes s.52(3)…; "in Schedule 14, paragraph 5" becomes sch.5.
- **N4:** a list heading naming several places is never read (`@heading` takes one place): "…extend to England and Wales, Scotland and Northern Ireland—", "…also to Scotland and Northern Ireland—".
- **N5:** "Subject to …, Parts 1 to 5 extend to England and Wales only" and "extends to the same part or parts of the United Kingdom as the provision to which it relates" are unread (2006/48 s.54).
- **N6:** "This Act, which subject to subsections (8) to (10) below extends to Scotland only—" is unread (1995/36 s.105(1)), and the half-read s.105(8) bounds s.18 to E+W.
- **N7:** "the preceding provisions of this Act (including the Schedules) do not extend to Northern Ireland" is unread and uncounted (1998/8 s.16(1)).
- **N8:** named Articles, regulations and Parts in SIs are never read (`@named` knows Sections, Parts and Schedules; `parts()` collects only section ids): 2016/1142 art.1(3)–(6), 2020/1460 reg.2.
- **N9 (verified):** `Extent.to_rows/2` writes only a `none` row when there is no default, so the lists are lost in storage (2015/20, 1995/36, 2006/48, 2016/1142 stored as `none`). This also breaks powers (2015/1637's power 2015/20 s.112 reads as nothing). The check's stale test compares through `to_rows`, so it can't see it.
- **N10:** "has the same application and extent as the provision amended" is unread (2020/660), so a UK powers bound is used instead of `:same`.
- **N11:** "The following provisions of these Regulations extend to England and Wales—" is unread (2025/361).
- **N12:** RefList: "paragraphs 5, 35 … of Schedule 23" becomes s.5, s.35…; "26(7) to (10)" becomes s.26(7) only; "Parts 4 and 5 of Schedule 13" is dropped (2015/20 s.114).
- **N13:** a same-extent subject naming Parts or regulations becomes `*` ("made by Parts 4, 5 and 6"; "made by regulations 3, 4, 6, …").
- **N14:** amendments or modifications with their own extent are unread ("The amendments made by regulations 8, 12, 17 and 19 extend to England, Wales and Scotland only"); "(and article 26 …)" is stored as sch.26.
- **N15 (verified):** "This Act shall extend to Northern Ireland with the exception of— (a) … Part 1; …" (CPA 1987 s.49(1)) is stored as default **NI**, so every CPA change to HSWA (a GB Act) carries an NI bound. It must be unread (an excepted statement) or read in full.
- **N16:** `NoteDate.extent_claims` falls back to the law's default when markup names no amending provision, ignoring `feed:affecting` and same-extent lists (OSRPA 1963 changes by the Licensing Act 2003, claimed E+W, though they follow the enactment, which is GB).
- **Doubtful:** devolved Acts (asp, asc, nia) get no competence (`with_powers` applies it to SIs only). "Parts 2 and 3 do not extend to NI" with no default is left unread (2001/10).
- **Minor:** the check reports an empty clause for basis `application`; the enabling cache for 2020/1111 lists ukpga 2005/14 (result unaffected).
- **Known (K):** K1 EU ×6, K3 ×3, K5, K6, K9 ×2 (1994/3140 refer-back, 2008/396 garbled title).

## Fix round 1 (2026-10-24, Jason: "Go ahead"), code `d5cba338`

N1–N16 are fixed as logged above, with tests (the reader's tests are 44). Also fixed, found while reviewing the catalogue diff:
- **A default with exceptions after it:** read only where the exceptions are plain ("except regulation 15" becomes not there; "except for Part 1, which extends to …" and "except that section 12 extends …" become those lists; "except as otherwise provided …" means the exceptions are stated elsewhere). Otherwise unread, and never with another law's provisions.
- **Atomic place lists**, so a shorter list can't slip past the exception guard.
- **Lists:** a list inside an enumerated item ends at the parent's next item. Items are split at each provision noun, with dots removed. A qualified aside in brackets names nothing. A complement (", but otherwise this Act extends there") is no compound.
- **Never read:** "together with corresponding entries in Schedule 4"; "in so far it applies".
- **Devolved Acts** (asp, nia, anaw, asc) stating no extent take their legislature's competence.
- **Catalogue:** 100 examples changed. The risky ones (changed defaults, lists now unread) were reviewed against their text, the rest sampled; all re-accepted. The related suites pass (4,073).
