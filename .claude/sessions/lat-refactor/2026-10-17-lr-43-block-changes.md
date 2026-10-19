---
session: 'LR-43: Block Changes'
status: closed
opened: '2026-10-17'
closed: '2026-10-19'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: >
  A block instruction now reaches the rows inside it — a quote numbering the row's provision when the instruction names none ("For Part 13, Sub-Part C substitute—"), a quote numbered from the subsection it substitutes. The pilot found two more causes: clause sentences split after "etc." in a title, and "so far as it is not yet in force" not read as full. Applied: undated_change 15,467 → 15,189, unknown today 16,610 → 16,359.
decisions:
  - what: Finish LR-43 as a text fix; scope the amendment ruleset as a pending meta
    why: 'Jason 2026-10-19 "(a), and scope the amendment ruleset as a pending meta": the fix was small and measurable now; the ruleset is a bigger refactor with the QQ deadline'
    result: amendment-rules/2026-10-19-ar-00-meta (pending)
  - what: Pilot on the six laws with most undated changes, one corpus run at the end
    why: 'Jason 2026-10-19: no repeated corpus runs'
    result: the pilot exposed the two non-block causes (SI 2019/696 undated without the sentence fix)
metrics:
  labels: { undated_change: '15,467 → 15,189', unknown_today: '16,610 → 16,359', insertion_not_in_register: '8,817 → 8,567', fields_changed: 1614, errors: 0 }
  examples: { nisi_2003_419: '235 rows 2009-02-01 (arts. 52-55F substituted)', uksi_2014_1638: 'undated_change 78 → 1' }
lessons:
  - title: Reaching a row is not dating it
    detail: 'The block fix reached all 77 SI 2014/1638 rows but they stayed undated: SI 2019/696''s commencement sentence was cut at "etc." in its own title. Trace a fixed case to its label before measuring.'
    tag: data
  - title: The text matcher grows a case per form; the commencement ruleset showed the alternative
    detail: 'Jason asked whether LR-43 used the common schema: it did for dating, not for reach (the ruleset was scoped to bringing into force). Each block form is another special case in Target — the reason for the amendment-ruleset meta.'
    tag: data
bugs:
  - pattern: 'A block instruction naming no provision number ("For Part 13, Sub-Part C substitute—") or quoting paths from the substituted subsection never reached the rows inside it'
    category: amending-law
    module: AmendingLaw.Target
    affected: 'undated_change −278 (corpus)'
    fix: 'the quote''s numbering names the row; paths relative to the named bracket'
    status: fixed
  - pattern: 'Clause sentences split after an abbreviation in a title ("Metrology etc. (Amendment etc.) (EU Exit) Regulations 2019 and come into force on exit day")'
    category: commencement
    module: LawStart.Clause
    affected: 6 laws
    fix: 'Clause.sentences/1 with abbreviation lookbehinds, shared by Provisions and OwnClause'
    status: fixed
  - pattern: 'A block substituted from the amending law''s own Schedule ("Part I of Schedule 4 shall be substituted for Part VIII": EReA 1999 on ERA 1996) not reached'
    category: amending-law
    module: AmendingLaw.Target
    affected: unknown
    fix: 'amendment ruleset (AR meta): a block target from the amending law''s Schedule'
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/target.ex
  - backend/lib/sertantai_legal/scraper/law_start/clause.ex
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/data/reports/lat-refactor/lr43_dry.diff.csv
depends_on:
  - lat-refactor/2026-10-17-lr-41-instruction-law
enables:
  - amendment-rules/2026-10-19-ar-00-meta
---

# Session: LR-43 Block Changes (CLOSED)

## Problem

An instruction inserting or substituting a block — a Part or Sub-Part, a run of sections, a subsection with its paragraphs — never reaches the provisions inside it, so their change stays undated (LR-41 sample: 61 of 159 target failures: no provision number named 37, another number 14, the row inside a named provision 10). SI 2014/1638 reg.76(1)(a): SI 2019/696 "For Part 13, Sub-Part C substitute—" quotes regs 69–76; NRSWA 1991 s.148(3)(a): "for subsection (3) substitute". After LR-41 (Jason 2026-10-17: "Law first, block next").

## Todo

- ✅ D1: a block instruction reaches the rows inside it (the quote's paths; named brackets a prefix of the row's)
- ✅ Build, tests, dry run, Jason ("okay"), restore point `2026-10-19-lr43-relabel`, applied

## Dependencies

- ✅ LR-41 (the law check runs first; closed)

## D1 (2026-10-19): what stopped a block instruction

The quote already lists every level it inserts ([69], [69, 1], [69, 1, a]), so rows inside a quoted provision match when its path is quoted. Two gaps:

1. **No provision number named.** "For Part 13, Sub-Part C substitute—" (SI 2019/696 on SI 2014/1638) names no regulation, and the number stage failed before the quote was consulted. Now: a quote numbering the row's provision names it.
2. **Paths numbered from the substituted subsection.** "In section 148 … for subsection (3) substitute— (3) … (a) …" quotes [3], [3, a]: the row s.148(3)(a) matches when the quote's top is the bracket the instruction names.

Words-level changes don't spread to a block ("for “x” substitute “y”" in s.148(3) never reaches s.148(3)(a)). Tests red → green.

## Applied (2026-10-19, Jason: "okay")

Whole-corpus dry run `lr43_dry`: 1,614 fields, 0 errors (Energy (NI) Order 2003 arts. 52–55F 235 rows 2009-02-01, note agrees; SI 2014/1638 Pt. 13 Sub-Pt. C 2020-12-31; TCPA s.171A ff. 1992). Restore point; `mix lat.relabel --stale`: 0 failed, **0 stale**; today in force +216, partly +35.
