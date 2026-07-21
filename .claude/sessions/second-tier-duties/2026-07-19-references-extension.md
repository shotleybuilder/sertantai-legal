---
session: References Extension to SecondaryTaxaSubscriber
project: sertantai-legal
status: closed
opened: 2026-07-19
closed: 2026-07-19
outcome: success
commits: [b46e0d9]

summary: >
  Extended SecondaryTaxaSubscriber to parse references_json from fractalaw's
  consolidated enrichment payload, creating source_links for legislation
  cross-references. JSP-375-CH23 produced 9 source_links to 8 distinct UK laws.

decisions:
  - what: Read-then-create instead of Ash upsert for source_links
    why: >
      SourceLink unique identity includes nullable columns (section_id,
      secondary_section_id). PostgreSQL treats NULL != NULL in unique indexes,
      so upsert identity never matches and creates duplicates.
    result: No duplicates after re-publish

  - what: Park JSP cross-references, log batch summary only
    why: No inter-secondary link table exists yet; per-provision debug logging was too noisy (~20 lines per source)
    result: Single summary line per source batch

  - what: Three-step regex normaliser for DuckDB struct syntax
    why: >
      DuckDB serialises list-of-structs as VARCHAR with single-quoted keys,
      unquoted values, and single-quoted values when they contain commas.
      Standard JSON parser fails on all of these.
    result: Handles all observed formats from JSP-375-CH23 publish

metrics:
  source_links: { created: 9, distinct_laws: 8, provisions_with_refs: 5 }
  tests: { total: 27, new: 10 }

lessons:
  - title: PostgreSQL unique indexes with nullable columns break Ash upsert
    detail: >
      When a unique identity includes nullable columns, PostgreSQL's NULL != NULL
      semantics mean the upsert identity never matches existing rows. Two rows with
      identical non-null columns but NULL in a nullable identity column will both be
      inserted. Use explicit read-then-create/update instead.
    tag: schema

  - title: DuckDB list-of-structs VARCHAR has three value quoting styles
    detail: >
      DuckDB serialises struct values as: (1) unquoted for simple values like
      `legislation`, (2) single-quoted when containing commas like `'JSP 375 Volume 3, Chapter 3'`,
      (3) unquoted multi-word like `Health and Safety at Work etc. Act 1974`.
      A three-step regex (keys → quoted values → unquoted values) handles all cases.
    tag: zenoh

artifacts:
  - backend/lib/sertantai_legal/zenoh/secondary_taxa_subscriber.ex
  - backend/lib/sertantai_legal/legal/source_link.ex
  - backend/test/sertantai_legal/zenoh/secondary_taxa_subscriber_test.exs

depends_on:
  - 2026-07-18-secondary-taxa-subscriber.md

enables:
  - Baserow sync of secondary source ↔ legislation traceability
  - Inter-secondary JSP cross-reference table (when needed)
---

# References Extension to SecondaryTaxaSubscriber

**Started**: 2026-07-19
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (references_json section)

## Todo
- [x] Parse `references_json` from Arrow row (DuckDB struct syntax → Elixir maps)
- [x] Add upsert action to SourceLink resource
- [x] For legislation refs: upsert into source_links (secondary_source_id, law_name, link_type=references, secondary_section_id)
- [x] Resolve source_id → secondary_source_id (UUID) with caching
- [x] JSP cross-refs: log/skip for now (no inter-secondary table)
- [x] Null/empty references_json: skip, don't clear
- [x] Tests for DuckDB struct parsing
- [x] Tests for reference processing

## Notes
- DuckDB struct syntax: `{'key': value}` not `{"key": "value"}` — needs normalisation
- SourceLink identity: [:secondary_source_id, :secondary_section_id, :law_name, :section_id, :link_type]
- section_id on SourceLink is the *primary law* provision — null for doc-level refs
- secondary_section_id = the provision's section_id from the Arrow row
