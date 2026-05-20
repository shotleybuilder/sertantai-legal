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
- [x] NSW feed tuned (10s delay, 30s retry on 429)
- [x] NSW manual annotation applied: 88 updated, 13 created, 6 repealed marked
- [x] NSW now: 176 records, 114 with URLs, 117 with numbers, 110 with status
- [x] Type codes stripped of jurisdiction prefix (act, reg, li, obj, nepm, etc.)
- [x] NEPM type_code added, NPI Objective classified correctly
- [x] QLD enriched via in-force legislative tables (Acts 573 + Regs 446) + manual annotations
- [x] QLD: 110/133 with URLs, 26 repealed, 0 legislation remaining
- [x] ACT enriched: 65 verified from website (43 repealed, 22 in force), 21 stale determinations deleted
- [ ] SA — blocked (Cloudflare + PDF-only, no parseable data). Manual annotation future task

**Ended**: 2026-05-20
**Commits**: `af8480e`, `c651ddb`, `e445f6e`, `4da66f9`, `cf097f7`, (pending)

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

| Jurisdiction | Total | Has URL | Has Status | Repealed |
|---|---|---|---|---|
| cth | 178 | 138 | 137 | 14 |
| nsw | 176 | 126 | 120 | 12 |
| qld | 133 | 110 | 106 | 26 |
| act | 104 | 65 | 58 | 3 |
| vic | 116 | 56 | 0 | — |
| sa | 104 | 2 | 2 | 1 |
| nt | 75 | 47 | 0 | — |
| **Total** | **887** | **544** | **423** | **56** |

Key findings:
- **ENHESA staleness is severe**: ACT shows 66% repeal rate (43/65 verified as repealed)
- Total confirmed repealed across all states: 56+ (NSW/QLD) + 43 (ACT) = 99+
- ACT: 21 stale determinations deleted, ni/di type_codes added
- ACT client built — fetches real metadata from website (status confirmed vs assumed)
- Dry-run comparison mode catches conflicts between DB and website status
- SA remains untouched (403 blocked, no feed or tables found)

## Notes
- From Phase 2.3 research: NSW returns 403, QLD has Swagger API (but 401), VIC has slug-based URLs
- Federal API pattern (OData) won't apply — each state is different
- Goal: source_url + live status, not full metadata parity with federal
