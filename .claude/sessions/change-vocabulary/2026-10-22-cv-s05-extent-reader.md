---
session: 'CV-S05: Extent and Application Reader'
status: active
release: v0.1
opened: '2026-10-22'
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
