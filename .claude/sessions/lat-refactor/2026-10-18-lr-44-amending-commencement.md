---
session: 'LR-44: Dating Amending Provisions'
status: closed
opened: '2026-10-18'
closed: '2026-10-18'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'Sized the undated amending-law records (2,552 distinct: 1,463 Acts whose held commencement orders give no date, 706 Acts with no order named, 383 SIs whose own start is not read) and, with Jason, chose a common commencement ruleset (readers → rules → one evaluator). Gemini reviewed the schema; implementation moved to the Commencement Ruleset meta (CR-00, CR-01–CR-07).'
decisions:
  - what: 'One commencement ruleset: source text translated to readable rules; one evaluator dates any provision'
    why: 'Jason 2026-10-18: "the key would be the schema for the abstracted rules … translated to a common ruleset that''s easy to read"; four readers cover different subsets today'
    result: commencement-rules/2026-10-18-cr-00-meta.md
  - what: 'Gemini: purposes a fixed set; add retrospective, expiry, on_event, not_already_in_force; aggregate rules in date order (a full commencement supersedes partial ones)'
    why: 'Gemini 2.5 Pro review of the draft (backend/data/code-reviews/2026-10-18-commencement-ruleset-schema-gemini.md)'
    result: CR-01 decides the fields, CR-02 the evaluator
metrics:
  undated_amending_records: { total: 3452, undated: 2745, distinct_by_cause: 2552, act_orders_no_date: 1463, act_no_order_named: 706, si_own_unread: 383 }
lessons:
  - title: Once documents are held, the gaps are all reading
    detail: 'After LR-42 no undated amending-law record lacks a held order or law; every one fails at reading commencement. The answer was one schema for commencement rather than more reader patches.'
    tag: data
artifacts:
  - backend/data/code-reviews/2026-10-18-commencement-ruleset-schema-gemini.md
depends_on:
  - 2026-10-17-lr-41-instruction-law
  - 2026-10-17-lr-42-fetch-amending-laws
enables:
  - commencement-rules/2026-10-18-cr-00-meta
---

# Session: LR-44 Dating Amending Provisions (CLOSED)

## Problem

The amending-law collector finds the change but can't date it: the amending provision's own commencement is by order or unread, and hop 2 (the commencing orders the note names, `CommencingOrder`) finds no date (LR-40 cause 5: 2,405 records undated, 1,057 partial only; after LR-41 most new records stall here — sample: 47 reach a record, 6 dated). The benchmark also shows the dates it does find differ from the feed's in 854 cases (Water Act 2014: England 2017 vs Wales 2019). Jason 2026-10-18: commencement before block changes (LR-43).

## Todo

- ✅ Size after the LR-41/42 relabel (`undated_al.exs`): 3,452 amending-law records, 2,745 undated; 2,552 distinct by cause (below)
- ⏸️ Trace a sample of "order held, no date read" (moved to CR-04)
- ✅ D1 (Jason 2026-10-18): a common commencement ruleset, readers → rules → one evaluator; Gemini reviewed (`backend/data/code-reviews/2026-10-18-commencement-ruleset-schema-gemini.md`)
- ⏸️ Build, tests, dry run, benchmark, apply (moved to the Commencement Ruleset meta: `commencement-rules/2026-10-18-cr-00-meta.md`, CR-01–CR-07)

## Dependencies

