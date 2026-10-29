---
session: 'CV-S08: Evidence'
status: closed
release: v0.1
opened: '2026-10-22'
closed: '2026-10-29'
outcome: success
parent: change-vocabulary/2026-10-21-cv-00-meta.md

summary: >
  The evidence step passes for OH&S on the statistical rule decided before round 1: after four fix batches,
  round 5 has V 8/8, D wrong only in logged classes, and A 150/150 (95% upper 1.98%; pairs 0/81, 3.6%) carried
  from round 4 with its chosen values unchanged; golden from inputs 27/27. The table now ranks the feed above the
  markup for operation, reads the markup's level in three tiers, compares like with like, and commences Schedules
  with the provision that gives them effect.

decisions:
  - what: Operation order — the feed above the markup (law text and commencement first)
    why: Round 1 D, the feed's 'substituted' right 12/12 against the markup's Addition (how legislation.gov.uk marks a substitution's new words)
    result: Jason 2026-10-29; D operation patterns hold from round 2
  - what: Gap rule — a value no table source claims is a coverage gap, not WRONG
    why: Agents graded missing commenced_by both ways in round 2; one pool needs one rule
    result: Jason 2026-10-29; gaps published by cause in the quality statement
  - what: Fix every class in CV-S08 in batches, logged against its reader
    why: The evidence check surfaces readers' faults through wrong chosen values; one round per batch
    result: Jason 2026-10-29; four batches, readers' catalogues reviewed each time
  - what: KC-sch fixed in batch 2 — a Schedule commenced with its introducing provision
    why: NISR 2003/152 Sch.7 wrong date; Energy Act 2013 Sch.12 (56 changes) no commenced_by
    result: Commencement.ScheduleEffect; 2,702 rules; Energy Act Sch.12 commenced by SI 2014/251
  - what: Legacy markup Addition — no operation inside the text; round the number, inserted; never contradicts the law
    why: SIF-era Additions wrap text under a note whatever the change; golden Forestry Act s.1(4)(a) needs the insertion where nothing else speaks
    result: "Jason 2026-10-29 (twice: no operation, then number wrapped = inserted); V false conflicts gone in round 5"
  - what: Two-link 'as amended by' chains credit the feed's affecting law
    why: KX — the law whose words the provision now carries; the chain stays a pointer
    result: Jason 2026-10-29
  - what: Gemini review of the evaluator deferred
    why: Jason 2026-10-29 at close
    result: todo marked deferred

metrics:
  strata_final: { changes: 26492, V: 8, D: 40, A: 2019 }
  rounds: { r1: "V 27/63, D 42/102, A 47/50", r2: "V 15/21, D 41/70, A 147/150", r3: "V 12/15, D 36/44, A 146/150", r4: "V 8/12, D 32/39, A 150/150", r5: "V 8/8, D 32/35 (wrong only classed)" }
  a_pass: { wrong: 0, n: 150, upper95: 0.0198, pairs_wrong: 0, pairs: 81, pairs_upper95: 0.036, seed: 54 }
  value_conflicts: { start: 69, end: 8 }
  derived_disagreements: { start: 829, end: 40 }
  winners_final: { operation: "commencement 17652, feed 5028, law_text 1177, markup 180, none 2430", level: "commencement 17652, feed 4169, law_text 1177, markup 1119, none 2350", date: "commencement 19449, feed 5892, parts 8, none 1126", by: "feed 7284, law_text 1177, markup 237, none 17769", territory: "feed 1609, law_text 949, markup 43, law 2, none 23864" }
  gaps_text_changes: { text_changes: 4573, no_date: 609, dated_no_commenced_by: 2841, commenced_by: 1123 }
  golden: "27/27 from inputs"

lessons:
  - title: Golden from inputs caught a decision's side effect the agents could not
    detail: Dropping legacy Addition operations removed the 1999 credit on Forestry Act 1967 s.1(4)(a); the sample checks never drew it. The refined rule (number wrapped = inserted) came from the golden set, not a sample.
    tag: data
  - title: A fix to one reader exposes another's fault — pre-flight the strata, not just the tests
    detail: Commencing Schedules through their introducer took V from 21 to 70; 56 were one Energy Act 2013 misread ('Part 3' in a bracketed description) the new path routed onto Sch.12. The strata count before drawing caught it.
    tag: data
  - title: A markup signal can be right both ways — rank it, don't flip it
    detail: '"Covers all the text" was whole for Art 7(8) and words for reg.3(3)(e); batch 1 and batch 2 flipped the rule and each broke the other case. A weak tier below the feed ended it.'
    tag: data
  - title: Carry a pass over by comparing chosen values, not claims
    detail: Batch 4 changed claims (legacy operations, EU levels) but none of the 150 A chosen values; a before/after snapshot of the sample let A stand and saved a 5-agent round.
    tag: tooling
  - title: Agents need the grading rules for gaps written down
    detail: Round 2 agents scored missing commenced_by both as WRONG and OK; the gap rule went into the skill prompt after Jason's decision.
    tag: tooling

bugs:
  - pattern: "Operation order: markup Addition (inserted) outranks the feed's substituted; the feed is right 12/12 (every amending text says substitute)"
    category: evidence table
    module: ChangeVocabulary.Evidence
    affected: 14
    fix: "Feed above markup for operation (an Addition alone is how legislation.gov.uk marks a substitution's new words); markup Substitution vs feed inserted splits 2/2 — only the law's text settles it"
    status: fixed
  - pattern: "Level conflicts compared unlike for unlike: the feed's level for a parent or sibling at a child target; repealed_in_part vs repealed words"
    category: evidence table
    module: ChangeVocabulary.Conflicts
    affected: 12
    fix: "Compare a feed level only where its affected provision is the change's target; repealed_in_part = repealed at words"
    status: fixed
  - pattern: "Date conflicts compared unlike for unlike: the feed's first stage 'for specified purposes' (enabling powers) against the full commencement date; partial=true beside the completing date"
    category: evidence table
    module: ChangeVocabulary.Conflicts / Evidence
    affected: 7
    fix: "Compare first with first, full with full; partial judged at the chosen date"
    status: fixed
  - pattern: "Merge.precise/1 gives a note-ref-only placement a markup level :words — a level from a note (commencement stages, whole provisions repealed as dots, Pt modified)"
    category: pointer as fact
    module: ChangeVocabulary.Merge
    affected: 672
    fix: "A note-only placement claims no level; level falls to the feed"
    status: fixed
  - pattern: "commenced_by never emitted on an amendment change dated by commencement (the rule's source law dropped)"
    category: commencement reader
    module: Readers.AmendingLaw / Readers.Feed
    affected: 3688
    fix: "Emit {:commencement, :commenced_by, rule.source.law} with the date when it differs from by"
    status: fixed
  - pattern: "act_enactment 'all' rule (Royal Assent) outranks specific or by-order rules (ERA 2025 sch.12, PJA 2006 sch.15, Courts Act 2004 sch.1, Children (Scotland) Act 1995)"
    category: commencement reader
    module: Commencement
    affected: 11
    fix: "No act_enactment default for an Act whose commencement section defers to orders; a refs rule always beats all; no date → no claim (feed wins)"
    status: fixed
  - pattern: "Commencement exception list drops a last item after ', and' ('and 4(b)', 'and 17(1) to (3)')"
    category: commencement reader
    module: LawStart.Provisions
    affected: 3
    fix: "', and' one separator in the noun list (595ce2df)"
    status: fixed
  - pattern: "EU list items with no id (NumberOverride) placed on the Article as words, the feed's same event on the child row (REACH Art 3(18), CLP Art 2(17), Art 23(e)/(f))"
    category: markup reader
    module: Readers.Markup.ListItems
    affected: 13
    fix: "Place on the item's own row (provision id + number); whole when the change covers its text (d72ce36d)"
    status: fixed
  - pattern: "Markup level regression (batch 1): an Addition round all of a provision's text, number outside, read as words; EU Article repealed with only its Title wrapped read as words; note-only placement on a dotted row given 'beside' words"
    category: markup reader
    module: Readers.Markup / Merge.Precise
    affected: 9
    fix: "Additions whole, Substitutions with number outside words; a Repeal on an emptied row whole; :omitted flag (d72ce36d)"
    status: fixed
  - pattern: "Feed level from a parent compared on the law text's fan-out child; the feed's earlier partial stage compared with the law's full date (completion in a separate record)"
    category: evidence table
    module: Readers.Feed / Conflicts
    affected: 5
    fix: "feed.placed on every record; an earlier partial stage is like for like (d72ce36d)"
    status: fixed
  - pattern: "A schedule's commencement not traced through its introducing regulation (NISR 2003/152 Sch.7 Pt II via reg.15(2)); 'This section has effect from' unread (LGA 1985 s.84(3)); SOCPA s.178(1)(a) bare numbers after a parenthesis dropped"
    category: commencement reader
    module: Commencement.OwnClause / Readers.AmendingLaw
    affected: 2
    fix: "Schedule → the provision giving it effect: Commencement.ScheduleEffect (d72ce36d); list items past an aside (d229ba7b, a541f728). Still open: 'has effect from' (LGA 1985 s.84(3))"
    status: open
  - pattern: "Markup level: Substitution of a provision's whole text with its number outside read as provision; ';' remainder; Part <Number> wrapped still words; EU ListItem NumberOverride / id-less list own text; Correction wrapper"
    category: markup reader
    module: Readers.Markup
    affected: 15
    fix: "Number (group) counts; whole text only for a removal or a retained substitution's new version (595ce2df). Open: EU ListItem NumberOverride / id-less list own text (REACH Art 3 10A/10B, CLP Art 23(f))"
    status: fixed
  - pattern: "Feed reader: savings in a SectionRange dropped (store-wide 3,510 range-only); Type 'amended' gives level provision; '… heading', '… Text', 'Indent N' read as provision; '(EW)' in Type not read as extent"
    category: feed reader
    module: LegislationGovUk.ChangesFeed / Readers.Feed
    affected: 3510
    fix: "Savings .//Section/@Ref and range ends; 'amended' no level; suffixes → words; parenthesised extent → effect extent"
    status: fixed
  - pattern: "Amending reader: 'for X insert Y' read as inserted (is substituted); 'as it applies to Scotland / E+W' not read as territory"
    category: amending reader
    module: Amendment.Reader
    affected: 3
    fix: "for <quoted> insert = substituted; 'as it applies to X' a law_text territory claim"
    status: fixed
  - pattern: "Merge: an alias joins two events (SI 1995/2038 reg.6(8)); an EU ';' Substitution joined to an addition effect (CLP Art 23(f)); a substitution split Repeal+Addition left as a duplicate (SI 1998/494 reg.4(3)(e)n1); KX territory cut to the later law's extent"
    category: merge
    module: ChangeVocabulary.Merge
    affected: 4
    fix: "EU ';' join and chapeau joins fixed (list items on their rows d72ce36d; deepest markup joins first e1aded30). Open: KX territory (cut to the later law's extent: SI 2008/1597 reg.3), the alias (SI 1995/2038 reg.6(8)), a KX chain change left apart from the base law's own-text change (SI 2008/1597)"
    status: open
  - pattern: "Legacy markup (d29p…, M_F_…) Addition read as inserted whatever the change (Factories Act s.174(1) substituted; HSWA s.84(5), s.1(1)(d) repealed); its operation reported as a conflict with the law"
    category: markup reader
    module: Readers.Markup / Conflicts
    affected: 810
    fix: "Inside the text no operation; round the number inserted (Jason; golden Forestry Act s.1(4)(a)); a legacy operation never contradicts the law (a541f728, 3511120d, e1aded30). Factories s.174(1) stays inserted until its Schedule is read (KS)"
    status: fixed
  - pattern: "Markup level from 'covers all the text' wrong both ways; EU consolidation markup wraps the number on partial replacements; a heading's own ChangeId beside a whole substitution claims words"
    category: markup reader
    module: Readers.Markup.Level
    affected: 40
    fix: "Sure / covering / words tiers, covering below the feed; EU number wrap covering; heading wrappers claim no level (a541f728, e1aded30)"
    status: fixed
  - pattern: "Energy Act 2013 s.156(3) read 'Part 3' from a provision's bracketed description; SOCPA s.178(1)(a) aside broke the list"
    category: commencement reader
    module: LawStart.Provisions
    affected: 56
    fix: "Bracketed descriptions name no Part; nested asides break no list (d229ba7b, a541f728)"
    status: fixed
  - pattern: "Definitions list outside its P2 (COSHH 2002 reg.2(1)) and an empty CLML id segment (REACH article-2-6--d): one event as two changes"
    category: markup reader / ref
    module: Markup.ListItems.lead_in / Ref.from_clml
    affected: 13
    fix: "a541f728"
    status: fixed
  - pattern: "Feed Type error wins where the law's text makes no claim (REACH Art 138(1): feed 'inserted', para 95(3)(d) substitutes); moved words carried as renumbered (SI 1999/3242 reg.3(3))"
    category: evidence table
    module: Evidence (KF-type, KMV)
    affected: 2
    fix: "Read the amending provision (para 95(3)(d) has no rule); a 'moved' operation in the vocabulary"
    status: open
  - pattern: "Commencement orders held in the store but not read as rules (SI 1995/2950, 1997/1097, 2006/266, 2013/1869, 2016/603, 2020/1662; SSI 2009/319, 2013/51); SI 2015/994's 48 rules stored as commencing SI 2015/1637 (title-prefix match); a repealed commencement section falls back to Royal Assent (EPCA 1978)"
    category: commencement reader
    module: Commencement.Orders / LawStart
    affected: 60
    fix: "Read held orders' Schedules; resolve 'the Act' by the order's enabling Act; no Royal Assent default where the commencement section is gone"
    status: open
  - pattern: "Amending reader coverage: no rules at all for SI 2015/1682, SI 1999/2024, SI 2015/1637; no claim for whole-instrument revocations, 'in regulations 4 to 11, in each place', some plain body instructions (SI 2023/247 reg.4(b)(ii), SI 2020/660 reg.4, SI 2024/322 reg.15)"
    category: amending reader
    module: Amendment.Reader / ReadPass
    affected: 2841
    fix: "Coverage (CV-S06/CV-07): commenced_by gaps follow from it (2,841 OH&S text changes dated with no commenced_by)"
    status: open
  - pattern: "EU markup inside unnumbered ListItems placed on the Article, not its point (Directive 98/24 art.2(b)(i), (b)(iii))"
    category: markup reader
    module: ChangeVocabulary.Readers.Markup (placement)
    affected: 4
    fix: "Markup.ListItems: id-less EU list items on their own rows (d72ce36d)"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/evidence_strata.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/evidence_sample.ex
  - backend/lib/mix/tasks/lat.evidence_check.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge/precise.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/feed_savings.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/amending_commencement.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup/list_items.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup/level.ex
  - backend/lib/sertantai_legal/scraper/commencement/schedule_effect.ex
  - .claude/skills/evidence-check/SKILL.md

depends_on:
  - 2026-10-22-cv-s07-merge.md
  - 2026-10-22-cv-s06-amending-law-reader.md
  - 2026-10-22-cv-s04-commencement-reader.md

enables:
  - CV-S09 label fold (the merged changes' values are trusted on OH&S)
  - CV-S05g extent agreement measure
---

# Session: CV-S08: Evidence (CLOSED)

## Problem

Step 8 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each attribute from the right source by the agreed evidence table; disagreements reported like for like.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (Jason 2026-10-29: "Agree, build it"): strata V, D and A; pass rule below
- ✅ Build the acceptance check (`mix lat.evidence_check`, `evidence-check` skill; code 00d9b63d)
- ✅ Round 1 (seed 51): FAIL — V 27/63 OK, D 42/102, A 47/50; faults classed below
- ✅ Fix plan agreed (Jason 2026-10-29): operation, feed above markup; every class fixed in CV-S08 in one batch (logged against its reader)
- ✅ Fix batch 1 code (595ce2df): every class but the open residue; tests 9,507 pass; catalogues reviewed
- ✅ Fix batch 1 applied: restore point `cv-s08-fix1`, commencement re-read, read pass, rebuild; golden from inputs 27/27
- ✅ Round 2 (seed 52): FAIL — V 15/21 (1 wrong value, 5 false conflicts), D 41/70, A 147/150 (1 wrong: EU list item)
- ✅ Gap rule kept; KC-sch fixed in batch 2 (Jason 2026-10-29)
- ✅ Fix batch 2 code (d72ce36d), tests 9,510 pass
- ✅ Fix batch 2 applied (restore point `cv-s08-fix2`); the bracketed-description fix (d229ba7b); golden from inputs 27/27
- ✅ Round 3 (seed 53): FAIL — V 12/15 (3 false conflicts), D 36/44, A 146/150 (1 wrong)
- ✅ Legacy markup Addition claims no operation (Jason 2026-10-29)
- ✅ Fix batch 3 code (a541f728), tests 9,515 pass
- ✅ Fix batch 3 applied (restore point `cv-s08-fix3`); golden from inputs caught Forestry Act s.1(4)(a); legacy Addition round the number = inserted (Jason; 3511120d); golden 27/27
- ✅ Round 4 (seed 54): A PASS 150/150 (95% upper 1.98%; pairs 0/81, 3.6%); V 8/12 (4 false conflicts), D 32/39 (4 NEW + KMV, KF-type)
- ✅ Fix batch 4 (e1aded30): legacy operations never contradict; EU number wrap covers; the merge joins the deepest markup first. Golden 27/27; A's 150 chosen values unchanged (A carried over)
- ✅ Round 5 (seed 55): V 8/8; D 32/35, its wrong values only in logged classes (KX-territory, KF-type), 1 doubtful; with A carried over: PASS by the rule decided before round 1
- ✅ The table re-reviewed with Jason (2026-10-29, on round 1's evidence): operation, the feed above the markup
- ✅ Value conflicts checked in full every round (V: 63 → 8)
- ⏸️ A Gemini review of the evaluator (CV-04) (deferred — Jason 2026-10-29)
- ✅ Fixed until the check passed (round 5); quality statement below

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01–S07 closed PASS (CV-S07 Merge 2026-10-29); CV-S05g extent agreement PENDING (not a prerequisite)

## What good looks like (Jason 2026-10-29: "Agree, build it")

The unit is a merged change. Agents judge each chosen attribute against the sources' own records (`evidence-check` skill).

- **V, value conflicts:** the law's text or its commencement against legislation.gov.uk (63 changes, 69 conflicts). Checked in full: is each a real disagreement, like for like, and did the right side win?
- **D, derived disagreements:** the markup against the feed with no primary claim (829 changes, 16 patterns). The table's order alone chooses, and applies one rule to a pattern's items, so D is drawn by pattern, up to 10 of each (`--per`). Each pattern is judged: is the chosen value right?
- **A, agreeing:** several sources claim an attribute with nothing flagged (1,927). Sampled in batches of 50 on fresh seeds: is each chosen value right, and is no real disagreement unreported?

**Pass** (decided before round 1):
- V and D: no wrong winner, false conflict or wrong pattern left unfixed or unclassed.
- A: pooled samples since the last fix (items unchanged since checked) under 2% wrong changes and under 5% wrong (law, amending law) pairs, at the 95% Clopper–Pearson upper bound.
- Golden from inputs passes.

The session ends with a quality statement.

**D is dominated by one pattern:** 672 items are commencement stages where the markup's level (words) attaches to the stage and outranks the feed's (provision). This is for the table review.

## Inputs from CV-S07 (2026-10-29)

The merge's agents judged joins only. They met merged values that are this step's, from the evidence order:
- **Date:** HSWA s.51A(2E)(c) merged 2006-11-08, where the feed's only dated InForce is 2007-04-01 "wholly in force" (S.I. 2007/709). No source states 2006-11-08.
- **Operation:**
  - Factories Act 1961 s.178(1) merged "inserted" from a markup Addition, where the feed says "fees substituted" and the note "fee substituted".
  - REACH Art 138(1): the feed says "inserted", where the amending text (SI 2019/758 Sch.1 para 95(3)(d)) and the note say substituted.
- **The known coarseness:** the markup shows a substitution as an Addition (`Conflicts` `@agree`), common across the J samples. Check the evidence order resolves operation against the law text and feed, not the markup's element.
- **A note's cited law as `by`:** kept as the last fallback, the one documented exception (1,295 changes; `docs/CHANGE-IDENTITY-DESIGN.md` decision 3). Identity-only pointers never feed `by`: `:markup :cited_text`, `:note`, `:note_digest`, `:heading`, `:feed :uri_id`/`:named_at`.

The CV-S07 agent outputs were in a session scratchpad (not kept). The cases above are the record.

## Census at the start (2026-10-29, OH&S, read-only)

26,517 stored changes, of which 2,082 are stated by two or more of feed, markup and law text. Who won each attribute:
- **operation:** commencement 17,652, feed 4,157, markup 1,184, law text 1,177, none 2,339.
- **date:** commencement 19,385, feed 6,010, a parent through its parts 8, none 1,114.
- **by:** feed 7,347, law text 1,177, markup (a note's cited law) 215, none 17,770 (mostly commencements, which use `commenced_by`).
- **territory:** feed 1,495, law text 948, markup 43, the affecting law 2, none 24,021.

Value conflicts reported (primary against legislation.gov.uk): 69 in all.
- level: law text vs feed 25, vs markup 12;
- date: commencement vs feed 20;
- operation: law text vs markup 8, vs feed 4.

The markup and the feed disagree on operation in 52 changes. These are not reported, because both are derived; the table ranks the markup first.

## Round 1 (2026-10-29, seed 51): FAIL

Nine agents (V 3 × 21, D 4 × ~26, A 2 × 25).

| Stratum | OK | WRONG | doubtful | Pairs OK/WRONG/doubtful |
|---|---|---|---|---|
| V (63, full) | 27 | 34 (19 wrong values, 15 false conflicts only) | 2 | 20/24/2 of 46 |
| D (102 of 829, by pattern) | 42 | 55 | 5 | — |
| A (50) | 47 | 2 | 1 | 39/2/1 of 42 |

**Patterns in D:**
- by cited/affecting: the feed is right (KX); the rule holds.
- Operation inserted/substituted: the feed is right 12/12, so the rule fails (the table review). Substituted/inserted splits 2/2: only the law's text settles it.
- Level words/provision: mostly a note-only placement made words by `Merge.precise/1`. The feed is right for commencements (10/10), repeals (7/10) and repealed in part (4/4). The markup is right where the feed's provision is a deeper row, or for headings.

**Classes** (frontmatter bugs; owners):
- **The evidence step itself:**
  - the operation order;
  - level compared unlike for unlike (a parent's or sibling's level; repealed_in_part);
  - first date against full date.
- **A note as a level:** `Merge.precise/1`. 672 commencement items in OH&S carry a markup level.
- **The commencement reader:**
  - commenced_by never on an amendment (3,688 store-wide);
  - the Royal Assent fallback beating specific rules (11 changes, including the HSWA s.51A(2E) date from CV-S07);
  - an exception list's last item, a schedule's introducing provision, "has effect from".
- **The markup reader's level:** number outside the element; Part numbers; EU list items.
- **The feed reader:**
  - savings ranges (3,510 range-only Savings store-wide);
  - "amended" giving a level;
  - "heading"/"Text"/"Indent" suffixes;
  - "(EW)".
- **The amending reader:** "for X insert Y"; "as it applies to X".
- **The merge (4 cases):** an alias joining two events, an EU ";" Substitution, a split substitution's duplicate, a KX territory.
- **Vocabulary:** moved words ("renumbered"/"repositioned") have no operation (SI 1999/3242 reg.3(3)).

## Fix batch 1 (2026-10-29, code 595ce2df)

| Class | Fix | Where |
|---|---|---|
| Operation order | the feed above the markup (Jason) | `Evidence` |
| Feed level on another provision | `{:feed, :placed, target}` where the merge moves a feed record; the feed's level counts only there (`:placed_here`) | `Merge`, `Merge.Precise`, `Evidence`, `Conflicts` |
| Partial at a later date | partial is the date's own source's | `Evidence` |
| Unlike conflicts | in part = words omitted; the feed's first stage is not its completing date | `Conflicts.like?/5` |
| Note as level | a note-only placement claims no level, except beside the provision the feed names (Forestry Act s.1(4)(a)) | `Merge.Precise` (split from `Merge`, 346 lines) |
| Royal Assent default | dates only what no other rule reaches | `Readers.AmendingLaw.commencement/2` |
| commenced_by | the rule's law, with every commencement date (law text and note pointer) | `Readers.AmendingLaw`, `Readers.NoteDate` |
| ", and" in a list | one separator | `LawStart.Provisions` |
| Markup level | a group's `Number` is its number; new words round all of a provision's text are words (a removal or a retained substitution's new version stays whole) | `Readers.Markup` |
| Feed level | none without an operation ("amended"); "… heading/Text/Indent" are words (never a cross-heading) | `Readers.Feed` |
| Feed savings ranges | read from the raw pages (`ParserVersion` untouched) | `FeedSavings` |
| Feed bracketed territory | "(EW)", "(S)" in the type | `Readers.Feed` |
| for X insert Y | substituted | `AmendingLaw.Operation` |
| as it applies to X | the law text's territory | `Readers.AmendingLaw` |

Catalogue readings reviewed:
- **feed:** 676 levels plus 15 territories;
- **markup:** 26 (16 group rows become provision; 10 "Words … substituted" become words);
- **amendment:** 2 ("for … insert on each occasion");
- **commencement:** 1 (SI 2026/318: reg.16(3)–(5) now read).

**Left open** (logged):
- a schedule commenced through its introducing provision;
- "has effect from";
- EU list items;
- KX territory;
- three single merge cases;
- moved words, which now take the feed's "renumbered".

### Applied (2026-10-29)

- **Restore point:** `cv-s08-fix1` (commencement, amendment and extent rules; provision changes and claims).
- **Commencement re-read:**
  - own clauses: 1,066 laws, 1,623 rules;
  - amending laws: 1,541 laws, 2,391 rules.
  - No errors. SI 2004/3386 now holds reg.4(b).
- **Read pass:** 28 laws changed. A preview showed 13 of them were "after the entry for “X” insert", which is a place, not words replaced. That was fixed (1afed139), and a second pass changed 13 laws. Rules 42,799 throughout.
- **Rebuild:** OH&S rebuilt. Golden from inputs 27/27.
- **Strata after:** V 63 → 21, D 829 → 85, A 1,927 → 1,987. commenced_by now comes from commencement on 21,116 OH&S changes, up from 19,384 (the commencements alone).

## Round 2 (2026-10-29, seed 52): FAIL

Nine agents: V 21, D 70 by pattern (3 batches), A 150 (5 × 30; the redraw is identical by `cmp`).

**Gap rule (adjudicated for one pool):** a value no table source claims is a coverage gap, not WRONG. Examples: commenced_by with no commencement claim, or no date from any source. Agents graded these both ways, so they are regraded here. Gaps are listed with their cause.

| Stratum | OK | WRONG | doubtful |
|---|---|---|---|
| V (21, full) | 15 | 6: 1 wrong value (NISR 2003/152 Sch.7, KC-sch), 5 false conflicts | 0 |
| D (70 of 85) | 41 | 25 | 4 |
| A (150) | 147 | 1 (Directive 98/24 Art 2(b)(ii), EU list item) | 2 |

A: 1 wrong in 150 gives a 95% upper bound of 3.1%, above the 2% pass mark.

**Faults found:**
- **False conflicts:**
  - the feed's level for a parent (s.51A(2)(c), s.23(4)) on the law text's new child ((c)(i), (b)): the child carried no feed placement;
  - the feed's partial first stage against the law's full date where the completion is a separate feed record (HSWA s.47(7)).
- **D level, the markup reader:**
  - **(a) Regression from batch 1:** new text round all of a provision, its number outside, read as words (ukpga 1995/15 s.1(2A) inserted whole).
  - **(b)** An EU Article repealed whole, with only its Title wrapped and its text dots (Directives 2002/44, 2006/25, 2003/10).
  - **(c)** Points omitted to dots given words through the Forestry-Act "beside" exception (REACH Art 77(2)).
  - **(d) EU list items:** the markup places an id-less `ListItem` (`NumberOverride`) on the Article, while the feed's same event sits on the child row (REACH Art 3(18), CLP Art 2(17)…). That gives a words duplicate on the parent, and CLP Art 23(e)'s ";" joined to (f).
- **Merge:** a definitions list outside its P2 (SI 2002/2677 reg.2) leaves one feed effect in two changes.
- **The feed's type error** (REACH Art 138(1) "inserted" for "for … substitute") wins with no law-text claim. The amending reader did not read Sch.1 para 95(3)(d).
- **Commencement gaps (KC-sch):**
  - a schedule commenced through its introducing provision: Energy Act 2013 Sch.12 via s.116 (Part 3); NISR 2003/152 Sch.7 via reg.15(2);
  - an order in the store not read as rules: SI 1995/2950;
  - SOCPA s.178 bare numbers after a parenthesis.
  
  Energy Act 2013: 85 changes, all with commenced_by null.
- **Seen, outside the sample:** commencement rows at a law's own date on provisions inserted later (SI 2008/1597 reg.16A–C; ukpga 1995/15 s.1(2A)).

## Fix batch 2 (2026-10-29, code d72ce36d)

| Class | Fix | Where |
|---|---|---|
| EU list items | an id-less `ListItem` with `NumberOverride` placed on its own row (the provision's id and its number), whole when a change covers its text | `Readers.Markup.ListItems` (new) |
| Markup level (and batch 1's regression) | new text round all of a provision is whole; a Substitution with the number outside is words; a Repeal on a row whose text is gone is whole | `Readers.Markup.whole?/4` |
| Note-only on an emptied row | `{:markup, :omitted, true}`; never the "beside" words | `Readers.Markup`, `Merge.Precise` |
| Feed level on a fan-out child | every feed record carries `feed.placed` (its own target) | `Readers.Feed`, `Evidence.placed_here?/1` |
| Stage dates | the feed's earlier partial stage is no conflict with the law's full date | `Conflicts.like?/5` |
| D selection | a feed level placed elsewhere is no disagreement | `EvidenceStrata` |
| KC-sch | "Schedule N … has effect" / "amended in accordance with that Part" read as `:schedule_effect` rules (the introducer and its containers). The evaluator leaves them out; the amending-law reader dates a Schedule paragraph by its introducer where nothing more specific dates it. A Schedule Part becomes its paragraphs from the document (NISR 2003/152 Sch.7 Pt II = paras 8–9). | `Commencement.ScheduleEffect` (new), `Readers.AmendingCommencement` (split from `Readers.AmendingLaw`, now 253 lines), `LawStart` provision catalogue |

The catalogue changes were reviewed:
- **markup:** 9 readings (EU Articles repealed whole; list items on their own rows; s.78 repealed whole);
- **markup:** 230 `omitted` flags (order only otherwise).

### Applied (2026-10-29)

**First apply:** 2,702 `schedule_effect` rules; golden 27/27. But V rose from 21 to 70. Of those, 56 were Energy Act 2013 Sch.12 dated 2013-12-18 (Royal Assent).

The cause: s.156(3)(i) "section 114(1) (power to make transitional provision in relation to Part 3)" was read as bringing in Part 3 itself, and Sch.12 then took that date through s.116(1).

**The fix (d229ba7b):** a provision's description in brackets names no Part or Chapter. An aside in brackets also no longer breaks a list (SOCPA 2005 s.178(1)(a): 158, 167 … now read). Four commencement catalogue readings improve:
- SI 1988/1324 regs 11–15;
- Water Act 1989 Parts VII and VIII;
- Housing Grants Act 1996, no Part IV;
- ukpga 2003/30 s.5.

`--read` now passes the document too, so a Schedule Part resolves to its paragraphs.

**Second apply:** own clauses 2,654 rules; amending laws 4,062 rules; rebuild; golden 27/27.
- **Strata:** V 15, D 51, A 2,041.
- **Energy Act 2013:** 56 changes now commenced by SI 2014/251 on 2014-04-01; 28 are dated by the feed with no commenced_by (gaps).
- **NISR 1997/248 reg.20:** 2003-05-30.

## Round 3 (2026-10-29, seed 53): FAIL, much closer

Eight agents: V 15, D 44 (2 batches), A 150 (5 × 30; the redraw is identical).

| Stratum | OK | WRONG | doubtful |
|---|---|---|---|
| V (15, full) | 12 | 3 false conflicts (no wrong value) | 0 |
| D (44 of 51) | 36 | 6 | 2 |
| A (150) | 146 | 1 (Factories Act s.174(1): legacy `Addition` read inserted; the law, Sch.3 unparsed, substitutes) | 3 |

A: 1 wrong in 150 gives a 95% upper bound of 3.1%. Gaps (commenced_by, mostly) are listed by cause in each batch.

**Faults:**
- **V (all three):** a whole-regulation substitution's heading has its own ChangeId under the same effect (SI 2009/1348 regs 19, 20, 24). It claims words beside the whole provision.
- **D, markup level:**
  - "covers all the text" is unreliable both ways. A Substitution covering all of Art 7(8): the law says "For paragraph 8 substitute", so provision. An Addition covering all of reg.3(3)(e): the feed and law say words.
  - An Addition on an EU point later omitted to dots read as words (REACH Art 3(43)).
  - EU feed "Sentence 2" / "Unnumbered Paragraph" is words.
- **D, merge:** an EU chapeau word change (generic note) joined to the feed's Point replacement; the point's own markup left as a second change (REACH Art 119(1)(a), 56(6)(b)).
- **Doubtful (merge):** COSHH 2002 reg.2: a definitions list outside its P2 makes one event two changes. REACH `article-2-6--d`: an empty id segment makes a phantom row and a duplicate.
- **A:** legacy SIF markup (`d29p…`) `Addition` read as inserted where the law substitutes (Factories Act s.174(1)) or repeals (V: HSWA s.1(1)(d), s.84(5), ukpga 1972/28 s.5(1); law text won there).
- **Commencement:** SOCPA s.178(1)(a) still drops 158, 167 … (the aside holds nested brackets). Laws whose commencement section was repealed to dots fall back to Royal Assent (EPCA 1978, doubtful).

**Out of sample:** 48 SI 2015/994 rules stored as commencing SI 2015/1637 (a title-prefix match); commencement orders held but not read (KC-order).

## Fix batch 3 (2026-10-29, code a541f728)

| Class | Fix | Where |
|---|---|---|
| Markup level both ways | Three kinds of level claim. **Sure whole:** the number is wrapped, or a Repeal (or a dotted Addition) sits on a row whose text is gone. **Sure words:** the change covers part of the text. **Covering** (`:level_covering`): the change covers all the words with the number outside, ranked below the feed. | `Readers.Markup.Level` (new), `Evidence` |
| Heading wrapper | A heading's own record beside its provision's whole one claims no level. | `Markup.Level.heading_wrappers/1` |
| Legacy Addition | Places the change, claims no operation (Jason). 810 changes store-wide took "inserted" from it alone. | `Readers.Markup` |
| Definitions list after a lead-in | The list is the lead-in paragraph's (COSHH 2002 reg.2(1)). | `Markup.ListItems.lead_in/2` |
| Empty id segment | `article-2-6--d` is Art 2(6)(d). | `Ref.from_clml/2` |
| EU feed parts | "Sentence N", "Unnumbered Paragraph", "L N" are words. | `Readers.Feed` |
| Nested aside | An aside with its own brackets breaks no list (SOCPA s.178(1)(a)). | `LawStart.Provisions` |

**Catalogues reviewed:**
- **markup, 141 changes:**
  - 119 legacy operations dropped;
  - 16 covering levels;
  - 3 lead-in lists;
  - 3 heading wrappers.
- **feed, 20 changes:** EU sentence parts.

**Left open (logged):**
- a feed Type error with no law-text claim (REACH Art 138(1));
- KM-EU chapeau joins (REACH Art 119(1)(a), 56(6)(b));
- moved words;
- commencement orders held but unread (KC-order);
- SI 2015/1637's misattributed order rules;
- a repealed commencement section falling back to Royal Assent;
- "has effect from".

### Applied (2026-10-29)

- **Commencement re-read:** own clauses 2,654 rules; amending laws 4,062. Rebuild done.
- **Golden from inputs failed 26/27:** Forestry Act 1967 s.1(4)(a) lost its 1999 credit (SI 1999/1747). The insertion is known only from a legacy Addition wrapping the whole paragraph, number included, with no feed record.
- **Jason's decision:** a legacy Addition round the provision's number claims inserted; inside the text, nothing (3511120d). 83 catalogue readings came back. Golden is 27/27 again; the rebuild is done.
- **Strata:** V 12, D 44, A 2,011.

Factories Act s.174(1) is a whole subsection replaced through an unparsed Schedule. It stays "inserted": a known limit until schedules are read (KS).

## Round 4 (2026-10-29, seed 54): A passes; V and D do not

Eight agents: V 12, D 39 (2 batches), A 150 (5 × 30; the redraw is identical).

| Stratum | OK | WRONG | doubtful | Pairs |
|---|---|---|---|---|
| V (12, full) | 8 | 4 false conflicts (every chosen value right) | 0 | 7/11 |
| D (39 of 44) | 32 | 6 (4 NEW, KMV, KF-type) | 1 | — |
| **A (150)** | **150** | **0** | **0** | **81 distinct, 0 wrong** |

**A: PASS.** 0 wrong in 150 gives a 95% Clopper–Pearson upper bound of 1.98% (< 2%). Pairs: 0 in 81, upper bound 3.6% (< 5%).

Gaps, by cause (not WRONG):
- commenced_by where the amending law's text makes no claim: Schedules (KS); EU amenders; amending-reader misses (SI 2023/247, SI 2020/660, SI 2024/322 reg.15, SI 2022/8 reg.6 "in each place", NISR 2012/179 reg.33(1) "… are revoked");
- orders held but not read (SSI 2009/319, SI 2013/1869, SI 2016/603, SI 2020/1662, SI 2006/266);
- SOCPA s.178(1)'s qualifier read over the whole list;
- EU dates found only in Comments.

**V, the cause:** legacy markup operations compared with the law. These are Additions round the number of provisions repealed but still shown (HSWA s.84(5), s.1(1)(d); ukpga 1972/28 s.5(1)), and a legacy `M_F_` Substitution wrapping a later modern one (HSWA s.38).

**D, NEW:**
- EU consolidation markup wraps the number on a partial replacement: REACH Art 77(2)(e) first sentence; Art 14(4) introductory sentence.
- CLP's "mixtures" chapeau markup was joined to the feed's Point replacement (REACH Art 56(6)(b), 119(1)(a)), and the point's own markup was left as a second change (a merge fault).

**For Jason:** the two-link "as amended by" chains (REACH by SI 2019/1144, itself amended by SI 2020/1577) credit the middle link, as KX says.

## Fix batch 4 (2026-10-29, code e1aded30)

| Class | Fix | Where |
|---|---|---|
| Legacy operations (V) | a legacy markup operation fills a gap, never contradicts the law (no conflict) | `Conflicts.like?/5` |
| EU number wrap (D) | EU consolidation markup round the number is `level_covering` (below the feed) | `Markup.Level` |
| Chapeau join (D) | the merge joins the deepest markup first | `Merge` |

- **Catalogue:** markup, 17 readings.
- **Checks:** tests 9,519; restore point `cv-s08-fix4`; OH&S rebuild; golden from inputs 27/27.
- **Strata:** V 8, D 40, A 2,019.
- **A carries over:** the 150 round-4 A items' chosen values (operation, level, date, by, territory, partial, saved, commenced_by) were compared before and after the batch: 0 of 150 changed. A's round 4 pass (1.98%; pairs 3.6%) stands under the rule "items unchanged since checked".

## Round 5 (2026-10-29, seed 55): PASS

Three agents: V 8 in full; D 35 of 40 by pattern (2 batches). A carried over from round 4.

| Stratum | OK | WRONG | doubtful | Pairs |
|---|---|---|---|---|
| V (8, full) | 8 | 0 | 0 | 7 OK |
| D (35 of 40) | 32 | 2, both in logged open classes: KX-territory (SI 2008/1597 reg.3 heading), KF-type (REACH Art 138(1)) | 1 (SI 1992/2793 reg.2(2): "for X insert Y" in an unread Schedule) | 17/2/1 |
| A (150, round 4) | 150 | 0 | 0 | 81 OK |

**D patterns, the table's rule:**
- **by cited/affecting:** the feed holds (KX), 20 of 20.
- **operation inserted/substituted:** the feed holds (KA), 10 of 10.
- **level:** the markup holds where its change sits in the text.
- **operation substituted/inserted:** only the law's text settles it. With the text unread, one is the feed's own error (KF-type).
- **moved words:** KMV.

**Pass rule:**
- **V:** no wrong winner or false conflict. Met.
- **D:** no wrong pattern left unfixed or unclassed. Met: two classed items, both logged as open.
- **A:** the pooled 95% upper bounds are under 2% for changes and 5% for pairs. Met: 1.98% and 3.6%.
- **Golden from inputs:** 27/27. Met.

**Coverage found (not this step's pass):** three amending laws hold no amendment rules at all: SI 2015/1682, SI 1999/2024, SI 2015/1637. Their changes rest on the feed and markup alone. This is the amending reader's coverage (CV-S06/CV-07). The SI Schedules of laws that were read are read (SI 2019/758: 95 rules).

## Quality statement (OH&S, 2026-10-29)

Each attribute of a merged change comes from the evidence table:
- **operation:** the law's text, its commencement, then legislation.gov.uk's feed, then its markup;
- **level:** the markup only where it is sure, below the feed where its change merely covers the words;
- **date and commenced_by:** the law's commencement;
- **by:** the law's text, then the feed.

Disagreements between the law and legislation.gov.uk are reported like for like.

**Checked by agents against the sources' own records:**
- **Agreeing changes (A, 2,019):** 150 sampled, 0 wrong. 95% upper bound 1.98% wrong changes; 3.6% wrong (law, amending law) pairs.
- **Every reported disagreement (V, 8):** real, and the law's side right.
- **Markup–feed disagreements (D, 40), each pattern judged:** the rules hold, except two logged classes:
  - a feed Type error where the amending provision is unread;
  - a chain's territory cut to the later law's extent.

**Coverage, stated apart (gaps, not errors).** Of 4,573 OH&S text changes:
- 609 have no date from any source;
- 2,841 are dated with no commencing law named, because the amending law's text makes no claim (Schedules of laws not read, three amending laws with no rules, plain instructions missed) or the order is held but unread;
- 1,123 name the law that commenced them.

**Known limits:**
- moved words carried as "renumbered";
- Schedules of amended laws unparsed (v0.1);
- "has effect from" unread;
- legacy markup cannot tell a whole provision substituted from one inserted.
