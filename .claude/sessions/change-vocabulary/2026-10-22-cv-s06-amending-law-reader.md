---
session: 'CV-S06: Amending-Law Reader'
status: closed
release: v0.1
opened: '2026-10-22'
closed: '2026-10-28'
outcome: success
parent: change-vocabulary/2026-10-21-cv-00-meta.md

summary: >
  The amending-law reader (Amendment.Reader → law_text claims) passed the revised acceptance check on OH&S in
  round 5: the disagreeing (77) and law-text-only (34) changes checked in full with no misread left, the agreeing
  stratum (1,063) sampled with 0 wrong of 160 pooled (95% upper 1.85%) and 0 of 86 pairs (3.42%). Agreement with
  legislation.gov.uk over 1,095 both-sourced changes: amending law 100%, operation 99.5%, level 99.2%; golden from
  inputs 26/27 (RTA s.4(6): CV-S05f). See "Quality statement".

decisions:
  - what: "Revised check (Jason 2026-10-28): strata A agreeing / D disagreeing / L law text only; D and L in full, A by pooled agent samples"
    why: Random seeds put ~49 of 50 items where legislation.gov.uk already vouches; the misreads sat in the disagreements and law-text-only changes
    result: Round 4 found 7 wrong in D+L in one pass (seeds 31-33 had found 1 each); A pooled 0/160
  - what: Golden from inputs on every chain (`mix lat.vocabulary --golden`), never only `--check`
    why: --check scores out-of-family golden laws from stale stored changes; an upstream reader change went unseen (RTA s.4(6))
    result: Known limit found and placed (CV-S05f PENDING)
  - what: "A definition's limb with no row of its own is words in the provision defining (`:in_definition` treatment); a held limb stays whole"
    why: "The first fix (every rule under a definition words) turned held rows (SI 2008/1597 reg.2(ba)) to words; a general 'fallback is words' rule would flip bracket-combination artefacts ('paragraphs (f)–(i)')"
    result: COSHH reg.2(1) (GB, NI) now agree with the feed; 96-law rules diff otherwise unchanged in level
  - what: Fix round 4's misreads only, leaving yield gaps logged (Jason 2026-10-28)
    why: The pass rule is about misreads; yield is CV-07's
    result: Ranges and two-operation clauses logged as bugs (open)

metrics:
  strata_at_close: { population: 1174, agreeing: 1063, disagreeing: 77, law_text_only: 34 }
  agreement_both_sourced: { compared: 1095, by: "1055/1055 (100%)", operation: "1090/1095 (99.5%)", level: "1086/1095 (99.2%)", same_row: "1016/1095 (92.8%)" }
  agent_rounds: { seed31: "49/50, pairs 47/48", seed32: "50/50, 33/33", seed33: "49/50, 38/39", round4: "D+L 7 wrong of 114; A 50/50", round5: "D+L 0 of 111; recheck 14/14" }
  pooled_A_at_close: { changes: "0/160 (95% upper 1.85%)", pairs: "0/86 (95% upper 3.42%)" }
  census: { start: 211, after_B1_B7: 142, at_close: "134 entries (45 unjoined, 34 law text only, 28 level, 19 date, 8 operation)" }
  coverage_oh_s_text_changes: { total: 4911, law_text: "1174 (23.9%)", feed_only_read_schedule: 831, feed_only_read_eu_article: 654, feed_only_read_body: 1150, feed_only_unread: 661, feed_only_other: 441 }
  catalogue: { patterns: 81, examples: 185 }
  golden_from_inputs: "26/27 (RTA 1988 s.4(6): CV-S05f)"

