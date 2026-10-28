---
session: 'CV-S06: Amending-Law Reader'
status: active
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
bugs:
  - pattern: "A Schedule's paragraph read as the amended law's regulation or section of that number: 'In Schedule 2, for paragraph 10 substitute—' → reg.10 and 11 provisions under it; 'Omit Schedule 5' → reg.26; 'In paragraph 4(2)(b) of Schedule 1—' → reg.2(2)(b). The guard (Reader.in_schedule) reads only a holding provision beginning 'In [Part|paragraph N of] Schedule N', misses a non-breaking space (no u flag), nested 'paragraph 1 of Part 3 of Schedule 6' and the instruction's own words"
    category: reader misread (target)
    module: Amendment.Reader (in_schedule)
    affected: 59
    fix: "schedule located when the instruction or a holding provision (unquoted, captionless, unicode) names Schedule N / Annex N and no section, regulation, article or rule: no rules while Schedules are not read as targets"
    status: open
  - pattern: "A list of many laws' provisions ('In the following provisions, for … substitute …— s.1A(8) of the 1953 Act; … paragraph 2(2) of Schedule 3A to HSWA; …', Sentencing Act 2020 Sch.24 para 443; 'The enactments are— … HSWA, section 60; …', 2022/31 Sch.1 para 1(2)) read with other laws' items as the amended law's targets (HSWA s.1A… ×125 'inserted'; s.113)"
    category: reader misread (target)
    module: Amendment.Reader / LawNamed.scoped
    affected: 2
    fix: "each law takes only its own item's provisions (the item naming it)"
    status: open
  - pattern: "Heading and punctuation substitutions read as whole-provision: 'For the heading substitute—' (under regulation 6) → reg.6 substituted; 'for the full stop at the end of sub-paragraph (b) substitute a comma' → reg.7(4)(b) provision"
    category: reader misread (level)
    module: Amendment.Reader.Clauses (operation level)
    affected: 2
    fix: "heading, full stop, comma, semicolon substitutions are words-level"
    status: open
  - pattern: "A named place's bracket readings ('subsection (6)(e)' → s.15(6), s.15(e), s.15(6)(e)) taken top-most by the change vocabulary as if a quote's tree: the parent marked changed (HSWA s.15(6) repealed for (6)(e); reg.14(1) substituted for 14(1)(c); s.28(3) for (3)(c)(iii)): 74 of the family's 521 provision-level rules carry such readings"
    category: reader misread (target)
    module: ChangeVocabulary.Readers.AmendingLaw (targets) / Amendment.Reader (treatment)
    affected: 74
    fix: "quoted rules carry treatment :quoted (top-most); a named place's readings filtered to the law's rows, then the deepest"
    status: open
  - pattern: "'after subsection (2) insert the subsection set out in sub-paragraph (2)' read as s.11(2) inserted (the anchor), not s.11(2A) (2005 c.14 Sch.3 para 3(1)(b))"
    category: reader misread (target)
    module: Amendment.Reader (set_out)
    affected: 1
    fix: "the block set out in a sibling sub-paragraph is the quote"
    status: open
  - pattern: "A provision omitted with the word joining it ('omit sub-paragraph (d) and the word “or” preceding it') read as words: the quoted conjunction made the clause words-level"
    category: reader misread (level)
    module: AmendingLaw.Operation (words?)
    affected: 8
    fix: "a provision named then 'and the [word] “…” preceding/following/at the end' is whole"
    status: open
  - pattern: "A quote numbering provisions ('In paragraph (l), at the end, for “.” substitute— (m) …; (n) …') read as words in the new paragraphs"
    category: reader misread (level)
    module: Amendment.Reader (quoted rule)
    affected: 10
    fix: "a quoted rule with numbered provisions is provision-level, unless it quotes a definition (its lettered paragraphs are words)"
    status: open
  - pattern: "A list of sections with a Schedule entry ('sections 7, 8(2) and the entry in Schedule 2 relating to section 124(2) …', SI 1974/1941 reg.5(1)) read as s.7(2), s.8(2), s.124(2): the bracket carried to s.7 and the entry's section taken as the law's"
    category: reader misread (target)
    module: Amendment.Reader.Targets
    affected: 1
    fix: "not in this batch (one provision); a list's bare numbers are whole, a Schedule entry's section is not the law's"
    status: open
  - pattern: "A named place's partial readings kept beside its held one when the amended law's CLML skips a level (HSWA s.28(3)(f)(i) is section-28-f-i): 'paragraph (f)(i) of subsection (3)' gave s.28(3) and s.28(f)(i); the s.28(3) change was then placed on s.28 (seed 31 NEW, ssi 2008/339 art.5(2))"
    category: reader misread (target)
    module: ChangeVocabulary.Readers.AmendingLaw (targets) / ChangeVocabulary.build
    affected: 6
    fix: "each full reading resolved to its longest held spelling, shallower places dropped; law-text targets respelt to rows via xml_ids (35f29731)"
    status: fixed
