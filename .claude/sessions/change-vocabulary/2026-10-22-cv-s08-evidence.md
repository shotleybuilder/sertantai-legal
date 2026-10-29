---
session: 'CV-S08: Evidence'
status: active
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
bugs:
  - pattern: "Operation order: markup Addition (inserted) outranks the feed's substituted; the feed is right 12/12 (every amending text says substitute)"
    category: evidence table
    module: ChangeVocabulary.Evidence
    affected: 14
    fix: "Feed above markup for operation (an Addition alone is how legislation.gov.uk marks a substitution's new words); markup Substitution vs feed inserted splits 2/2 — only the law's text settles it"
    status: open
  - pattern: "Level conflicts compared unlike for unlike: the feed's level for a parent or sibling at a child target; repealed_in_part vs repealed words"
    category: evidence table
    module: ChangeVocabulary.Conflicts
    affected: 12
    fix: "Compare a feed level only where its affected provision is the change's target; repealed_in_part = repealed at words"
    status: open
  - pattern: "Date conflicts compared unlike for unlike: the feed's first stage 'for specified purposes' (enabling powers) against the full commencement date; partial=true beside the completing date"
    category: evidence table
    module: ChangeVocabulary.Conflicts / Evidence
    affected: 7
    fix: "Compare first with first, full with full; partial judged at the chosen date"
    status: open
  - pattern: "Merge.precise/1 gives a note-ref-only placement a markup level :words — a level from a note (commencement stages, whole provisions repealed as dots, Pt modified)"
    category: pointer as fact
    module: ChangeVocabulary.Merge
    affected: 672
    fix: "A note-only placement claims no level; level falls to the feed"
    status: open
  - pattern: "commenced_by never emitted on an amendment change dated by commencement (the rule's source law dropped)"
    category: commencement reader
    module: Readers.AmendingLaw / Readers.Feed
    affected: 3688
    fix: "Emit {:commencement, :commenced_by, rule.source.law} with the date when it differs from by"
    status: open
  - pattern: "act_enactment 'all' rule (Royal Assent) outranks specific or by-order rules (ERA 2025 sch.12, PJA 2006 sch.15, Courts Act 2004 sch.1, Children (Scotland) Act 1995)"
    category: commencement reader
    module: Commencement
    affected: 11
    fix: "No act_enactment default for an Act whose commencement section defers to orders; a refs rule always beats all; no date → no claim (feed wins)"
    status: open
  - pattern: "Commencement exception list drops a last item naming another regulation ('and 4(b)'); a schedule not traced through its introducing regulation; 'This section has effect from' unread; SOCPA s.178 bare numbers dropped"
    category: commencement reader
    module: Commencement.OwnClause
    affected: 3
    fix: "New base number per list item; schedule → introducing provision's rule; read 'has effect from'"
    status: open
  - pattern: "Markup level: Substitution of a provision's whole text with its number outside read as provision; ';' remainder; Part <Number> wrapped still words; EU ListItem NumberOverride / id-less list own text; Correction wrapper"
    category: markup reader
    module: Readers.Markup
    affected: 15
    fix: "Provision only when the element wraps the number (Pnumber, Number, NumberOverride) or the whole element; look through Correction wrappers"
    status: open
  - pattern: "Feed reader: savings in a SectionRange dropped (store-wide 3,510 range-only); Type 'amended' gives level provision; '… heading', '… Text', 'Indent N' read as provision; '(EW)' in Type not read as extent"
    category: feed reader
    module: LegislationGovUk.ChangesFeed / Readers.Feed
    affected: 3510
    fix: "Savings .//Section/@Ref and range ends; 'amended' no level; suffixes → words; parenthesised extent → effect extent"
    status: open
  - pattern: "Amending reader: 'for X insert Y' read as inserted (is substituted); 'as it applies to Scotland / E+W' not read as territory"
    category: amending reader
    module: Amendment.Reader
    affected: 3
    fix: "for <quoted> insert = substituted; 'as it applies to X' a law_text territory claim"
    status: open
  - pattern: "Merge: an alias joins two events (SI 1995/2038 reg.6(8)); an EU ';' Substitution joined to an addition effect (CLP Art 23(f)); a substitution split Repeal+Addition left as a duplicate (SI 1998/494 reg.4(3)(e)n1); KX territory cut to the later law's extent"
    category: merge
    module: ChangeVocabulary.Merge
    affected: 4
    fix: "Per case; KX: cut to the chained amending provision's extent"
    status: open
---

# Session: CV-S08: Evidence (ACTIVE)

## Problem

Step 8 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each attribute from the right source by the agreed evidence table; disagreements reported like for like.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (Jason 2026-10-29: "Agree, build it"): strata V, D and A; pass rule below
- ✅ Build the acceptance check (`mix lat.evidence_check`, `evidence-check` skill; code 00d9b63d)
- ✅ Round 1 (seed 51): FAIL — V 27/63 OK, D 42/102, A 47/50; faults classed below
- ⬜ Fix plan agreed with Jason (evidence table here; reader faults: where)
- ⬜ The table re-reviewed with Jason after the source-use balance (CV-07)
- ⬜ Value conflicts checked on a sample: level vs markup/feed, operation, date (OH&S family: 63)
- ⬜ A Gemini review of the evaluator (CV-04)
- ⬜ Fix until the check passes reliably; record the result

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