lessons:
  - title: Sample where the independent source can't vouch; check disagreements in full
    detail: Three uniform seeds of 50 found one misread each; checking the 114 disagreeing and law-text-only changes in full found seven at once. Agreement with an independent high-fidelity source is evidence; spend agent effort on the strata it doesn't cover.
    tag: data
  - title: A wide rules diff before the chain catches a fix that is right for its case and wrong elsewhere
    detail: Two of round 5's fixes (words under any definition; per-number brackets) passed their own tests but the 96-law diff showed held limbs turned words and brackets read from quotes, captions and context numbers. Narrowed before any write.
    tag: tooling
  - title: A new enum value needs every reader of the stored row, not just the writer
    detail: "`:in_definition` wrote fine but `Rule.from_row` used a hand list of names; six family laws failed the rebuild. Derive name maps from the value lists, and round-trip test every value."
    tag: schema
  - title: Golden scored from stored changes hides upstream changes
    detail: "`--check` scored out-of-family golden laws from stale stored changes (27/27) while from inputs RTA s.4(6) failed. Every chain runs `--golden`."
    tag: tooling

bugs:
  - pattern: "A Schedule's paragraph read as the amended law's regulation or section of that number: 'In Schedule 2, for paragraph 10 substitute—' → reg.10 and 11 provisions under it; 'Omit Schedule 5' → reg.26; 'In paragraph 4(2)(b) of Schedule 1—' → reg.2(2)(b). The guard (Reader.in_schedule) reads only a holding provision beginning 'In [Part|paragraph N of] Schedule N', misses a non-breaking space (no u flag), nested 'paragraph 1 of Part 3 of Schedule 6' and the instruction's own words"
    category: reader misread (target)
    module: Amendment.Reader (in_schedule)
    affected: 59
    fix: "schedule located when the instruction or a holding provision (unquoted, captionless, unicode) names Schedule N / Annex N and no section, regulation, article or rule: no rules while Schedules are not read as targets"
    status: fixed  # 24e5c371 (fix batch B1–B7)
  - pattern: "A list of many laws' provisions ('In the following provisions, for … substitute …— s.1A(8) of the 1953 Act; … paragraph 2(2) of Schedule 3A to HSWA; …', Sentencing Act 2020 Sch.24 para 443; 'The enactments are— … HSWA, section 60; …', 2022/31 Sch.1 para 1(2)) read with other laws' items as the amended law's targets (HSWA s.1A… ×125 'inserted'; s.113)"
    category: reader misread (target)
    module: Amendment.Reader / LawNamed.scoped
    affected: 2
    fix: "each law takes only its own item's provisions (the item naming it)"
    status: fixed  # 24e5c371 (fix batch B1–B7)
  - pattern: "Heading and punctuation substitutions read as whole-provision: 'For the heading substitute—' (under regulation 6) → reg.6 substituted; 'for the full stop at the end of sub-paragraph (b) substitute a comma' → reg.7(4)(b) provision"
    category: reader misread (level)
    module: Amendment.Reader.Clauses (operation level)
    affected: 2
    fix: "heading, full stop, comma, semicolon substitutions are words-level"
    status: fixed  # 24e5c371 (fix batch B1–B7)
  - pattern: "A named place's bracket readings ('subsection (6)(e)' → s.15(6), s.15(e), s.15(6)(e)) taken top-most by the change vocabulary as if a quote's tree: the parent marked changed (HSWA s.15(6) repealed for (6)(e); reg.14(1) substituted for 14(1)(c); s.28(3) for (3)(c)(iii)): 74 of the family's 521 provision-level rules carry such readings"
    category: reader misread (target)
    module: ChangeVocabulary.Readers.AmendingLaw (targets) / Amendment.Reader (treatment)
    affected: 74
    fix: "quoted rules carry treatment :quoted (top-most); a named place's readings filtered to the law's rows, then the deepest"
    status: fixed  # 24e5c371 (fix batch B1–B7)
  - pattern: "'after subsection (2) insert the subsection set out in sub-paragraph (2)' read as s.11(2) inserted (the anchor), not s.11(2A) (2005 c.14 Sch.3 para 3(1)(b))"
    category: reader misread (target)
    module: Amendment.Reader (set_out)
    affected: 1
    fix: "the block set out in a sibling sub-paragraph is the quote"
    status: fixed  # 24e5c371 (fix batch B1–B7)
  - pattern: "A provision omitted with the word joining it ('omit sub-paragraph (d) and the word “or” preceding it') read as words: the quoted conjunction made the clause words-level"
    category: reader misread (level)
    module: AmendingLaw.Operation (words?)
    affected: 8
    fix: "a provision named then 'and the [word] “…” preceding/following/at the end' is whole"
    status: fixed  # 24e5c371 (fix batch B1–B7)
  - pattern: "A quote numbering provisions ('In paragraph (l), at the end, for “.” substitute— (m) …; (n) …') read as words in the new paragraphs"
    category: reader misread (level)
    module: Amendment.Reader (quoted rule)
    affected: 10
    fix: "a quoted rule with numbered provisions is provision-level, unless it quotes a definition (its lettered paragraphs are words)"
    status: fixed  # 24e5c371 (fix batch B1–B7)
  - pattern: "A list of sections with a Schedule entry ('sections 7, 8(2) and the entry in Schedule 2 relating to section 124(2) …', SI 1974/1941 reg.5(1)) read as s.7(2), s.8(2), s.124(2): the bracket carried to s.7 and the entry's section taken as the law's"
    category: reader misread (target)
    module: Amendment.Reader.Targets
    affected: 1
    fix: "91211e44: a bare number listed beside bracketed ones is whole (Targets.named_for); the entry in Schedule N relating to … dropped (Clauses.no_schedule_entries)"
    status: fixed
  - pattern: "A named place's partial readings kept beside its held one when the amended law's CLML skips a level (HSWA s.28(3)(f)(i) is section-28-f-i): 'paragraph (f)(i) of subsection (3)' gave s.28(3) and s.28(f)(i); the s.28(3) change was then placed on s.28 (seed 31 NEW, ssi 2008/339 art.5(2))"
    category: reader misread (target)
    module: ChangeVocabulary.Readers.AmendingLaw (targets) / ChangeVocabulary.build
    affected: 6
    fix: "each full reading resolved to its longest held spelling, shallower places dropped; law-text targets respelt to rows via xml_ids (35f29731)"
    status: fixed
  - pattern: "A whole provision made by a quote below a words change folded into the words change by the merge, so the parent read as substituted whole (HSWA s.51A(2)(a), (c); s.23(4)); and a quoted lone (i) under a lettered paragraph read only beside it (s.51A(2)(i), not (c)(i)) — seed 33 NEW"
    category: reader misread (level) / merge
    module: ChangeVocabulary.Merge (inside_words?) / Amendment.Reader.Targets (quoted_paths)
    affected: 4
    fix: "bd0ff6de"
    status: fixed
  - pattern: "A quoted limb of one definition ('In regulation 2(1)— in the definition of “substance hazardous to health”— for paragraph (a), substitute— (a) …') read as provision-level: the law holds no reg.2(1)(a), the change falls back to reg.2(1) and says the whole of it was substituted (COSHH 2002/2677 by 2015/21 reg.12(2)(i)(ii); NI 2003/34 by 2015/265 reg.9(2)(j)(ii)) — round 4 NEW-1 (D)"
    category: reader misread (level)
    module: Amendment.Reader (quoted rule) / AmendingLaw.Operation
    affected: 2
    fix: "91211e44, 51088da8: :in_definition treatment — an instruction rule under a parent naming a definition is words where its target falls back to the provision defining; a held limb stays whole; a quote's change wins over its named place on one row"
    status: fixed
  - pattern: "A quote whose provision number is plain text, not a numbered P ('After regulation 5(3)(b) insert the following— ; or (c) information …'): quoted_provisions empty, so the anchor reg.5(3)(b) is read as inserted whole, not reg.5(3)(c) (SI 1989/682 by 2009/606 reg.2(3), (4)) — round 4 NEW-2 (D)"
    category: reader misread (target)
    module: AmendingLaw.Text (inserted) / Amendment.Reader.Targets
    affected: 2
    fix: "91211e44: Text.inserted reads a BlockAmendment's leading '(x)' (after '; or'/'and') when it has no numbered provision"
    status: fixed
  - pattern: "A repeals-table line naming a provision with its joining word ('Section 1(1)(d) and the word “and” preceding it'; 'Section 27(2)(b) and the word “or” immediately preceding it') read as words (treatment repeal_table); B6's whole-provision rule reaches instructions only (EPA 1990 Sch.16 on HSWA s.1(1)(d); Electricity Act 1989 Sch.7 on HSWA s.27(2)(b)) — KR"
    category: reader misread (level)
    module: Amendment.Reader (repeal table) / AmendingLaw.Operation
    affected: 2
    fix: "91211e44: RepealTable drops a provision's joining-word clause before reading the line"
    status: fixed
  - pattern: "A range of provisions not expanded: 'in paragraphs (1)(b)(i) to (iii)' gives (i) and (iii), not (ii) (SI 2008/1597 by 2019/696 Sch.12 para 8(a)); 'Section 63(1) to (4)' gives (1) and (4) (HSWA by 1982 c.30 Sch.7, harmless: no rows between)"
    category: reader gap (target, yield)
    module: Amendment.Reader.Targets
    affected: 2
    fix: "expand 'X to Y' between siblings at the same depth, held rows only (LatRef range cover)"
    status: open
  - pattern: "Two instructions in one clause, the first dropped: 'after “a notifier” add “or applicant” and for “2001” substitute “2015”' gives only the substitution (NI 2012/255 reg.8(1) by 2015/339 reg.34(2)(b))"
    category: reader gap (yield)
    module: AmendingLaw.Operation / Amendment.Reader
    affected: 1
    fix: "a clause with two operations joined by 'and' gives a rule for each"
    status: open
  - pattern: "Amendment reader drops a context's subsection: \"In section 43(1) …— (a) omit the 'or' at the end of paragraph (h)\" targets s.43(h), not s.43(1)(h) (PCA 2017 Sch.1 para 94(3))"
    category: reader misread (target)
    module: Amendment.Reader.Targets / ChangeVocabulary.Readers.AmendingLaw
    affected: 2
    fix: "24e5c371 (B5): a named place's bracket readings all listed, the deepest held taken (rule now {s.43(1), s.43(h), s.43(1)(h)})"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/patterns.ex, patterns/example.ex, pattern_source.ex, lib/mix/tasks/lat.amendment_patterns.ex
  - backend/lib/sertantai_legal/scraper/amendment/check_sample.ex, check_strata.ex, lib/mix/tasks/lat.amending_check.ex
  - backend/lib/sertantai_legal/scraper/amendment/reader/scope.ex (B1, B2)
  - backend/test/fixtures/amendment_patterns/ (catalogue)
  - backend/test/sertantai_legal/scraper/amendment/reader_s06_test.exs, check_strata_test.exs, amendment_patterns_test.exs
  - .claude/skills/amending-reader-check/SKILL.md

