---
session: Phase 3 — Zenoh Queryables for Secondary Sources
project: sertantai-legal
status: closed
opened: 2026-07-16
closed: 2026-07-16
outcome: success
commits: []

summary: >
  Added 3 Zenoh queryables to DataServer for secondary source data. Fractalaw
  can now pull source metadata (JSON) and provisions (Arrow IPC or JSON) on
  demand. Pull-only — no pub/sub needed for static sources. Spec published.

decisions:
  - what: Pull-only queryables, no pub/sub for secondary sources
    why: Secondary sources are static (parsed from PDFs, updated infrequently). Publishing change events adds complexity for no benefit — fractalaw queries when it wants to enrich.
    result: 3 queryables added, zero subscription infrastructure needed
  - what: Arrow IPC default for provisions, JSON for source metadata
    why: Provisions can be large (45K records total). Arrow IPC is efficient for batch transfer to fractalaw's Polars/Rust pipeline. Source metadata is small — JSON is simpler.
    result: L8 (168 provisions) = 86KB Arrow IPC

metrics:
  queryables_added: 3
  key_expressions: ["sources", "sources/*", "provisions/*"]
  corpus_exposed: { sources: 208, provisions: 45049 }

lessons:
  - title: Secondary source queryables follow exactly the same DataServer pattern as legislation
    detail: "declare_queryables → handle_query route → fetch function → serialize. Adding a new data domain to the Zenoh mesh is mechanical — the pattern is established. No new infrastructure needed."
    tag: zenoh

artifacts:
  - backend/lib/sertantai_legal/zenoh/data_server.ex
  - docs/zenoh/ZENOH-SECONDARY-SOURCES.md

depends_on:
  - second-tier-duties/parse-acops.md
  - second-tier-duties/parse-hsgs.md

enables:
  - Fractalaw enrichment of secondary provisions (responsibility assignment classification)
  - Fractalaw control generation from secondary source obligations
---

# Title: Phase 3 — Zenoh Queryables for Secondary Sources

**Started**: 2026-07-16
**Parent**: second-tier-duties/meta.md

## Todo
- [x] Add key expressions: sources, sources/*, provisions/*
- [x] Add route clauses in handle_query
- [x] Add fetch functions: fetch_all_secondary_sources, fetch_secondary_source, fetch_secondary_provisions
- [x] Add JSON + Arrow IPC serialization
- [x] Test: source listing, provision fetch, Arrow serialization (L8: 168 → 86KB)
- [x] Spec published: docs/zenoh/ZENOH-SECONDARY-SOURCES.md

## Key expressions to add
```
fractalaw/@{tenant}/data/secondary/sources           -- all secondary sources
fractalaw/@{tenant}/data/secondary/sources/{source_id} -- single source + its provisions
fractalaw/@{tenant}/data/secondary/provisions/{source_id} -- provisions for a source
```

## Notes
- Pull-only (queryable) — no pub/sub for static sources
- Fractalaw will query when it wants to enrich provisions
- Subscription (enrichment results back) is a separate session later
- Follow existing DataServer patterns: Task.start for async, Arrow IPC default
