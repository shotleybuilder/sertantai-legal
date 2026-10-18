---
session: 'CR-04: Reader — Commencement Orders'
status: closed
opened: '2026-10-18'
closed: '2026-10-18'
outcome: success
parent: commencement-rules/2026-10-18-cr-00-meta.md
summary: 'When an amending provision came into force is now read effects first: each amending Act''s legislation.gov.uk "coming into force" effects become rules (221 Acts, 32,335 rules) and date 774 of the 5,720 undated changes on our rows at 97.0% agreement with the feed. Orders read as text (Commencement.Order) reach 92.8% against note dates (QA only) — below the 95% bar, held back (CR-08).'
decisions:
  - what: Bar of 95% agreement before any order-derived date reaches the labels
    why: 'Jason 2026-10-18: "Agree, 95% bar and read all orders"'
    result: effects tier passes (97.0%); text tier held back
  - what: Effects first; law text only where effects are missing; every fetch one hop from our domain rows
    why: 'Jason 2026-10-18: "We''re not driving through the cascade…"; "if we have the effects data from leg.gov.uk why do we need to pull the laws too?"'
    result: all-orders fetch stopped at 56 of 1,131; one changes feed per amending Act instead
  - what: Note dates only as a QA yardstick for the text tier, never a source
    why: 'Jason 2026-10-18: "only if used as a qa and never a source of truth"'
    result: scratch QA script outside lib/; text tier 92.8%
  - what: Close with the effects tier; the text tier a pending session
    why: 'Jason 2026-10-18 "(a)"'
    result: CR-08
metrics:
  effects_tier: { vs_feed: '97.0% (12,046/12,415)', vs_notes_2002_on: '99.6% (741/744)', dates: 706, partial: 68 }
  text_tier: { vs_feed: '77% (924/1,199)', vs_notes_pre_2002: '92.8% (1,727/1,860)', would_date: 1476, would_partial: 535 }
  rules: { effects: 32335, order_text: 1061, amending_acts: 221, commencing_instruments: 712 }
lessons:
  - title: Ask whether an effect already holds the fact before reading or fetching text
    detail: 'Jason stopped a 1,131-order fetch: the amending Acts'' own feeds held the commencement effects. Effects first is now standing guidance (feedback_effects_first).'
    tag: data
  - title: A measured disagreement usually has one systematic cause
    detail: 'Each precision jump came from one bug: the feed listing a paragraph''s Schedule as a ref (86% → 96%), an Act''s year taken for its commencement''s (feeds for every Act), LR-33''s Royal Assent fallback read as an amending provision''s date (14% → 81%), a Schedule subset read as the whole (81% → 92.8%).'
    tag: data
bugs:
  - pattern: 'The amending-law collector dates changes from CommencingOrder (hop 2), which finds no date for most held orders'
    category: commencement
    module: AmendingLaw.CommencingOrder
    affected: 1463
    fix: Commencement.Amending (effects first) — consumed at CR-06
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/effects.ex
  - backend/lib/sertantai_legal/scraper/commencement/amending.ex
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/lib/sertantai_legal/scraper/commencement/orders.ex
depends_on:
  - commencement-rules/2026-10-18-cr-03-reader-own-clause
enables:
  - commencement-rules/2026-10-18-cr-06-switch-over
  - commencement-rules/2026-10-18-cr-08-text-tier
---

# Session: CR-04: Reader — Commencement Orders (CLOSED)

## Problem

A commencement order becomes rules about the law it commences. Today `CommencingOrder` reads orders only for hop 2 and finds no date for 1,463 amending-law records whose orders are held (LR-44).

## Todo

- ✅ Trace a sample of the 1,463 (30, `order_trace.exs`): below
- ✅ Reader: `Commencement.Order` (text tier) and `Commencement.Effects` (effects tier, first); `Commencement.Amending` decides
- ✅ Which: effects from each amending Act's feed; text from the orders notes cite (the all-orders route `Commencement.Orders` built, not used — Jason: scope from our rows)
- ✅ Gate vs the feed: effects 97.0%; text 77% (92.8% vs note dates, QA only) → text held back (CR-08)

## Dependencies

- ⬜ CR-01, CR-02; LR-42 (orders held)

## Trace (2026-10-18): why the held orders give no date

`CommencingOrder` reads two shapes only — a Schedule table dated by its title, an article whose child items are its list — and matches a provision only as "section N …" / "Schedule N, paragraph …" at an item's start. The orders traced use:

