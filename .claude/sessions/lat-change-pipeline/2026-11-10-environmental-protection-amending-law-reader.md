---
session: 'Environmental Protection: Amending-law reader'
status: closed
opened: 2026-11-10
closed: 2026-11-10
outcome: success
family: '💚 ENVIRONMENTAL PROTECTION'
step: Amending-law reader

summary: >
  The amending-law reader's gate passes for Environmental Protection: every one of the 240 groups of changes the law's
  text states that legislation.gov.uk contradicts or leaves unstated is named in disagreements.json (from 230 of 280 not
  named). Thirteen misread classes were fixed (an Order's articles, a Schedule's paragraphs, a commencement's items,
  table entries, repeals-table items, quotes numbered in titles, levels, the modification wording) and A rose 2,950 → 3,192,
  L fell 536 → 391; Maritime's gate passes with its parked group named.

decisions:
  - what: "Decision 1 (A): fix F1–F5, the modification wording and the repeals-table items (K4, 18 laws); one-law wordings named known; unnumbered list items re-parked"
    why: Each fixed class was over the triage size (10 changes or 2 laws); the review found them mostly hidden in by-design groups
    result: about 170 wrong changes removed in this family; 22 unit tests
  - what: "Decision 2 (A): fix three level classes found in the catalogue dry run (in the appropriate place, inline quotes, amounts)"
    why: Each over the triage size by laws; local to the level reading; fixed before write 2 saves a third write
    result: 14 changes now words; a second cold catalogue run (the --accept)
  - what: Runs held to batched writes (Jason "be careful with rerunning data rebuilds")
    why: The step had many fixes; each write is a read pass and rebuilds
    result: "write 1, write 2, a small write 3 (3 laws) on Jason's go, then two zero-diff re-reads for the reader version"
  - what: "Write 2 read the family's amending laws and the regression set only (Jason: Family only)"
    why: The pass rule needs the family current; other families' stale amenders are read live per law at their builds
    result: family stale 0 of 500; about 1,700 other amenders stale
  - what: F3's "come into force" pattern moved to Amendment.Reader.Commencing, listed in CommencementReadTest's allowed readers
    why: The architecture test keeps commencement words in the commencement readers; this is a skipped lead-in, never a date; putting it in commencement/ would stale every commencement rule
    result: architecture tests pass; one more zero-diff re-read

metrics:
  strata_before: { A: 2950, D: 396, L: 536, stated: 3882 }
  strata_after: { A: 3192, D: 391, L: 391, stated: 3974 }
  agreement_after: { by: 100.0, level: 98.5, operation: 91.2, target: 95.8 }
  gate: { groups_before: 280, not_named_before: 230, groups_after: 240, not_named_after: 0 }
  read_pass: { family_stale_before: 304, family_stale_after: 0, family_amenders: 500, write1_laws: 351, write2_laws: 798 }
  maritime: { A: "1348 → 1347", D: "99 → 97", gate: "1 → 0 not named" }
  ohs: { strata: unchanged, gate_not_named: "91 → 88" }
  catalogue: { patterns: 151, new_accepted: 29, examples_reading_differently: 0 }
  golden: 27/27
  mix_test: 10652 passed
  agent_tokens: 0

