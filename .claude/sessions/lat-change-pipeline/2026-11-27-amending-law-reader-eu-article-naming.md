---
session: 'Amending-law reader: EU article naming'
status: closed
opened: '2026-11-27'
closed: '2026-11-27'
outcome: success
family: 'Waste, Water and Climate (round)'
parent: lat-change-pipeline/2026-11-26-waste-water-and-climate-amending-law-reader.md
summary: >
  EU laws now get changes from their amending SIs' own text: six reader faults fixed (row spelling,
  quoted Articles, EU titles naming other laws by citation or defined term, a paragraph with its point,
  words falling to a held Article). Fresh EU rules with no held target fell from 581 plus 345 two-law
  provisions to 61 of 3,860, all named; nothing outside EU law changed. Written at the parent's Settle.
decisions:
  - what: Fix the paragraph-with-point class (481 rules) in this session though the plan named three classes
    why: it was the largest no-target group at the baseline and pass item 1 fixes any group over the triage size
    result: 1,628 pairs found their paragraph; 381 provisions gained a held target
  - what: A words change with no held target falls to its nearest held EU Article, in the vocabulary, EU only
    why: the paragraph fix turned held art.Article N into unheld art.Article N(1) where the rows hold no paragraphs (Regulation 2019/631); UK law and whole changes left as they were
    result: 74 lost provisions kept; 126 rules kept at the Article
  - what: Blank an EU title in naming text for every kind of name, not only EU citations
    why: SI 2019/758 Sch.6 named REACH through the defined term "(REACH)" inside the fees Regulation's title
    result: exactly 25 rules gone, nothing else in both previews
metrics:
  baseline: { eu_rules: 4454, eu_laws: 54, amenders: 65, targets_held_as_spelt: 41, no_target_held: 581, two_law_provisions: 345 }
  after: { fresh_eu_rules: 3860, target_held: 3673, kept_at_article: 126, no_target_held: 61, parser_owned: 27, known_limit: 34 }
  yield_eu_share: { feed_markup_changes: 7286, met_stored_respelt: 1959, met_now: 3401 }
  tests: { full_suite: 12926, failures: 0 }
lessons:
  - title: Count held targets with the vocabulary's own names, not the rows' section ids
    detail: Readers.AmendingLaw keeps a target only if Ref.from_clml of a row's CLML id spells it (article-36-3n1 is art.Article 36(3n1); a territorial version's id has no extent bracket), and only among the rule's own targets. An exact row-spelling count overstated misses; the vocabulary count also showed a finer reading can lose a held coarse target.
    tag: data
  - title: A diff pairs two rules of one provision crosswise
    detail: Operation and treatment "flips" in --diff were a provision's two rules (substituted + inserted) matched the other way round. Compare whole rule sets per provision before reading a flip as a change.
    tag: tooling
  - title: An EU law's full title is a list of other laws
    detail: 'Its words "amending", "repealing", "pursuant to … of", "under" and a defined term in brackets name other laws; any name-finder over an EU naming sentence must skip the title, not only the citation scanner.'
    tag: data
bugs:
  - pattern: 'EU law gets no change from its amending SIs'' own text: rules name art.N, rows art.Article N, so all drop as misreads; and a quoted Article''s numbered paragraphs are read as Articles (For Article 22 substitute— … 1. 2. → art.1, art.2)'
    category: eu-article-naming
    module: amendment/reader/eu_spelling.ex, amending_law/text.ex
    affected: 4454 rules on 54 EU laws
    fix: "targets spelt art.Article N at Reader.read/4's exit; a quote's <Number>Article N</Number> is its number"
    step: Amending-law reader
    status: fixed
  - pattern: "One provision read for two or more EU laws: an EU law's title names other laws, taken as laws amended (e.g. SI 2019/720 Sch.2 CLP paragraphs also on REACH; SI 2019/758 Sch.6 by the defined term (REACH))"
    category: eu-title-citations
    module: amendment/reader/eu_citation.ex, amendment/reader/law_named.ex
    affected: 345 provisions, 849 rules, 9 SIs
    fix: "EuCitation.untitled/1 blanks an EU title in a naming text; LawNamed reads every kind of name from it"
    step: Amending-law reader
    status: fixed
  - pattern: "An EU paragraph with its point ('In paragraph 5(a)—') read as the point alone, Article 10(a) (SI 2019/453 reg.63(4))"
    category: eu-paragraph-point
    module: amendment/reader/brackets.ex, amendment/reader/law_named.ex
    affected: 481 rules
    fix: "eu_paragraphs takes a number followed by a bracket; parents' words pass through it"
    step: Amending-law reader
    status: fixed
  - pattern: "Words in an EU Article's paragraph the rows don't hold were dropped (Regulation 2019/631 rows hold no paragraphs: SI 2020/1418 reg.3(8)(a)(i))"
    category: eu-words-to-article
    module: change_vocabulary/readers/amending_law.ex
    affected: 74 provisions (126 rules kept at the Article)
    fix: "a words rule with no held target falls to its nearest held Article (EU targets only)"
    step: Amending-law reader
    status: fixed
  - pattern: "EU Articles held without their paragraph rows, so a whole paragraph's change has no row (Regulation 2019/631 Arts 4, 6-8, 10, 15; 1272/2008 Art 42; 2009/392 Art 10; 2005/111 Art 33; 2018/2067 Art 72; 2014/427 Art 1)"
    category: eu-paragraphs-not-parsed
    module: lat_parser (EU Articles whose paragraphs carry no ids)
    affected: 27 rules, 6 EU laws
    fix: "give an EU Article's numbered paragraphs rows where the CLML holds them without ids, as for UK lists (#184)"
    step: LAT parser
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader/eu_spelling.ex
  - backend/test/sertantai_legal/scraper/amendment/reader/eu_article_naming_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/amending_law_eu_article_test.exs
  - backend/data/reports/amending-reader/eu-naming/
