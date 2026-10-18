---
session: 'LR-42: Fetch Missing Amending Laws'
status: closed
opened: '2026-10-17'
closed: '2026-10-18'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'The amending laws and commencing orders named on undated-change rows were fetched into the CLML store: 1,805 of 1,821 (16 not on legislation.gov.uk). Flagged row–law pairs whose amending law is held 21,063 of 21,089. Applied with LR-41 (one relabel 2026-10-18).'
decisions:
  - what: Fetch amending laws and the commencing orders their notes name (hop 2), not only the amending laws
    why: hop 2 dates an amending provision commenced by order from the orders named
    result: 1,821 listed, 1,805 stored
metrics:
  fetch: { listed: 1821, stored: 1805, not_found_404: 16, pairs_held: 21063, pairs_total: 21089 }
  fetch_alone_dry_run: { undated_change: '16,528 → 16,437', unknown_today: '17,345 → 17,304' }
lessons:
  - title: New source documents expose old reader bugs
    detail: 'Holding PIDA 1998 and SI 2009/2861 surfaced LR-08 Target/Operation misreads (an insertion into s.235 read as an insertion of it; "omit the following definitions" as a whole repeal). Dry-run losses after a data fetch are worth tracing one by one: they were all reader bugs, fixed in LR-41.'
    tag: data
bugs:
  - pattern: '890 amending laws named on undated rows not in the CLML store; the amending-law collector cannot read them'
    category: source coverage
    module: CLML store
    affected: 6060
    fix: mix clml.fetch --laws (1,805 stored; 16 are 404 on legislation.gov.uk)
    status: fixed
artifacts:
  - backend/data/cache/clml (1,805 laws)
  - backend/data/reports/lat-refactor/lr42_dry.csv
depends_on:
  - 2026-10-17-lr-40-undated-change
enables:
  - 2026-10-18-lr-44-amending-commencement
---

# Session: LR-42 Fetch Missing Amending Laws (CLOSED)

## Problem

890 of the 1,230 amending laws named on `undated_change` rows aren't in the CLML store, so the amending-law collector can't read them (LR-40 cause 2: 6,060 row–law pairs). Commencing orders the same notes name (hop 2) may be missing too. Jason 2026-10-17: "Go on both 1 and 2".

## Todo

- ✅ List (`fetch_list.exs`): 2,282 laws named (amending laws + the commencing orders hop 2 reads), 1,821 not held (uksi 1,152, ukpga 385, ssi 94, asp 35, nisr 31, eur 30 …)
- ✅ Fetched (`mix clml.fetch --laws`, trial of 3 first): 1,805 stored; 16 are 404 on legislation.gov.uk (not online: ukpga 1974/70, uksi 2000/323 …) — a known limit; flagged pairs whose amending law is held 21,063 of 21,089 (26 pairs, 14 laws not)
- ✅ Measure the fetch alone (`lr42_dry`, LR-41 not yet built): undated_change 16,528 → 16,437, insertion_not_in_register 9,529 → 9,488, unknown today 17,345 → 17,304; 503 label diffs in 40 laws (changed_by gained 186, effective_from gained 146, unknown → in force 51). Losses traced to an LR-08 Target bug the new laws exposed (fixed in LR-41): ERA 1996 s.235 (11 rows in force → unknown), 1973/26 s.4 (8 emptied)
- ✅ Applied with LR-41 (relabel 2026-10-18)
- ✅ NAS backup (DB + `backend/data`) before the relabel

## Dependencies

- ✅ LR-40 cause map; #175 CLML store