- ✅ LR-41/42 (records reach this stage); LR-33 `LawStart` (an amending SI's start)

## Sizing (2026-10-18)

| Amending law | Its own commencement (`AmendingLaw.Commencement`) | Hop 2 | Records |
|---|---|---|---|
| Act | unknown or by order | orders named and held, **no date read** (`CommencingOrder`) | 1,463 (1,123 + 340) |
| Act | unknown or by order | no order named in the note | 706 (609 + 97) |
| SI / other | **unknown** | no order named | 300 |
| SI / other | unknown | orders named, no date read | 83 |

No order named or held is missing (LR-42 fetched them). An SI's own start is `LawStart`'s (LR-33) — the old reader returns unknown for 383 SI records.

## Design question: one provision-start reader (Jason 2026-10-18: "is there benefit from abstracting amending/commencing rules")

Four readers answer "when did provision P of law L come into force": `LawStart` + `Clause` (law-level, 14 treatments), `LawStart.Provisions` (the labelled law's own clause), `AmendingLaw.Commencement` (LR-08, an older subset), `CommencingOrder` (hop 2). Proposal: one provision-start reader with one treatment catalogue, used for the labelled law and for amending laws; one commencement-order reader, used by hop 2 here and later by a commencement-order collector for J6 (`commenced_by_order`, 18,394 rows).

## Design draft: a commencement ruleset (Jason 2026-10-18: "the key would be the schema for the abstracted rules … translated to a common ruleset that's easy to read")

Two halves, kept apart:

1. **Readers** translate source text into rules, once per source document: a law's own commencement clause, each commencement order, an amending law's clause. All XML and prose handling lives here.
2. **One evaluator** answers "when did provision P of law L come into force, and where?" from the rules only. Every consumer asks it: the labelled law's start (LR-33/34), an amending change's date (LR-08/44), and J6's by-order rows.

### A rule

One rule per commencement statement (a sentence, or one item of a list):

| Field | Meaning | Values |
|---|---|---|
| `commences` | the law whose provisions start | `UK_ukpga_2014_21` |
| `scope` | which provisions | `all` · `[refs]` (section / regulation / article / Part / Chapter / Schedule / paragraph, with ranges "ss. 1–5") · `rest` ("otherwise", "the remaining provisions") · `except: [refs]` |
| `when` | when they start | `date: 2017-04-01` · `after: made / passed, offset: 1 day / 2 months` · `named_day: exit_day / ip_completion_day` · `by_order` (appointed day, power in `power`) · `with: <law/provision>` (tied to another commencement) · `unread` |
| `territory` | where | nil (everywhere the provision extends) · `E` / `W` / `S` / `NI` / combinations ("in relation to England") |
| `purposes` | how far | nil (fully) · `specified` ("for specified purposes") · text ("so far as it confers power to make regulations") |
| `source` | where the rule came from | `{law, provision id, sentence verbatim}`: the order or clause read |
| `treatment` | catalogue name (LR-33's, extended) | `clause_date`, `made_relative`, `named_day`, `order_date`, … |

### Examples (from cases met in A8)

```
# uksi 2017/469 art.1 (LR-34's open "Otherwise" bug)
commences: UK_uksi_2017_469  scope: [art.1, art.2, art.11]  when: after made +1 day          treatment: made_relative
commences: UK_uksi_2017_469  scope: rest                    when: date 2017-05-08              treatment: clause_date

# SI 2019/696 reg.1 (the old amending reader returns unknown)
commences: UK_uksi_2019_696  scope: all  when: named_day exit_day   → 2020-01-31               treatment: named_day

# Merchant Shipping Act 1995 s.316(2)
commences: UK_ukpga_1995_21  scope: all  when: date 1996-01-01                                 treatment: clause_date

# a Water Act 2014 commencement order (shape; wording to be read)
commences: UK_ukpga_2014_21  scope: [s.11]  when: date 2017-04-01  territory: E                 treatment: order_date
commences: UK_ukpga_2014_21  scope: [s.11]  when: date 2019-04-01  territory: W                 treatment: order_date

# Environment Act 1995 s.57 via SI 2000/340 (1990/43 s.78H, partial)
commences: UK_ukpga_1995_25  scope: [s.57]  when: date 2000-04-01  territory: E  purposes: specified
```

### The evaluator (one place, pure)

For a provision P of law L (a row, or an amending provision):
- the rules whose `scope` covers P: its own ref, an ancestor (Part, Schedule), `all`, or `rest` when no other rule names it;
- the most specific scope wins, and an explicit ref beats `rest` beats `all`;
- each matching (territory, purposes) gives an in-force entry: full where territory and purposes are nil, partial otherwise (today's in-force entries and `EffectFacts.partial?`);
- `when` resolves to a date (`after made`, named days from the catalogue) or stays undated (`by_order` with no order rule, `unread`) — the gap says which.

### Storage (to decide)

A table of rules per law (`commencement_rules`, an Ash resource): queryable ("which rules start ukpga/2014/21 s.11?"), and `mix lat.commencement --law X` prints a law's ruleset in the form above. The register's commencement records (LR-33/34) and amending-law dates then cite the rule that dated them.
