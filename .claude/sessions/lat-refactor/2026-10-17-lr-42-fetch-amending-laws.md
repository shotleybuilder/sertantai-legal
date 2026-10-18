---
session: 'LR-42: Fetch Missing Amending Laws'
status: active
opened: '2026-10-17'
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-42 Fetch Missing Amending Laws (ACTIVE)

## Problem

890 of the 1,230 amending laws named on `undated_change` rows aren't in the CLML store, so the amending-law collector can't read them (LR-40 cause 2: 6,060 row–law pairs). Commencing orders the same notes name (hop 2) may be missing too. Jason 2026-10-17: "Go on both 1 and 2".

## Todo

- ✅ List (`fetch_list.exs`): 2,282 laws named (amending laws + the commencing orders hop 2 reads), 1,821 not held (uksi 1,152, ukpga 385, ssi 94, asp 35, nisr 31, eur 30 …)
- ✅ Fetched (`mix clml.fetch --laws`, trial of 3 first): 1,805 stored; 16 are 404 on legislation.gov.uk (not online: ukpga 1974/70, uksi 2000/323 …) — a known limit; flagged pairs whose amending law is held 21,063 of 21,089 (26 pairs, 14 laws not)
- ✅ Measure the fetch alone (`lr42_dry`, LR-41 not yet built): undated_change 16,528 → 16,437, insertion_not_in_register 9,529 → 9,488, unknown today 17,345 → 17,304; 503 label diffs in 40 laws (changed_by gained 186, effective_from gained 146, unknown → in force 51). Losses traced to an LR-08 Target bug the new laws exposed (fixed in LR-41): ERA 1996 s.235 (11 rows in force → unknown), 1973/26 s.4 (8 emptied)
- ⬜ Apply with LR-41 (one relabel)
- ⬜ NAS backup of `backend/data` after the fetch

## Dependencies

- ✅ LR-40 cause map; #175 CLML store
