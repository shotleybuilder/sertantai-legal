# Title: Phase 2.5 — AU State Portal Parsers

**Started**: 2026-05-19
**Plan**: `.claude/plans/multi-jurisdiction.md`

## State Records Needing Enrichment
| Jurisdiction | Records | Enriched | Portal |
|---|---|---|---|
| NSW | 154 | 2 | legislation.nsw.gov.au (403 on automated access) |
| QLD | 134 | 0 | legislation.qld.gov.au (has API) |
| ACT | 124 | 2 | legislation.act.gov.au |
| VIC | 115 | 0 | legislation.vic.gov.au |
| SA | 104 | 2 | legislation.sa.gov.au |
| NT | 77 | 0 | legislation.nt.gov.au |

## Todo
- [x] Research each state portal for URL patterns and API availability
- [x] Build `mix au.enrich_state` — slug-based URL construction + HEAD verification
- [x] VIC enrichment: 55/115 (48%)
- [x] NT enrichment: 46/77 (60%)
- [x] Manual corrections: WHS Act→cth, Building Act 1993→vic, COVID-19→act, WHS Reg→qld
- [x] Marked 174 records as non-legislation (standard, cop) — excluded from enrichment
- [x] Enrichment tasks now skip standards/CoPs
- [x] NSW feed client built — Atom feed bypasses 403 block, title search works
- [x] NSW initial run: 3/50 matched (39 errors — rate limited, needs slower delay)
- [x] Type codes stripped of jurisdiction prefix (act, reg, li, obj, nepm, etc.)
- [x] NEPM type_code added, NPI Objective classified correctly
- [ ] NSW: tune rate limiting, run full enrichment
- [ ] QLD, SA, ACT — investigate feed/API options

## Portal URL Patterns

| Portal | Pattern | Constructible? | Status |
|---|---|---|---|
| VIC | `/in-force/acts/{title-slug}` | Yes (slug from title) | **done** 55/115 |
| NT | `/Legislation/{TITLE-SLUG}` | Yes (uppercase slug) | **done** 46/77 |
| QLD | `/view/html/inforce/current/act-{year}-{number}` | No (need number) | blocked |
| ACT | `/a/{year}-{number}` | No (need number) | blocked |
| NSW | `/view/html/inforce/current/act-{year}-{number}` | No (need number + 403) | blocked |
| SA | all paths | N/A | 403 blocked |

## Enrichment Summary

| Jurisdiction | Total | Enriched | Rate |
|---|---|---|---|
| cth | 177 | 137 | 77% |
| vic | 115 | 55 | 48% |
| nt | 77 | 46 | 60% |
| nsw | 154 | 2 | 1% |
| qld | 134 | 0 | 0% |
| act | 124 | 2 | 2% |
| sa | 104 | 2 | 2% |

## Notes
- From Phase 2.3 research: NSW returns 403, QLD has Swagger API (but 401), VIC has slug-based URLs
- Federal API pattern (OData) won't apply — each state is different
- Goal: source_url + live status, not full metadata parity with federal
