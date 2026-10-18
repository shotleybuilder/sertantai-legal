---
session: "CR-03: Reader — a Law's Own Commencement Clause"
status: closed
opened: '2026-10-18'
closed: '2026-10-18'
outcome: success
parent: commencement-rules/2026-10-18-cr-00-meta.md
summary: 'A law''s own commencement clause is now a set of rules (Commencement.OwnClause over LawStart and Provisions.groups/3): 1,241 rules for 994 laws; the evaluator matches today''s register on 99.6% of rows, every difference classified. Reading fixes applied by relabel 2026-10-18 (59 rows; unknown today 17,079).'
decisions:
  - what: Reuse LawStart / Provisions reading; the reader writes what they read as rules
    why: the parsing (made-relative counting, named days, lists, except, Parts) is tested and decided (LR-33/34); rewriting it would re-open it
    result: 'Provisions.groups/3: refs unexpanded ("pt.II", "pt.6.ch.1")'
  - what: A qualified sentence is a partial rule, completing the general one
    why: 'Jason 2026-10-18 "Accept the decisions" (replaces LR-34 D2); Quarries reg.26: in force for classified tips 2006, fully 2007'
    result: 905 rows partial first in the comparison; labels change at CR-06
  - what: A staged clause keeps LR-33 P1's earliest-date law rule for now
    why: 'dropping it made 4,666 rows in 35 laws unknown, largely reader gaps (Jason 2026-10-18)'
    result: revisit when the reader covers the missed sentences
  - what: Apply the reading fixes' 59 label changes
    why: Jason 2026-10-18
    result: 82 of 82 fields live, 0 stale
metrics:
  rules: { written: 1241, laws: 994 }
  comparison_cr03_cmp4: { same: 373430, partial_first_qualified: 905, by_order_to_dated: 218, dated_to_unknown: 173, partial_only: 70, later: 28, earlier: 19, unknown_to_dated: 23 }
  relabel_2026_10_18: { label_changes: 59, fields_live: 82, stale_after: 0, unknown_today: 17079 }
  tests: { suite: 2804 }
lessons:
  - title: A widened pattern needs the corpus dry run before it is trusted
    detail: 'Two reading edits passed their tests and failed on the corpus: a bare "in Scotland" qualifier matched inside "(… except in Scotland …)" (243 rows moved), "the X is made" matched "the day after the day on which these Regulations are made" (lost +1 day). The relabel dry run caught both.'
    tag: data
  - title: Never --no-verify a commit while code is staged
    detail: 'A code commit failed its format hook and the follow-up session commit (--no-verify) swept the still-staged code in; undone with a soft reset and redone. Stage sessions-only before a --no-verify commit.'
    tag: tooling
bugs:
  - pattern: 'LawStart.Provisions reads an "Otherwise … comes into force on" sentence over provisions an earlier sentence commences (uksi 2017/469 art.11)'
    category: commencement clause
    module: LawStart.Provisions
    affected: 4
    fix: 'the ruleset: "Otherwise" = rest; the source''s named rules win (CR-03)'
    status: fixed
  - pattern: 'A row''s dated commencement record lost to a qualified record of the same sentence (Commencement uniq by {section_id, evidence}: wsi 2026/103 reg.36)'
    category: commencement register
    module: ChangeCollector.Commencement
    affected: 1
    fix: the register's provision records are replaced by the evaluator at CR-06
    status: open
  - pattern: 'A sentence qualified by one item qualifies all it names ("Sections 33, 34, 41 and (in so far as …) 42": asp 2005/13)'
    category: commencement clause
    module: LawStart.Provisions
    affected: 32
    fix: qualify per item outside "the following" lists too
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/own_clause.ex
  - backend/lib/sertantai_legal/scraper/law_start/provisions.ex
  - backend/lib/mix/tasks/lat.commencement.ex
  - backend/data/reports/commencement-rules/cr03_cmp4.csv
  - backend/data/reports/lat-refactor/cr03_dry3.csv
depends_on:
  - commencement-rules/2026-10-18-cr-02-evaluator
enables:
  - commencement-rules/2026-10-18-cr-04-reader-orders
  - commencement-rules/2026-10-18-cr-06-switch-over
---

# Session: CR-03: Reader — a Law's Own Commencement Clause (CLOSED)

## Problem