| Form | Example |
|---|---|
| inline sentence, range | SI 1994/571 art. 6: "Sections 17 to 22 of, and Schedule 4 to, the Act shall come into force on 2nd April 1994." |
| Schedule paragraphs via the introducing section | SI 1995/1983: "section 116 in so far as it relates to paragraphs 2(1) to (3) of Schedule 21"; SI 1996/186: "section 120(1) in so far as it relates to the following paragraphs of Schedule 22— 1, 3, 5 to 12, …"; SI 2004/2173: "section 46(3) (which introduces Schedule 4) in so far as it relates to the provisions in Schedule 4 referred to in sub-paragraph (i)" — the "so far as" qualifies the section; the paragraphs come in fully |
| Schedule paragraph lists | SI 2006/2541: "the following paragraphs of Schedule 11— paragraphs 1 to 33; paragraph 34, so far as it has not already been commenced; …" |
| qualified items | SI 2009/400: "section 196 and paragraphs 1, 3 to 6, and 10 to 14 of Schedule 10 so far as they relate to— (i) any appeal under …" |
| appointed-day sentences | SI 1996/323 art. 4: "1st April 1996 is the day appointed for the coming into force of …" |
| the Act not identified | 1997/53, 1998/23: no `uk_lrt` title, so "does this order commence the Act?" fails — take the title from the amending law's own CLML |

## Plan