depends_on:
  - 2026-11-26-waste-water-and-climate-amending-law-reader.md
enables:
  - the parent's amending Schedules and yield sessions, then its Settle write
---

# Session: Amending-law reader: EU article naming (CLOSED)

## Problem

An EU law's amending SIs give it no change. The reader names targets `art.2` while the rows are `art.Article 2`, so the change vocabulary drops every one: 4,454 rules on 54 EU laws. A quoted inserted Article's paragraphs also read as Articles 1, 2 … (55 rules). And about 790 rules from 8 SIs land on two or more EU laws at once, as with SI 2019/720's CLP paragraphs on REACH.

This is a named session inside the step "Waste, Water and Climate: Amending-law reader", whose parent is suspended until its three named sessions are done. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md` (approved 2026-11-27).

## Todo

- ✅ 1. Measure: baselines (three classes by law; the EU amenders' provisions with no rule; feed comparison by spelling) → `eu-naming/baseline.txt`
- ✅ 2. Find: each class's cause by probing two laws each (class 3: SI 2019/720 Sch.2 Part 2, SI 2019/453, SI 2019/583)
- ✅ 3. Fix: class 1, EU targets spelt `art.Article N…` at `Reader.read/4`'s exit, test first
- ✅ 4. Fix: class 2, a quoted Article gives Article N and its paragraphs, test first
- ✅ 5. Fix: class 3, one provision read for several EU laws, by the cause found, test first
- ✅ 6. Check: previews of the 65 EU amenders and the regression list, every pair read; held-target count; yield's EU share; `mix test`, Credo diff
- ✅ 7. Close: frontmatter bugs, RULES, commits by path, resume the parent (amending Schedules next, on Jason's go); no push

## Dependencies

- ✅ Waste, Water and Climate: Amending-law reader, Fix phase done (to `f49d651b`), catalogue accepted (`3b74c86d`); suspended 2026-11-27

## Measure (todo 1)

Report: `backend/data/reports/amending-reader/eu-naming/baseline.txt`.

- 4,454 stored rules from 65 amending laws on 54 EU laws (122 EU laws hold rows). Targets 7,377: held as spelt 41; held once respelt 5,094.
- Rules with no target held even respelt, class 3 aside: 581. Of these, 481 are an Article held with a point not (`art.10(a)` for Article 10(5)(a)): a fourth class, below.
- Class 2 (quoted Article): 157 rules from 35 amending laws. Class 3 (several EU laws): 345 provisions, 824 rules from 8 SIs (SI 2019/720 110, SI 2019/453 103, SI 2019/270 49, SI 2019/583 30, SI 2019/758 25, SI 2022/1260 14, SI 2021/135 11, SI 2019/590 3).
- Feed and markup changes on EU laws by a named law: 7,286; 2,441 where the amender has no rule for the law (top: SI 2020/1567 248, eur 2008/1272 137). The yield's EU share.

## Find (todo 2)

- **Class 1, spelling:** the reader's `@prefix` gives `art`, so targets are `art.N`; rows are `art.Article N`.
- **Class 2, a quoted Article:** the quote is `<Part><Number>Article 53A</Number>…`; `AmendingLaw.Text.number/1` read only `Pnumber`, so its paragraphs became Articles 1, 2 (SI 2019/720 Sch.2 para.53).
- **Class 3, several EU laws:** confirmed in all 8 SIs. `EuCitation.scan` took every citation in the naming sentence, those in the first law's own title too: CLP's "… and amending Regulation (EC) No 1907/2006"; 165/2014's "repealing Council Regulation (EEC) No 3821/85 … and amending Regulation (EC) No 561/2006"; 788/2014's "pursuant to Articles 6 and 7 of Regulation (EC) 391/2009"; 537/2011's "under Regulation (EC) No 1005/2009"; 1418/2007's "Annex III or IIIA to Regulation (EC) No 1013/2006". Not a heading cause: SI 2019/720 Sch.2's groups are titled by the law, but `Doc.headings` gave only the Schedule's.
- **Class 4 (new), an EU paragraph with its point:** "In paragraph 5(a)—" (SI 2019/453 reg.63(4)) gave Article 10(a): `Brackets.eu_paragraphs` refused a number followed by a bracket, and a parent's words never passed through it. 481 rules; over the triage size, fixed here (pass rule item 1).

## Fixes (todos 3–5)

Tests: `reader/eu_article_naming_test.exs` (6, red first), `brackets_test.exs` (+1).

- Class 1: `Reader.EuSpelling.rows_spelling/2` at `Reader.read/4`'s exit (new module, in both stamps).
- Class 2: `Text.number/1` reads a quote's `<Number>Article N</Number>`.
- Class 3: `EuCitation.scan` drops a citation reached from the one before through its title (a title opener in the gap, no "is amended", `;`, `—` or sentence end).
- Class 4: `eu_paragraphs` takes "paragraph 5(a)", and `LawNamed.placed_by` passes parents' words through it.
- `mix test` over the reader, amending-law and architecture tests: 2,681 pass; `AmendmentPatternsTest` did not drift.

## Check (todo 6)

Reports in `backend/data/reports/amending-reader/eu-naming/`: `fix-1-*` (classes 1–4), `fix-2-*` (the title blanking widened to every name), `held-targets.txt`, `yield-eu-share.txt`.

- **A fifth cause found in the field diff, fixed:** SI 2019/758 Sch.6 on the fees Regulation was read for REACH too, by the defined term "(REACH)" inside the fees Regulation's own title. `EuCitation.untitled/1` now blanks an EU title in a naming text (byte offsets kept) and `LawNamed` reads every kind of name from it. Test red without it. `fix-2` against `fix-1`: exactly those 25 rules gone, nothing else, in both previews.
- **A sixth, from the held count, fixed:** class 4 had turned `art.Article 10` (held) into `art.Article 10(1)` where the EU law's rows hold no paragraphs (Regulation 2019/631): 74 provisions lost a held target. The vocabulary's amending-law reader now puts a words change with no held target in its nearest held Article (EU targets only, never a whole change, never UK law; `amending_law_eu_article_test.exs`, 4 cases).
- **Every pair read by code:** 2,073 respelt only; 1,628 a paragraph found (class 4); 31 a quoted Article (class 2); class 3 in all 8 SIs keeps the title's own law (table below); the operation and treatment flips are two rules of one provision paired crosswise (sets equal); "Omit Part 3" and "in Part 6" now `pt.N` (out of scope, an Annex's).
- **Outside EU law nothing changed:** regression preview's non-EU pairs against the parent's last (`wwc/fix-m-regression-diff.json`): 6 new, all 1994 c.28, the parent's own last fix (f49d651b); the EU preview's 56 non-EU pairs are all in the parent's previews.
- **Pass item 1 (held targets), counted with the vocabulary's own names (`Ref.from_clml` of the rows' ids):** 3,860 fresh EU rules; 3,673 hold a target, 126 more kept at their Article; 61 (1.6%) hold none, against 581 plus class 3 at the baseline. Named: 27 are whole changes to paragraphs the EU law's rows don't hold (LAT parser, parked `eu-paragraphs-not-parsed`); 34 are one-provision readings below the triage size (a disambiguated `(3n1)` row, a definitions Article numbered (1)(N) by the parse, a quote's nesting), a known limit in RULES.
- **Pass item 6 (the yield's EU share):** of 7,286 feed and markup changes on EU laws by a named law, a kept rule meets the target in 1,959 with the stored rules respelt (about none as stored, unspelt), 3,401 now.
- `mix test` over the vocabulary, reader, amending-law and architecture tests: 6,867 pass; `AmendmentPatternsTest` did not drift. Credo diff: no issues added.

| SI | Two laws before | Kept |
|---|---|---|
| SI 2019/720 | REACH, CLP | CLP (110) |
| SI 2019/453, 2021/135, 2022/1260 | drivers' hours 561/2006, tachograph 165/2014 | 165/2014 (128) |
| SI 2019/270 | 391/2009, 788/2014 | 788/2014 (49) |
| SI 2019/583 | 517/2014 with 2015/2066-8, 2016/879; 1005/2009 with 537/2011 | the implementing Regulation (28) |
| SI 2019/590 | 1013/2006, 1418/2007 | 1418/2007 (3) |
| SI 2019/758 | REACH, fees 340/2008 | fees (25) |

## Parking list

- LAT parser: `eu-paragraphs-not-parsed` — EU Articles held without their paragraph rows (27 rules, 6 EU laws).

## Close (todo 7)

- Code commit `764fd74e` (hooks passed); full suite 12,926 pass.
- Docs changed: `RULES.md` (EU forms under `amending-places-read-as-the-amended-law-numbers-them`; the EU known limit marked fixed; two new limits); the reader's `CLAUDE.md` gotcha on held counts.
- Parking list: `eu-paragraphs-not-parsed` is a bug entry, step LAT parser.
- No database write: the parent's Settle writes the round once.