---

# Session: CV-S06: Amending-Law Reader (ACTIVE)

## Problem

Step 6 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Per the source-use balance (CV-07, Jason 2026-10-22): find the changes legislation.gov.uk hasn't recorded yet (the backlog) and check theirs; coverage of the feed is not the target.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (accepted by Jason 2026-10-28): catalogue, census of the 211 disagreements, precision seeds on the statistical rule, renumbering as a census class, quality statement
- ✅ Catalogue (B1–B3 found; statuses after the fix batch): `mix lat.amendment_patterns` over the family's read instruction sentences, classed by form, examples pinned in a test; new forms decided
- ✅ Census of the 211 disagreements (B4–B7 found; the rest legislation.gov.uk, the merge's, or right; no renumbering) (65 law text only, 60 unjoined, 86 value): each classed backlog / reader misread / join miss / legislation.gov.uk fault; renumbering (C4) as a class
- ✅ Fix batch B1–B7; acceptance chain (2026-10-28): disagreements 211 → 142, family rules diff clean, golden from inputs 26/27 (RTA s.4(6): CV-S05f, known limit)
- ✅ Precision check: `mix lat.amending_check` (0b40fa64), skill `amending-reader-check` (1648bbba)
- ⬜ Agent seeds until the statistical rule passes (pooled 95% upper < 2% changes, < 5% pairs)
- ⬜ Quality statement and coverage table; CV-00 recipe step 6
- ⏸️ The reader's yield over the feed (2,658 read with no rule): not chased (CV-07)

## Dependencies

- ⬜ The steps before it passed (CV-00 order)

## Catalogue (2026-10-28)

`mix lat.amendment_patterns --family 'OH&S: Occupational'` (new; `Amendment.Patterns`, `Patterns.Example`, `PatternSource`; 3½ min, one at a time with a VM running). Population: the provisions the read pass reads for the family's 149 laws (notes' and feed's pointers, per amended law): 3,285 provisions in 453 amending laws (1 not held), 90 patterns, 208 examples. Each example is the amending law pruned to the provision's top provision, its containers' titles and the fewest earlier provisions that give the same class (all 208 faithful, 2.5 MB). `AmendmentPatternsTest` pins each.

Pattern key: `shape|verb|quote|place|law|outcome`. Shape: table, modification, set_out, no_verb or instruction. Place: whether the instruction or a holding provision names a Schedule or Annex. Law: whether the amended law is named where the reader looks.

| outcome | provisions |
|---|---|
| rules | 1,223 (37%) |
| none: no verb (headings "In section 5—", "… amended as follows") | 898 |
| none: law not named where the reader looks (pointer imprecision, self-amendment, another law) | 680 |
| none: law named, verb, body (the yield, CV-07: not chased) | 270 instructions + 22 table lines + 1 modification |
| none: law named, verb, Schedule place (v0.1 limit: Schedules not parsed) | 191 |

**Misread classes found** (bugs block):
- **B1 Schedule paragraph as regulation:** 59 provisions in rule patterns with a Schedule place. Every example checked is wrong except "section 75 and Schedule 7 are repealed" (s.75, right).
- **B2 Many laws' provision lists:** other laws' items taken as the amended law's targets (2 examples).
- **B3 Heading and punctuation substitutions** read as the whole provision (2).

Level mismatches otherwise checked right: a block quoting a definition's words is words-level; "for regulation 2 substitute—" quoting words is the whole regulation.

## Census of the 211 disagreements (2026-10-28)

`s06_census.json` (scratch: `Conflicts.report` items with each amending provision's catalogue class, its rules and legislation.gov.uk's effects by the same law). Triaged by hand, item by item:

| kind | n | classes |
|---|---|---|
| law text only (`uncovered :derived`) | 65 | B1 Schedule paragraph 24; legislation.gov.uk's effect recorded but unapplied (`Applied=false`: the backlog the reader is for) 5; legislation.gov.uk records "amended" (no operation) 3; Acts amended before the feed's records (1920–1992 repeals; no effect by that law at all) ~17, each checked right against the law; join miss (the effect is there on the same provision: CV-S07) ~9; reader misread: B5 3, B4 1 (s.11(2) for s.11(2A)), B1-caption 1 (2013 c.32 "Schedule 2 (… etc. …) is amended" → s.4); a recent SI with no effect recorded at all (SI 2022/372 reg.46 → HSWA s.28(6)) 1 |
| unjoined | 60 | several legislation.gov.uk effects by the same law on one provision, the merge not choosing (CV-S07) ~35; B5 (parent for the child) ~10; B1 10; the repeals table (1989 c.38 Sch.7, right against the law; legislation.gov.uk's twin a later insertion) 2 |
| value: level | 56 | B5 ~14; B7 ~12; B6 8; B3 2; legislation.gov.uk's markup coarse (whole text for a words change, or words for "For regulation 19 substitute—"; the law right) ~20 |
| value: operation | 11 | the law says insert, the markup shows Substitution (the law right) 4; B2 4; the law's own slip ("for “…” insert", SI 2023/284) 1; "repealed" words-level vs the feed's "repealed in part" (the same fact: a like-for-like gap in `Conflicts`) 2 |
| value: date | 19 | the commencement reader's (CV-S04): not judged here |

**Renumbering (C4):** no item in the census is a renumbering. Not built; it stays a CV-04 provision fact.

**Fix batch (B1–B7, with B1 widened):**
- **B1, Schedule place:** `Reader.Scope` (new; `in_schedule` and `articles_only` moved from `Reader`). A Schedule or Annex named in the instruction or a holding provision, with unicode matching and a case-sensitive number, and no section or regulation named (a title's year never counts). The amending law's own Schedule ("set out in Schedule 4", "this Schedule") is not a place. A holding provision's caption no longer hides "Schedule 2 … is amended".
- **B2:** an instruction naming three or more laws (by year) gives no rule.
- **B3:** a heading or a mark itself changed is words-level. A provision going with its heading stays whole.
- **B4:** a block "set out in sub-paragraph (N)" of the same provision is the quote.
- **B5:** treatment `:quoted` on quote rules. The vocabulary filters to the law's rows first, then takes a quote's top and a named place's deepest.
- **B6:** a provision named with its joining word is whole.
- **B7:** a quote numbering provisions is provision-level, except a quoted definition.

Pre-flight (regression set, 279 amending laws, `--preview`, then a treatment-blind diff over the 96 laws whose rule counts changed): 443 fewer rules. Every removal checked: Schedule or Annex paragraphs 359, many-laws lists 46. Changes: headings to words 58. No additions. Collateral found and fixed on the way: "heading" anywhere had made "Omit section 27A … and the heading preceding it" words; the case-insensitive "Schedule is" had matched as a Schedule number. Tests: `reader_s06_test.exs` (15; 6 fail on the old code). Catalogue after the batch: 81 patterns, 185 examples, all faithful; Schedule-place provisions with rules 59 → 3 (two right, one logged open: SI 1974/1941).

## Acceptance chain, batch 1 (2026-10-28)

Restore point `cv-s06-batch1` (amendment_rules, extent_rules, provision_changes, provision_change_claims); snapshots `r6b.s06_rules_before`, `r6b.s06_claims_before`.

- **Read pass** (`mix lat.amending --read`, one law at a time): 2,102 laws read, 959 changed, rules 43,678 → 42,758; no errors.
- **Family rules diff** (before vs after, the family's amended laws): Schedule or Annex paragraphs dropped 59, many-laws lists 4, level or operation changed 22, added 2 (HSWA s.11(2A), "insert a comma"). Each checked.
- **`--check` on the family** (conflicts over 149 laws):

| kind | before | after |
|---|---|---|
| law text only | 65 | 32 |
| unjoined | 60 | 45 |
| value: level | 56 | 38 |
| value: operation | 11 | 8 |
| value: date | 19 | 19 |
| read, no rule (yield) | 2,658 | 2,635 |

- **Golden:** `--check` scores 19 golden laws outside the family from their stored changes (27/27). From inputs (`--golden`): 26/27. The failure, RTA 1988 s.4(6) (repealed everywhere from 2006; expected in force in Scotland), is not this batch. SOCPA 2005 Sch.7 para 27(4), "The repeal of section 4(8) extends also to Scotland", is unread since CV-S05 round 6, so the bound is withheld. Before that the paragraph silently took the E+W default. A bound per amending provision can't be right for both s.4(6) and s.4(8) (para 27(2) repeals both), so the faithful fix is extent rows naming the amended target: **CV-S05f** (PENDING, Jason 2026-10-28: straight after S06's agent seeds). Known limit until then.
- **Lesson:** a golden law outside the family is scored from stored changes by `--check`. Every acceptance chain must also run `--golden` from inputs, or a reader change upstream goes unseen. CV-S05's closing golden runs missed this one.
- Catalogue fixtures regenerated, effect ids shortened in the pruned XML (`Patterns.Example.export`): 81 patterns, 185 examples.

## Agent seeds

Population: 1,171 family changes the law's text states (both sources 1,094; law text only 77). The statistical rule pools seeds after the last fix batch.

| Seed | Changes | Pairs | Result |
|---|---|---|---|
| 31 | 49 OK / 1 WRONG / 0 doubtful | 47 / 48 OK | FAIL, 1 NEW: ssi 2008/339 art.5(2) "In paragraph (f)(i) of subsection (3) …" stored a change on HSWA s.28. HSWA's CLML names s.28(3)(f)(i) `section-28-f-i`, so the reading s.28(3) survived beside s.28(f)(i), and placement lifted it to s.28. Fixed (`35f29731`): the longest held spelling of each reading, law-text targets respelt via `xml_ids`. Pre-flight: 6 of 6,214 family and golden rules change, all intended. Chain 2: law text only 32 → 29, unjoined 45; golden 26/27 (CV-S05f). |

The pool restarts after this fix: seeds 32 onward.

## Starting point (2026-10-28, from run-07's family chain)

`mix lat.vocabulary --conflicts --family 'OH&S: Occupational' --all` (stored changes, 6 s) over 149 laws:

| kind | count | meaning |
|---|---|---|
| law text only, no legislation.gov.uk record (`uncovered :derived`) | 65 (46 law/amender pairs) | backlog candidates (CV-07 counted 84) |
| unjoined | 60 (25 pairs; 17 HSWA ← SI 2008/960) | a law-text change beside a legislation.gov.uk change on a nearby provision: likely one event |
| value conflicts | 86 (level 56, date 19, operation 11) | the law's text and legislation.gov.uk disagree on one change |
| read but no rule (`uncovered :primary`) | 2,658 | the reader's yield: not chased (CV-07) |
| unread | 662 | amending provision not read: coverage |

The law's text wins where it speaks (source authority), so a wrong reading by this reader overrides a right one from legislation.gov.uk. Its precision is never measured.

## What good looks like (accepted 2026-10-28)

1. **Catalogue first** (as S02–S05): `mix lat.amendment_patterns`, every instruction sentence the read pass reads for the family classed by form (substitute, insert, omit, repeal-table entry, heading, …), with examples pinned in a test; new forms decided until the test passes.
2. **Census of the 211 disagreements** (65 + 60 + 86; small enough to do in full, no sample): each item classed as
   - backlog: the law states it and legislation.gov.uk has no record, unapplied effects included;
   - reader misread (wrong target, operation or level): fixed;
   - join miss: logged for CV-S07 (merge);
   - legislation.gov.uk fault: known class.
   Pass: every item classed, no reader misread left unfixed.
3. **Precision on a sample** (`mix lat.amending_check --family F --sample --n 50 --seed N`): changes the law's text states (both sources and law text only); an agent judges target, operation, level and by against the amending law's text. Dates are CV-S04's and territory CV-S05's, so they are not judged here. Pass by the statistical rule: seeds pooled since the last fix batch, every NEW fixed, 95% upper bound of wrong changes < 2% and of (amended law, amending law) pairs < 5%.
4. **Renumbering (C4):** a target named by an old number resolves to the current one. Measured as a census class (2) first; built only if it counts.
5. Quality statement and coverage table at close, CV-S05's model.