lessons:
  - title: A reader edit of any kind moves ReaderVersion and stales every amending law
    detail: >
      A compiler-warning fix (clauses not grouped) and then an architecture-test fix, both after write 3, each moved the
      version, so the 798 laws were re-read twice (zero-diff, about 25 min each). Run mix compile --warnings-as-errors and
      mix test test/sertantai_legal/architecture with the reader suites before any write.
    tag: tooling
  - title: The field diff catches over-reaches a unit test misses
    detail: >
      Run 1 of the by-field diff showed F3 firing on a definition's "the day when this section comes into force" (2003 c.37
      s.58 on the Water Industry Act lost) and F5 letting an entry borrow a sibling's section. Both were fixed before any
      write. A count of rules per law would have hidden them.
    tag: data
  - title: Review the field diff fully before the catalogue dry run
    detail: >
      The catalogue's new patterns showed three more level classes after the dry run, so the --accept was a second cold run
      (Jason, with the VM booting, "we're continually running cold runs"). The diff's classes should be read to the end
      first.
    tag: tooling
  - title: The by-design groups hide most misreads
    detail: >
      quote-dropped-number held 2006 c.16 → 1995 c.25 s.2(1)… (40, a Schedule's sub-paragraphs) and WSI 2013/755 → the NRW
      Order (31, an Order's articles); quote-new-number grew 175 → 343 after write 1. Check by law, as Maritime's lesson said.
    tag: data
  - title: Readers' application claims fall into the L stratum
    detail: >
      25 groups were the laws' own "These Regulations apply to …" claims (Readers.Application), not amendments; named by cause
      once, which also cut OH&S's unnamed groups 91 → 88.
    tag: data

bugs:
  - pattern: "A modification read as an amendment: \"has effect as if\", \"shall apply in relation to … as if … were substituted\" slip past the modification rule (`@modification` reads only \"have effect|be read|be construed as if\") (e.g. SI 1995/3128 reg.10(3) on MSA 1995 s.97(1); 2020 c.7 Sch.7 on ERA 1996)"
    step: Amending-law reader
    status: fixed
  - pattern: "The amending gate fails today: 1 group not named — MSA 1995 s.173(7)(a)(i), inserted by SI 2006/1265 (no operation from legislation.gov.uk: inserted provision), appeared with Merge's rebuild (93599e6d) after the step passed (f18affb2)"
    step: Amending-law reader
    status: fixed
  - pattern: "OH&S Amending-law gate: 91 disagreement groups not named, as at 2026-11-08"
    step: Amending-law reader
    status: open
    fix: "88 groups as at 2026-11-10 (the application claims now named by cause); OH&S's own Amending-law reader re-run names them"

artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/commencing.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/scope.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/clauses.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/law_named.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/targets.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/repeal_table.ex
  - backend/lib/sertantai_legal/scraper/amendment/read_law.ex
  - backend/lib/sertantai_legal/scraper/amendment/patterns/example.ex
  - backend/lib/sertantai_legal/scraper/amending_law/text.ex
  - backend/lib/sertantai_legal/scraper/amending_law/operation.ex
  - backend/test/sertantai_legal/scraper/amendment/reader/environmental_protection_forms_test.exs
  - backend/test/sertantai_legal/architecture/commencement_read_test.exs
  - backend/test/fixtures/amendment_patterns/
  - backend/data/reports/amending-reader/environmental-protection-gate-review-1.md

depends_on:
  - 2026-11-09-environmental-protection-extent-reader

enables:
  - "Environmental Protection: Merge"
---

# Session: Environmental Protection: Amending-law reader (CLOSED)

## Problem

Step 6 for Family 3, together with the bugs parked on this step. Each amending provision's own words must give the right amended law, target, operation and level, because the law's text wins where it speaks. Today the gate fails: 230 of 280 groups are not named, and 304 of the family's 500 amending laws are stale.

## Todo

- ✅ Open the step session with the baseline. Record the OH&S and Maritime strata and gates as baselines
- ✅ Restore point; read pass 1 of the stale laws (preview, then the read); family rebuild; the gate and strata give the real gate
- ✅ Review every group in the amending law's words, widest first. Name each `fix:`, `known:` or `check:`, with the reasons in a report. Measure each parked bug's reach in this family. Decisions for Jason
- ✅ Fix the `fix:` classes and the two carried-forward bugs (the modification wording, the unnumbered list items), test first; pre-flight previews and a field diff
- ✅ Catalogue over every family's laws: dry run, review, `--accept` after Jason decides; `AmendmentPatternsTest` passes
- ✅ Read pass 2 and the rebuilds; the gate re-run until PASS; Maritime's group named; the OH&S and Maritime regression checks
- ✅ Golden 27/27; `mix test` with 0 failures; Credo clean
- ✅ Pass and close: WORKFLOW, RULES, the skill's history, parked bugs, the meta row, commits

## Dependencies

- ✅ Environmental Protection: Extent reader (closed 2026-11-10, pushed 2e73de62)
- ✅ Plan approved 2026-11-10 (`~/.claude/plans/gleaming-doodling-matsumoto.md`)

## Plan (as approved)

- **Aim:** `binds-on-date`, the "what changed" half: the right provision, changed the right way. Principle `law-text-wins`.
- **Pass rule:**
  1. the read pass is current: no stale family amending law;
  2. the family gate prints PASS, with every D and L group named `known:` and the by-design classes checked by law;
  3. `AmendmentPatternsTest` passes, with the catalogue run over every family's laws; each fixed form is unit-tested; the dry run comes first, and held moves only on Jason's decision;
  4. every shared reader change is diffed by field, with each loss checked;
  5. no regression: the OH&S and Maritime strata no worse, Maritime's gate PASS, OH&S's unnamed groups at most 91;
  6. golden 27/27;
  7. `mix test` passes; the Credo ratchet is clean.
- **Triage size:** 10 changes or more, or 2 laws or more.
- **Frozen:** `golden.exs` and the held `expected.json`.
- **Out of scope:**
  - Merge (`unjoined` is Merge's);
  - the other readers;
  - the label fold;
  - Sources;
  - yield and coverage;
  - EU law's amending SIs;
  - the amended laws' Schedules.

## Baseline (2026-11-10)

Reports are in `backend/data/reports/amending-reader/*-2026-11-10-0.txt`.

| Family | A | D | L | Operation | Level | Target | Gate groups | Not named |
|---|---|---|---|---|---|---|---|---|
| Environmental Protection | 2,950 | 396 | 536 | 91.0% | 98.1% | 96.3% | 280 | 230 |
| OH&S | 1,375 | 121 | 400 | 91.3% | 99.1% | 92.5% | 128 | 91 |
| Maritime Safety | 1,348 | 99 | 162 | 94.2% | 99.1% | 97.7% | 83 | 1 |

- **Read pass:** 304 of the family's 500 amending laws (feed pointers) are stale, and 351 of 2,521 across the corpus.
- **Parked bugs on this step:** 20. The plan's table gives each one's action. Each is measured in this family after read pass 1.

## Write 1 (2026-11-10)

- **Restore point** `amending-environmental-protection-before-read`, with the index tar in the scratchpad.
- **Preview** of the 351 stale laws: 202 changed, rules 3,906 → 6,753, all gains.
- **Read pass,** then the family rebuild (122 laws, 187 s).
- **Stale after:** 0 in the family, 0 in the corpus.
- **Strata:** A 2,950 → 3,066, D 396 → 406, L 536 → 570.
- **Agreement:** operation 91.3%, level 98.2%, target 95.8%.
- **Gate:** 281 groups, 79 known, **202 not named** (976 D and L changes).
- **Reports:** `backend/data/reports/amending-reader/*-2026-11-10-1.txt`.

## Review 1

The review is in `backend/data/reports/amending-reader/environmental-protection-gate-review-1.md`. Every group was read in its amending provision's words.

- **Most groups are right:**
  - legislation.gov.uk holds no record, or names no operation;
  - headings and definitions are words;
  - legislation.gov.uk's "in part" against a whole repeal in the table;
  - Merge's unjoined changes;
  - 25 are the laws' own application statements, not amendments at all.
- **Five misread classes are over the triage size:**
  - F1, an Order's articles under the `reg.` prefix (~85);
  - F2, a Schedule lead-in not seen (~64);
  - F3, a commencement provision read as an insertion (14);
  - F4, a context's place dropped (2 laws);
  - F5, a table's entry read as the place (2 laws).
- **Hidden in the by-design groups:** F1 and F2 are mostly there, as quote-dropped repeals, for example 2006 c.16 → 1995 c.25 s.2(1)… (40).
- **Eleven one-law wordings** (K1–K11) are below the triage size.

## Decision 1: what is fixed in this step

**Question.** Which classes are fixed here, with one batched write 2 after them?

**Aim.** `binds-on-date` and `law-text-wins`: the law's text wins where it speaks, so a misread puts a wrong change on a provision. The fixes below remove about 170 wrong changes in this family.

**Options.**
- **A (recommended):**
  - fix F1–F5 and the modification wording (carried forward, already ruled);
  - name K1–K11 known (RULES, one-law amendment wordings);
  - measure K4 (repeals-table "In section N— …" read whole) across the corpus with the preview, and fix it if it reaches 2 laws;
  - park the unnumbered-list-items bug again with its count: this family has no case, and it is legislation.gov.uk's structure (a list nested inside a quote's list).
- **B:** as A, and also fix the unnumbered list items now, as the plan first said. It is a change to `AmendingLaw.Text`, shared by every reading, for 7 Maritime effects and no Environmental Protection ones.
- **C:** fix only F1 and F2, the two wide ones, and name the rest known.

**Decided: A** (Jason 2026-11-10).

**Recommendation: A.** Each fix is tested first, previewed on the family and the regression set, and diffed by field before the one write 2.

## Fixes (Decision 1, A)

Tests are in `backend/test/sertantai_legal/scraper/amendment/reader/environmental_protection_forms_test.exs` (13), written red first.

- **F1, an Order's articles:**
  - `Reader.law_ref/4` with `articles: true` gives kind `:order`, prefix `reg`, and the words "articles";
  - `ReadLaw.law_ref` sets it from the rows' `source_xml_id` (`article-…`).
- **F2, a Schedule's paragraphs.** In `Scope.in_schedule`:
  - a bare "paragraph N" is a Schedule's; never for an EU law, whose paragraphs are numbered that way;
  - the nearest lead-in in the context decides, Schedule or provision ("Amend Schedule 7 …", "Schedule 2 is amended in accordance with …").
- **F3, a commencement:** "comes into force" in the instruction or a parent, in its own words, gives no rule. "The coming into force of this paragraph" is not a commencement (2021 c.30 Sch.12 para 14(5)).
- **The modification wording:** `@modification` now also reads "has effect as if", "shall apply … as if" and "applies … as if", in the instruction's own words with quotes removed.
- **F4, a context's place:** an "(i)" under a parent's letter is a sub-paragraph (`LawNamed.placed_by`).
- **F5, a table's entry:** `Clauses.no_entry_names` leaves "the entry relating to/for section N" as "the entry".
- **K4, the repeals table, fixed** (its reach is 18 amending laws in the corpus, over the triage size, as Decision 1 said): "In section 48—" over its list items is those items, never the whole section (`RepealTable.lead_in_items`; items carrying their own "(a)" labels too).
- **Suites:** amendment, amending-law and change-vocabulary, 5,680 pass. Credo diff: no new issues.

## Pre-flight: the by-field diff

The diff is the stored rules against a fresh reading, by (source, law, operation, level, treatment, targets). It writes nothing. The script is `rule_diff.exs` in the scratchpad.

- **Run 1** (family + regression, 793 laws): 102 laws changed, −389 / +295. It found two over-reaches, both fixed before run 2:
  - F3 fired on a definition's "the day when this section comes into force" (2003 c.37 s.58 on the Water Industry Act 1991 ss.87–91 lost). F3 now reads only a parent lead-in ending in a dash.
  - F5 left an entry placed by nothing to borrow a sibling's or the context's section. Now its table's provision comes only from the instruction or its parents, else there is no rule; a Schedule's table drops out in `Scope`.
- **Run 2** (+ the 18 K4 laws, 811 laws): 119 laws changed, −486 / +516 (`fix-rule-diff-2026-11-10-2.txt`). Every class was read:
  - F1: correct moves, for example "In article 26, after paragraph (3)" → reg.26(4), not reg.4;
  - F2: only Schedule paragraphs, sub-paragraphs and forms dropped;
  - F4 and F5: placement;
  - the modification wording;
  - K4: whole-section repeals become their items.
- **After run 2:** one more K4 gap, items carrying "(a)" labels, was fixed and unit-tested.

## Catalogue dry run (2026-11-10)

`mix lat.amendment_patterns --laws <388 laws of the three families> --out <scratch copy>`. The output is `catalogue-dry-2026-11-10-1.txt`.

- 11,529 provisions read in 1,159 amending laws (27 not held); unclassified 0.
- 152 patterns (from 122), 318 examples.
- **Examples reading differently from held expectations: 0**, so there is no held move.
- 30 new patterns, each read on its examples. All are new families' forms read right, apart from three level classes, below. They join the three level-cause groups of the gate:
  - "in the appropriate place insert— <definition>": the reader knows only "at the appropriate place", so the definition is read as a whole provision. **5 laws** (SI 2013/1821, SI 2016/883, WSI 2013/755, WSI 2015/1394, WSI 2015/1417), 6 changes.
  - Quotes marked as inline amendments in the newest SSIs and NISRs: "omit <quote>,", "after <quote> insert <quote>." have no quote marks left in the instruction, so they read as whole provisions. **3 laws** (SSI 2026/55, SSI 2025/165, NISR 2025/126), 5 changes.
  - "For the amount of £25 … there shall be substituted the amount of £50": an amount is words, but it is read as the whole provision. **3 laws** (SSI 2003/268, SSI 2013/315, WSI 2004/909), 3 changes.

## Decision 2: the catalogue, and three level classes found in it

**Question.**
- Accept the catalogue as dry-run (30 new patterns accepted, no held expectation moved)?
- Fix the three level classes before write 2?

**Aim.** `law-text-wins`: the level (words or whole provision) decides whether a provision's text changed or the provision went. A definition read as a whole provision makes a new provision that isn't there.

**Options.**
- **A (recommended):**
  - fix all three, test first, in `Clauses.operation` and `Operation.words?`: "in the appropriate place"; an inline quote with no provision named as the object; "amount" or "sum" as words;
  - preview the affected laws, with a field diff;
  - then the catalogue `--accept` (a second cold run, about 25 min) and write 2.
- **B:** name the three known (14 changes) and accept the catalogue as it stands.

**Decided: A** (Jason 2026-11-10: "Go A, but know I'm booting the VM — and we're continually running cold runs!!!!"). So:
- the affected laws only are previewed;
- the catalogue runs once more, as the `--accept` (2 workers, VM up);
- then write 2.

The lesson: the dry run came before the review of the field diff was finished, so a second cold run was needed.

**Recommendation: A.** Each class is over the triage size by laws, and the fixes are local to the level reading. Fixing them now saves a third write.

## Write 2 and after (2026-11-10)

- **The catalogue `--accept`** (2 workers, VM up): 151 patterns, 29 new accepted, **0 examples reading differently**, so no held expectation moved. `AmendmentPatternsTest` passes (319).
- **Write 2:** restore point `amending-environmental-protection-before-write-2`, then 798 amending laws read (142 changed, rules 35,625 → 35,706), then rebuilds of Environmental Protection, OH&S and Maritime.
- **The gate review after write 2:** one more class, a quote numbered only in its group's title (7 laws, 13 changes: "After section 45B insert— 45C …" had made s.1–s.7). Fixed and field-diffed over the 7 laws (3 changed, all gains).
- **Write 3** (Jason's go): restore point `amending-environmental-protection-before-write-3`, then the 3 laws read and the Environmental Protection rebuild.
- **Statuses:** 145 named in `disagreements.json`.
  - By cause: the laws' own application statements.
  - By standard reason: no record, no operation, Merge's, legislation.gov.uk's "in part".
  - One-law wordings EP-K2–K14 (RULES known limits).
  - Maritime's parked group (SI 2006/1265 art.4(4)(a), checked in its text).
- **A compiler warning,** clauses not grouped in `AmendingLaw.Text`, was fixed after write 3. That moved `ReaderVersion`, so the 798 laws were re-read: **0 changed** (zero-diff).
- **The architecture test** `CommencementReadTest` then failed: F3's "come into force" pattern sat in `reader.ex`. It moved to its own module `Amendment.Reader.Commencing`, listed in the test's allowed readers with its reason (a skipped lead-in, never a date). The reader version moved again, so a second zero-diff re-read (read 5) followed.

## Results

| Family | A | D | L | Gate |
|---|---|---|---|---|
| Environmental Protection | 2,950 → 3,192 | 396 → 391 | 536 → 391 | **PASS**, 240 groups named (from 230 of 280 not named) |
| OH&S | 1,375 | 121 | 400 | 91 → 88 not named (no regression; "applied provision" named by cause) |
| Maritime Safety | 1,348 → 1,347 | 99 → 97 | 162 | **PASS** (1 → 0: its parked group named). A −1 and D −2 are the modification fix: SI 1995/3128 reg.10(3) on MSA s.97(1) gives no change |

- **Agreement (Environmental Protection):** operation 91.0% → 91.2%, level 98.1% → 98.5%, target 96.3% → 95.8% (more changes now read in Orders and Welsh law).
- **Read pass:** 0 stale family amenders after read 5. The other families' amenders (about 1,700) stay stale by Jason's choice ("Family only") and are read live per law at their builds.
- **Golden:** 27/27 (after read 4).
- **Agent tokens:** 0.

## Parking list

- Amending-law reader: `unnumbered-list-items-collapsed` stays parked (no case in this family; 7 Maritime effects).
- Amending-law reader: the other families' about 1,700 amending laws are stale since write 2's reader version (Jason: "Family only"); the next full read pass or the next family's step reads them.

## Parking list
- (none yet)

## Runs held to two (Jason 2026-11-10)

Jason: "With so many bugs to fix be careful with rerunning data rebuilds." So:
- **Write 1:** read pass of the stale laws and one family rebuild, after the preview.
- **Write 2:** after every fix and the catalogue, one batch. Only the laws the fixes change are read, then one rebuild per affected family.
- Between the two writes, fixes are checked by previews and field diffs, never by a write.
- New groups after write 2 are named or parked; a third rebuild only on Jason's go.