depends_on:
  - 2026-10-22-cv-s05-extent-reader.md

enables:
  - CV-S05f target-named extent statements (PENDING, next)
  - CV-S07 merge (unjoined twins logged)
  - CV-S06 for further families (recipe step 6)
---

# Session: CV-S06: Amending-Law Reader (CLOSED)

## Problem

Step 6 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Per the source-use balance (CV-07, Jason 2026-10-22): find the changes legislation.gov.uk hasn't recorded yet (the backlog) and check theirs; coverage of the feed is not the target.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (accepted by Jason 2026-10-28): catalogue, census of the 211 disagreements, precision seeds on the statistical rule, renumbering as a census class, quality statement
- ✅ Catalogue (B1–B3 found; statuses after the fix batch): `mix lat.amendment_patterns` over the family's read instruction sentences, classed by form, examples pinned in a test; new forms decided
- ✅ Census of the 211 disagreements (B4–B7 found; the rest legislation.gov.uk, the merge's, or right; no renumbering) (65 law text only, 60 unjoined, 86 value): each classed backlog / reader misread / join miss / legislation.gov.uk fault; renumbering (C4) as a class
- ✅ Fix batch B1–B7; acceptance chain (2026-10-28): disagreements 211 → 142, family rules diff clean, golden from inputs 26/27 (RTA s.4(6): CV-S05f, known limit)
- ✅ Precision check: `mix lat.amending_check` (0b40fa64), skill `amending-reader-check` (1648bbba)
- ✅ Revised check built: `--strata`/`--stratum`/`--skip` in `mix lat.amending_check` (123f61a5), seeds 31–33 classed
- ✅ Round 4 (seed 34): A pooled passes; D and L in full FAIL: NEW-1, NEW-2, KR
- ✅ Round 5: fix batch (91211e44, 51088da8), chain 4, D and L re-checked: PASS (A 0/160, 1.85%; pairs 0/86, 3.42%; D/L no misread; golden 26/27 bar CV-S05f)
- ✅ Quality statement and coverage table; CV-00 recipe step 6
- ⏸️ The reader's yield over the feed (2,658 read with no rule): not chased (CV-07)

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01–S05 closed

## Quality statement (2026-10-28): why the amending-law data is held to be good

The record to come back to, and the basis for publishing accuracy. Figures as of reader `51088da8` on OH&S: Occupational (149 laws with LAT).

### What the data is

For each change an amending law makes to a family law, what its own text says it does: the amended law, the target provision, the operation (inserted, substituted, repealed) and the level (words in a provision, or the provision whole). `Amendment.Reader` reads each amending law into `amendment_rules`; `ChangeVocabulary.Readers.AmendingLaw` turns them into `law_text` claims on `provision_changes`, joined with legislation.gov.uk's feed and markup by the merge. The law's text is primary and wins where it speaks (source authority), so this check measures precision: a misread would override a right record. Dates (CV-S04) and territory (CV-S05) are other readers'.

**Design rule:** a target the amended law doesn't hold is no change; a named place resolves to its deepest held reading; a quote's provisions to its top; a definition's limb with no row of its own is words in the provision defining. Schedules of the amended law aren't parsed (v0.1), so an instruction placed in one gives no change.

### How it was checked: four layers

1. **Catalogue** (`mix lat.amendment_patterns`): the family's read instruction sentences classed by form, verb, quote, place, law and outcome — 81 patterns, 185 pruned real examples run as tests (`test/fixtures/amendment_patterns/`); every reading change reviewed per fix batch.
2. **Census** of disagreements with legislation.gov.uk (`Conflicts`): 211 at the start, each classed; B1–B7 and the round-4 misreads fixed; 134 entries left (45 unjoined, 34 law text only, 28 level, 19 date, 8 operation; a value conflict counts once per derived source) — every change behind them classed (strata D and L).
3. **Agreement with an independent source** over every change both state (1,095): amending law 100% (1,055/1,055 compared), operation 99.5% (1,090/1,095), level 99.2% (1,086/1,095), same row 92.8% (the rest joined to legislation.gov.uk's record above or below the provision the law named).
4. **Agent checks** (skill `amending-reader-check`, prompt and known classes written down): a separate Claude agent judges each change against the amending law's stored text and the amended law's rows. The strata (revised check, Jason 2026-10-28):
   - **D, disagreeing (77) and L, law text only (34): checked in full** — no sampling error. No misread left (round 5).
   - **A, agreeing (1,063): sampled** (seeds 31–34, reproducible draws), pooled over items unchanged since checked.

### Measured accuracy

| Round | Seeds / strata | Wrong | Result |
|---|---|---|---|
| 1 | 31 | 1/50 changes, 1/48 pairs | FAIL, fixed `35f29731` |
| 2 | 32 | 0/50, 0/33 | PASS |
| 3 | 33 | 1/50, 1/39 | FAIL, fixed `bd0ff6de` |
| 4 | D 81 + L 33 in full; A seed 34 | D+L 7/114; A 0/50 | FAIL, fixed `91211e44`, `51088da8` |
| **5** | **D 77 + L 34 in full; A pooled** | **D+L 0/111; A 0/160 changes (95% upper 1.85%), 0/86 pairs (3.42%)** | **PASS** |

Upper bounds are exact one-sided Clopper–Pearson. **What this supports:** with 95% confidence, at most 1.85% of agreeing changes are wrong, and D and L hold no known misread; over all 1,174 changes the law's text states, the wrong rate is bounded by 1.85% × 1,063 / 1,174 ≈ **1.7%** — at least 98% of the family's law-text changes name the right law, target, operation and level. Golden from inputs 26/27 (RTA 1988 s.4(6): CV-S05f, a territory limit).

### Coverage (4,911 OH&S text changes)

| Who states the change | Changes | Share |
|---|---|---|
| **The amending law's text** (with legislation.gov.uk 1,095; alone 79) | 1,174 | 23.9% |
| legislation.gov.uk only; its amending provision read, no rule — a Schedule target (v0.1 limit) | 831 | 16.9% |
| — an EU-law article target (EU law amended by UK SIs) | 654 | 13.3% |
| — a body provision (the reader's yield gap, CV-07) | 1,150 | 23.4% |
| legislation.gov.uk only; its amending provision not read (schedule targets 214; by EU-law amenders 322) | 661 | 13.5% |
| legislation.gov.uk only; beside an unjoined law-text change, or its amending law not indexed | 441 | 9.0% |

A change only legislation.gov.uk states keeps legislation.gov.uk's facts (derived tier); the law's text adds nothing there and overrides nothing.

### Caveats for publishing

- **One family.** Other families run the skill's steps (catalogue, census, strata, D+L in full, A sampled).
- **Precision, not yield.** The reader states 24% of the family's text changes; recall over the feed is CV-07's.
- **Agent judgement** is an AI review of the stored legal text, not a lawyer's sign-off.
- **Logged, not misreads:** ranges not expanded ("(1)(b)(i) to (iii)"), a clause with two operations giving one rule (yield); law-text changes left apart from an identical feed effect (CV-S07); target-named extent statements (CV-S05f).

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

## Revised check: agreement first, agents where the feed can't vouch (Jason 2026-10-28: "yes, write up the revised check")

**Why.** Random seeds of 50 put about 49 of each 50 on changes legislation.gov.uk also states. That is the part already best evidenced: a misread there must be matched by the same misread in an independent source to look right. The risk sits where the feed can't vouch: changes only the law's text states, and disagreements. The census already found most of this session's misreads (B1–B7) this way. Seeds 31–33's three NEW came from a law-text-only change (31) and a merged change hiding a level conflict (33).

**Strata** of the population P (the family's changes the law's text states; 1,168 at seed 32):
- **A, agreeing:** stated by both sources, joined, with no value conflict on operation or level (like for like: `Conflicts`' equivalences: law insert vs markup Substitution, words repeal vs "repealed in part").
- **D, disagreeing:** every census item. Value conflicts on operation or level, unjoined law-text changes, and law-text changes beside legislation.gov.uk's on a nearby provision.
- **L, law text only:** no legislation.gov.uk record on the change (`uncovered :derived`, plus law-text changes standing alone).

**The check, per round:**
1. **Agreement (automatic, all of A):** `mix lat.amending_check --strata` counts A, D and L, and the agreement rate on operation, level, target and amending law between the law's text and the feed/markup on every both-sourced change. It is published as a quality figure.
2. **D and L in full (no sampling):** every item classed, as in the census: our misread (fix), legislation.gov.uk coarse or unrecorded (known), the merge's (CV-S07), or the law's own slip. Large classes by pattern, the rest one by one; the agent checks L in batches of 50.
3. **A by sample:** an agent sample of 50 from A per round, for shared blind spots (a misread both sources happen to share, or one the merge hides).

**Pass:**
- D and L: no misread left unfixed or unclassed. A full census has no sampling error, so its count is exact.
- A: the pooled agent samples since the last fix batch give a one-sided 95% upper bound under 2% for wrong changes and under 5% for wrong pairs.
- Overall wrong-change rate, bounded: (D∪L misreads left, 0) + 2% × |A| over |P|, which is under 2%.
- Golden from inputs, all-pass bar the known limits (CV-S05f).

**Seeds already done count by stratum.** Seeds 31–33's items are classed A/D/L after chain 3; agreeing items checked clean join A's pool if no fix since touched them. The pool restarts after the seed-33 batch, as the rule says.

**Also for CV-S05f (extent):** the same agreement measure. `law_text.extent` (the extent reader's bound) against the feed's `effect_extent` and `territorial_application`, like for like, over every bounded change. Then agents on the disagreements and on the changes with no feed extent.

## Agent seeds

Population: 1,171 family changes the law's text states (both sources 1,094; law text only 77). The statistical rule pools seeds after the last fix batch.

| Seed | Changes | Pairs | Result |
|---|---|---|---|
| 31 | 49 OK / 1 WRONG / 0 doubtful | 47 / 48 OK | FAIL, 1 NEW: ssi 2008/339 art.5(2) "In paragraph (f)(i) of subsection (3) …" stored a change on HSWA s.28. HSWA's CLML names s.28(3)(f)(i) `section-28-f-i`, so the reading s.28(3) survived beside s.28(f)(i), and placement lifted it to s.28. Fixed (`35f29731`): the longest held spelling of each reading, law-text targets respelt via `xml_ids`. Pre-flight: 6 of 6,220 family and golden rules change, all intended. Chain 2: law text only 32 → 29, unjoined 45; golden 26/27 (CV-S05f). |

| 32 | 50 OK / 0 WRONG / 0 doubtful | 33 / 33 OK | PASS, no NEW. Noted, not a fault: a words insertion "In section 53 … at the appropriate place insert" lands on s.53 as named, while definitions "In regulation 2—" land on reg.2(1) where the merge joins legislation.gov.uk's record; SI 2013/602 Sch.2 para 57(2)(e) drafting slip ("In section 13(1)(a)" heading over "in subsection (4)"), read right (KD). |

| 33 | 49 OK / 1 WRONG / 0 doubtful | 38 / 39 OK | FAIL, 1 NEW: HSWA s.51A(2)(c) (2011 c.13 Sch.16 para 119(2)(b), "in paragraph (c), for “…” substitute “means— (i) … (ii) …”") stored as (c) substituted whole. The quote's (c)(ii) whole-provision claim joined the feed's words change on (c) through the merge, and the quote's lone "(i)" read only as s.51A(2)(i). Fixed (`bd0ff6de`): the merge keeps a whole provision made below a words change as its own change; a quoted lone i/v/x under a lettered paragraph reads as its numeral too. Pre-flight: about 20 family rules gain the missing (x)(i) target. Chain 3 (restore point `cv-s06-seed33`): read pass 56 laws changed; family changes: s.51A(2)(a) and (c) now words with own (i)/(ii), HSWA s.23(4) the same shape (SI 2005/1541, SSI 2006/475); level conflicts 38 → 33; golden 26/27 (CV-S05f). |

The pool restarts after this fix: seeds 32 onward (and again after seed 33's fix: seeds 34 onward, under the revised check). Pooled after seed 32: changes 0/50 (one-sided 95% upper 5.8%), pairs 0/33 (8.7%).

## Round 4: the revised check (2026-10-28, after chain 3)

`mix lat.amending_check --family 'OH&S: Occupational' --strata` (`123f61a5`, 8 s). Population P: 1,173 changes the law's text states (both 1,095; law text only 78).

| Stratum | Changes | Share |
|---|---|---|
| A agreeing | 1,059 | 90.3% |
| D disagreeing | 81 | 6.9% |
| L law text only | 33 | 2.8% |

**Agreement** over the 1,095 both-sourced changes: amending law 1,055/1,055 (100%), operation 1,090/1,095 (99.5%), level 1,084/1,095 (99.0%), target placed on the same row 1,016/1,095 (92.8%; the rest joined below or above the provision the law named).

**Seeds 31–33 by stratum (today's changes):** 31: A 49, 1 gone (its NEW, fixed); 32: A 45, D 4, L 1; 33: A 47 (one, s.51A(2)(c), changed by its fix), L 2, 1 gone. Every A item checked clean whose change is unchanged since joins A's pool: 134 distinct.

**A, seed 34** (`--stratum A`, repeat draw identical): 50 OK, pairs 37/37; known KB ×2, KM, KJ. 8 items already pooled. **Pooled A: 0 wrong of 176 distinct changes (95% upper 1.69%), 0 of 95 pairs (3.1%): passes.**

**D in full** (81, two agent batches; each item with its census entry and the feed's effects by the same law): 76 right (merge's, KJ 35; legislation.gov.uk coarser, KM 33; backlog 6; the law's slip 1); 5 wrong:
- NEW-1 ×2: a quoted limb of a definition falls back to reg.2(1) as provision-level (COSHH 2002/2677 by 2015/21; NI 2003/34 by 2015/265).
- NEW-2 ×2: a quote whose number is plain text ("; or (c) …") not read; the anchor reg.5(3)(b), reg.5(1)(b) read as inserted (SI 1989/682 by 2009/606).
- KR ×1: repeals-table "Section 1(1)(d) and the word “and” preceding it" read as words (EPA 1990).

**L in full** (33, one agent batch): 31 right (no legislation.gov.uk record, or recorded coarser or not paired: six with a feed twin the merge left apart, CV-S07); 2 wrong, both KR (SI 1974/1941 reg.5(1) s.8(2); Electricity Act 1989 Sch.7 on s.27(2)(b)).

**Seen in passing (yield, not judged):** ranges not expanded ("(1)(b)(i) to (iii)", "Section 63(1) to (4)"); a clause with two operations gives one rule (NI 2015/339 reg.34(2)(b)). Logged as bugs.

**Result: FAIL** on D and L (7 misreads: NEW-1, NEW-2, KR), A passes. Wrong changes in P now: 7 known in D∪L, plus A bounded at 1.69% × 1,059.

## Round 5: fixes and re-check (2026-10-28)

Fix batch (Jason: "Misreads only"), `91211e44` + `51088da8`:
- NEW-1: `:in_definition` treatment. An instruction rule under a parent naming a definition is words where its target falls back to the provision defining (COSHH reg.2(1)); a limb held as a row stays whole; where a quote and its named place reach one row, the quote's change stands. First tried as "every rule under a definition is words": the 96-law diff showed whole limbs held as rows (SI 2008/1597 reg.2(ba)) turned words, so narrowed. A general "fallback is words" rule was also rejected: bracket-combination artefacts ("paragraphs (f)–(i)" → reg.3(f)(i)) would flip right readings.
- NEW-2: a BlockAmendment numbering its provision in its text ("; or (c) …") makes that provision (SI 2009/606 → reg.5(3)(c), reg.5(1)(c)).
- KR: repeals-table "Section 27(2)(b) and the word “or” …" whole; "sections 7, 8(2) and the entry in Schedule 2 relating to …" → s.7, s.8(2) (a bare number in a mixed list is whole, outside quotes and captions; a Schedule entry beside sections is no target).
- Pre-flight: red tests (4 fail without the fixes), suites 4,890 pass, catalogue diff only the intended (2 misread patterns no longer seen), 96-law rules diff traced (per-number brackets first read brackets in quotes, context numbers and captions: tightened to written lists).
- `in_definition` rows first failed to read back (`Rule.from_row`'s names were a hand list; 6 family laws failed the rebuild): fixed `51088da8`, round-trip test for every treatment.

Chain 4 (restore point `cv-s06-round4`): read pass 143 laws changed (rules 42,758 → 42,746); rebuild 149 laws, no failures; golden from inputs 26/27 (RTA s.4(6), CV-S05f).

**Strata after:** A 1,063 · D 77 · L 34 (P 1,174). Agreement: amending law 100%, operation 99.5%, level 99.2% (was 99.0%), same row 92.8%.

**D and L in full:** 111 items; 102 unchanged since round 4 keep their verdicts (right); 9 changed or new plus the 4 NEW items now in A re-checked by agent: 14/14 right, no NEW. No misread left in D or L.

**A pooled** (seeds 31–34, items unchanged by the fixes): 0 wrong of 160 changes (95% upper 1.85%), 0 of 86 pairs (3.42%). **PASS.**

**Result: PASS** (revised check, Jason 2026-10-28). Open, logged, not misreads: yield gaps (ranges "(1)(b)(i) to (iii)", a clause with two operations); unjoined twins (CV-S07); RTA s.4(6) (CV-S05f).

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