A law's own commencement clause becomes rules: the reading `LawStart.Clause` (LR-33) and `LawStart.Provisions` (LR-34) do today, written as rules instead of register records.

## Todo

- ✅ `Commencement.OwnClause`: `LawStart`'s decision → the law-level rule; `Provisions.groups/3` (new, refs unexpanded: "pt.II", "pt.6.ch.1") → named / rest / qualified rules; `context/1` (containers from `part` / `chapter`, document order)
- ✅ "Otherwise …" / "The remaining provisions …" = `rest` (never the commencement provision itself); the source's named rules win (uksi 2017/469 art.11, SI 1988/819 reg.4)
- ✅ Classified diff (`mix lat.commencement --compare --all`, `cr03_cmp2`): below
- ✅ Jason 2026-10-18 "Accept the decisions": (1) a qualified sentence is a partial rule — replaces LR-34 D2 (listed, no effect); (2) a staged clause keeps LR-33 P1's law-level rule (the earliest date) for now; (3) apply the 59
- ✅ Relabel dry run of the reading edits (`cr03_dry3`): 59 label changes in 5 laws, all explained (below); rules written (`--read --all`: 1,241 rules, 994 laws)
- ✅ Applied 2026-10-18: NAS backup, relabel (18 min), 0 stale, 82 of 82 predicted label fields live (59 rows); unknown today 17,079

## Dependencies

- ⬜ CR-01, CR-02

## Plan (2026-10-18)

The parsing in `LawStart.Clause` (made-relative counting, named days, staged clauses, territory) and `LawStart.Provisions` (lists, ranges, "except", Parts / Chapters, other-law guard) is kept and reused, not rewritten; the reader turns their reading into rules.