1. **`Commencement.Order`** (reader): an order's commencement statements → rules for the law it commences. Statements: "<items> come(s) into force on <date>" (inline, or its child items / a Schedule table), "<date> is the day appointed for the coming into force of <items>", Schedule tables (as now). Items: sections (ranges, subsections), Schedules, Parts of Schedules, "paragraphs … of Schedule N", "section N (which introduces Schedule M) in so far as it relates to <paragraphs of Schedule M>" (→ the paragraphs fully, the section partly); qualifiers → purposes / territory; "for all (remaining) purposes", "so far as not already in force" → full.
2. **Refs**: an amending law's grammar — "s.17..s.22", "s.36(3)", "sch.4", "sch.10.para.3..sch.10.para.6", "sch.21.para.2(1)"; the evaluator's ranges extended to paragraph refs; an amending provision id ("schedule-11-paragraph-137-a") → "sch.11.para.137(a)".
3. **The Act**: the order commences the law it names ("the Act" defined, else a title found in its text), the amending law's title from its own CLML when `uk_lrt` has none.
4. **Measure**: of the 1,463 records, how many the rules date (evaluator over the rules from their notes' orders); benchmark agreement with the feed where it dates them (date differs 854 → down).

## Built so far (2026-10-18)

`Commencement.Order` (`rules/2`, `ref/1`, `context/0`, `title/1`), 12 tests; evaluator ranges extended to paragraph refs and bracket ranges. Forms read: inline statements (and a list after the dash), statements with listed items (first line = statement, lines below = items), appointed-day sentences, "the day after this Order is made" (the order's made date), Schedule tables; items with sections / Schedules / "paragraphs … of Schedule N" / "in Schedule N, paragraphs …" / bare numbers under "the following paragraphs of Schedule N—"; "section N in so far as it relates to <paragraphs>" → the paragraphs fully; "as follows—" headings commence nothing; another law's provisions ("… into the 1991 Act") dropped; territory from the item, its statement or the instrument (a WSI: Wales); partial qualifiers include "for specified purposes".

## Coverage: the 2,552 undated amending-law records (`order_measure.exs`)

| | Before (`CommencingOrder`) | Now |
|---|---|---|
| dated | 0 | 463 |
| partly dated | 0 | 220 |
| rules read, none reaches the provision | — | 513 |
| no rules read from the named orders | — | 350 |
| no order named in the note | 1,006 | 1,006 |

## Precision: the feed's dates for the same kind of record (`order_precision.exs`, 16,171 benchmark records by Acts)

| Verdict | Records |
|---|---|
| full date agrees | 5,143 |
| a partial date agrees | 536 |
| partial only, before the feed's (full) date — consistent | 769 |
| **differs** | **1,851** |
| undated / no order | 7,872 |

78% agree or are consistent where both date. The differences are mostly staged commencements read as full: an order's partial stage ("so far as it relates to ss. 120D–120H", "for the substitution of s. 66EB(1)–(7)") without a qualifier the reader recognises, and the later "so far as not already in force" order not among those the note names (Water Act 2014 690, Building Safety Act 2022 428, Energy Act 2013? 2005/16 270, 2011/20 234, 2023/13 220).

## Decided (Jason 2026-10-18: "Agree, 95% bar and read all orders")

- **Bar**: order-rule dates reach the labels (CR-06) only at ≥ 95% agreement with the feed where both date (agree + consistent partial).
- **Read every commencement order made under an Act**, not only those the notes cite (the final "so far as not already in force" order is often uncited); missing orders fetched into the store (as LR-42). The same list serves CR-07.

## Every commencement order of an Act (`Commencement.Orders`)

legislation.gov.uk's title search ("<Act title> <year> (Commencement", every page) ∪ the register's `uk_lrt.enacting` titled commencement / appointed day; cached per Act (`data/cache/commencement-orders/`). Water Act 2014: 17 orders (the notes cite a few; the register lists 16). `mix lat.commencement --orders`: 221 amending Acts, 1,468 commencement orders, 1,131 not held → fetched (`mix clml.fetch`); `--read-orders` writes their rules by order.

## Re-scoped (Jason 2026-10-18: "Are we focussed on grabbing the laws we need …"; "if we have the 'effects' data from leg.gov.uk why do we need to pull the laws too?"; "Agree the re-scope")

The all-orders fetch was stopped at 56 of 1,131 (an Act's whole commencement history is far wider than the provisions that changed our rows: Scotland Act 2016 alone 98 orders). **Effects first; law text only where effects are missing; every fetch scoped from our domain laws' rows, one hop.**

1. **2002 on (68 amending Acts, 481 undated records)**: the amending Act's own changes feed (all pages) — its "coming into force" effects (provision, commencing order and article, date, territory / purpose) — as rules. No laws or orders fetched.
2. **Before 2002 (136 Acts, 1,870 records)**: legislation.gov.uk's changes data is thin there; read the amending law and the orders the notes cite (held since LR-42). No further fetching.
3. Measure against the 95% bar.

## Effects first: built and measured (2026-10-18)

- `Commencement.Effects`: an Act's "coming into force" effects → rules (scope from the structured refs; a Schedule listed with its paragraph is only its place; one rule per in-force entry; qualification → territory / the four purposes); `for_row/2`: a qualification naming inserted sections ("for the insertion of s. 120A for E. and the insertion of s. 120B for specified purposes") reaches only those rows.
- `Commencement.Amending.evaluate/4`: effects first; the text rules (the Act's own clause, the orders its notes cite) only where no effect reaches the provision.
- `Store.write/3` `treatments:` — two readers of one document keep each other's rules.
- `mix lat.commencement --effects`: every amending Act's feed (221 Acts, one feed each, 712 commencing instruments, 32,335 rules) — the feed records commencements from 2002, of older Acts too (CROW 2000 in 2004–05). The all-orders fetch (`--orders`) is not used.

Bugs caught by the measure: the feed's refs list a paragraph's Schedule too, so every Sch. 5 paragraph's commencement reached para. 77 (BSA 2022) — precision 86% → 96%; an Act's year is not its commencement's (CROW 2000) — feeds fetched for every amending Act.

### Gate (`cr04_measure.exs`): precision vs the feed where it dates, by tier

| Tier | Agree | Consistent (partial before the feed's date) | Differs | Rate |
|---|---|---|---|---|
| **effects** | 11,015 | 1,123 | 491 | **96.1%** ✅ |
| text (own clause + orders read) | 946 | 158 | 593 | **65%** ❌ |

### Coverage: undated amending-law changes on our rows (5,720)

| Tier | Dated | Partial | Undated / no rules |
|---|---|---|---|
| effects | 737 | 126 | — |
| text | 2,843 | 86 | 1,928 |

The text tier dates most pre-2002 rows (2,771) but at 65% where checkable — below the bar; its pre-2002 precision can't be checked against the feed (6 records).

## Decided (Jason 2026-10-18: "1. accept recommendation; 2. only if used as a qa and never a source of truth (b)")

1. **Only effects-tier dates reach the labels (CR-06)**; text-tier dates are held back (below the bar). Pre-2002 changes no effect dates stay undated — a known limit for now.
2. **Text tier QA against note dates — measure only, never a source**: a scratch QA script (not in `lib/`, so the note-read architecture test stays true) compares text-tier dates with the dates a change's note states; if ≥ 95%, the text tier may follow (Jason decides). Notes never label anything.

## Final measure (2026-10-18)

Fixes from the note-date QA: an Act's Royal Assent fallback (LR-33's law start when its clause leaves the rest to orders) is never evidence for an amending provision (text tier 14% → 81%); a whole Schedule whose entries came in on different dates gets no date (repeals tables); "the following provisions of Schedule 22—" / "the provisions in Schedules 13 and 14 … specified in …" are a subset, never the whole Schedule, and set the paragraph context.

| Tier | vs the feed (where it dates) | vs note dates (QA only, never a source) |
|---|---|---|
| **effects** | **97.0%** (12,046 / 12,415) | 2002+: 99.6% (741 / 744); pre-2002: 9 / 29 |
| text (own clause + cited orders) | 77% (924 / 1,199) | pre-2002: **92.8%** (1,727 / 1,860) |

Coverage of the 5,720 undated amending-law changes on our rows: effects tier dates 706 and partly 68 (passes the bar → CR-06); text tier would date 1,476 and partly 535 (held back: below the bar).