1. **The law-level rule**: `LawStart.resolve/1` keeps the catalogue order (register metadata → CLML → EU → the clause → Royal Assent → limits). Its decision becomes the source's general rule: scope `all`, `when` its date (`{:date, d}`; the treatment and the verbatim clause say how it was counted), `appointed "by order"` / `appointed "with another enactment"` for by_order / tied, `unread` for clause_unread; no rule for no_clause and the EU limits (unknown stays unknown).
2. **`Provisions.groups/3`** (public): the provision-level sentences as groups with **unexpanded** refs — provisions ("reg.45(4)(d)"), Parts and Chapters as the law's own ids ("pt.II", "pt.6.ch.1") — instead of the row ids `assign/3` expands them to (`assign/3` unchanged, built on it).
3. **Groups → rules**: named → refs; remaining / "otherwise" → `rest` with `except` (fixes the LR-34 "Otherwise" over-reach: the evaluator lets the source's named rules win); qualified → territory ("in relation to Wales") or one of the four purposes, with its date (LR-34 D2 listed them with no effect; as rules they give partial entries); unread → no rule (listed in the diff).
4. **Evaluator**: a row's containers from its `part` / `chapter` columns (`ctx.ancestors`); an `unread` rule doesn't make a provision prospective.
5. **Write and diff**: `mix lat.commencement --read [--law X | --all]` writes the rules (the new table only; no labels change); a classified diff of the evaluator's date per row against today's register (`LabelTimeline.row_starts/1` + `law_start/1`), every difference explained, before CR-06 switches anything.

## Built (2026-10-18)

- **Evaluator additions** (tests): an `unread` rule doesn't make a provision prospective; within a source, where the most specific rules are all partial they **complete** the next rule down, which still applies partly ("Regulation 26 … with respect to any tip which was not a classified tip": partly in force 2006, fully 2007; "Regulation 5 … in relation to Wales on 1 October": partly from April, fully from October); an excepted rule doesn't name a provision; duplicate-id suffixes ("#2", "n1": 571 rows) don't hide a provision.
- **`Provisions` edits** (they reach today's register too): `groups/3`; an item's "except" is relative to the first *provision* named, not a Part's id (`relative_base`); a tail starting with its territory is dated ("in relation to Wales on …"); bare "in Wales" / "in England" … is a qualifier like "in relation to".
- `mix lat.commencement --read` / `--compare`.

## Comparison (`cr03_cmp2`): evaluator vs register, per row

373,393 of 374,900 rows the same (99.6%). Differences, each class read on examples:

| Class | Rows | Laws | Why |
|---|---|---|---|
| dated → partial first (qualified) | 954 | 20 | **design change**: a qualified sentence is a partial rule (LR-34 D2 listed it with no effect). Quarries reg.26, Explosives 2014 reg.33(7), FWMA 2010 Parts 1–2 (England / Wales by order), Building Act 1984 s.12 |
| by_order → dated | 246 | 8 | J6 rows a qualified sentence now dates partly (asp 2012/8 Part 2 "but only for the purpose of …"); **over-reach**: asp 2005/13 s.33 — "Sections 33, 34, 41 and (in so far as …) 42" qualifies the whole sentence, only s.42 is (an LR-34 reading limit, now with an effect) |
| dated → unknown | 165 | 8 | the text leaves them to orders, the register gave the law's start: "The other provisions … by order" not applied (asp 2012/8 s.128 "this Part (other than section 128)"; ukpga 2010/15, 2013/32, 2022/30); FWMA 2010 s.22(1)(b) (by order, qualified) |
| dated → partial only | 70 | 1 | rules right: Environment Act 2021 s.51 … — in force 2 months after passing for some purposes (s.147(2), qualified), in Northern Ireland by order (s.147(6)): partly in force from 2022-01-09; the register gave the staged earliest date 2021-11-09 |
| later / earlier | 38 | 4 | register misreads, rules right: SI 1988/819 "The remainder … 3rd October 1988"; 2021/30 s.147(2) "2 months"; wsi 2026/103 reg.36 (item (f) names it: the register's dated record lost to a qualified record of the same sentence, `Commencement` uniq by {section_id, evidence}) |

## Question for Jason: a staged clause's earliest date

LR-33 P1: a staged clause ("This Act comes into force as follows—") dates the law's start by the earliest date its sentences state; rows no sentence names take it (J1). As a rule that reads "all — 2010-04-08", which the law doesn't say. Dropping it (tried, `cr03_cmp3`): 4,666 rows in 35 laws dated → unknown — partly honest (FWMA 2010 s.22(1)(b) is by order), largely reader gaps (Health and Care Act 2022 s.186's "other provisions" sentence unread; SI 2018/1203's compound "This regulation … and the remaining provisions …"). Kept as LR-33 decided until Jason says otherwise.

## Reading edits that reach today's register: relabel dry run (`cr03_dry3`)

Two edits caught on the way, with tests: the bare "in Scotland" qualifier first matched inside "(which are about civil enforcement except in Scotland …)" (uksi 2017/1200: 243 rows moved; narrowed to "comes into force in Wales on …"); "the X is made" first matched "the day after the day on which these Regulations are made" (lost the +1 day; narrowed to instrument nouns). Final: 59 label changes, unknown today 17,102 → 17,079:

| Law | Rows | Change | Why |
|---|---|---|---|
| uksi 2016/1245 | 23 | unknown → in force 2016-12-26 | "the seventh day after the day on which the Regulations are made" now read (made 2016-12-19) |
| ukpga 2013/32 | 25 | in_force_from emptied (J6) | "The provisions of this Act come into force on such day as the Secretary of State may by order … appoint, subject to subsections (2) and (3)": by order |
| ukpga 2022/30 | 9 | emptied (J6) | "The other provisions of this Act come into force on such day as the Secretary of State may by regulations appoint" |
| ukpga 2010/15, asp 2012/8 | 2 | emptied (J6) | the same; asp 2012/8 s.128 ("this Part (other than section 128)") |

Comparison after them (`cr03_cmp4`): same 373,430; dated → partial first 905; by_order → dated 218; dated → unknown 173; partial only 70; later 28; earlier 19; unknown → dated 23 (uksi 2016/1245, as above) — classes as `cr03_cmp2`.

## Decisions (Jason 2026-10-18: "Accept the decisions")

1. **Qualified sentences are partial rules** ("for the purposes of …", "in relation to Wales", "with respect to …"): the provision is partly in force from the general date and fully once the qualified sentence's date arrives. Replaces LR-34 D2 (listed with no effect). In the labels from CR-06.
2. **A staged clause keeps LR-33 P1's law-level rule** (its earliest date reaches rows no sentence names) until the reader reads the sentences it misses (Health and Care Act 2022 s.186's "other provisions"; SI 2018/1203's compound sentence) — then revisit.
3. **Apply the 59 label changes** (`cr03_dry3`).
