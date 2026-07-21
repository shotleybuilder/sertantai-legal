---
session: Obligations & RACI Extension to SecondaryTaxaSubscriber
project: sertantai-legal
status: closed
opened: 2026-07-19
closed: 2026-07-20
outcome: success
commits: [41d6516]

summary: >
  Added secondary_obligations and secondary_raci tables for JSP obligation data.
  Rewrote DuckDB struct parser from regex normalisation to key-boundary scanning
  to handle embedded quotes, colons, and commas in obligation text. JSP-375-CH23
  pilot: 117 obligations, 32 RACI across 7 MoD roles.

decisions:
  - what: Separate tables (secondary_obligations, secondary_raci) not JSONB on provision
    why: >
      Key query is "all obligations for Commanding Officer across applicable JSPs"
      which needs JOIN with org_secondary_applicabilities. Baserow sync needs
      row-per-obligation. JSONB would require unpacking at query time.
    result: 117 obligations and 32 RACI rows created from single JSP chapter

  - what: Replaced regex DuckDB normaliser with key-boundary scanner
    why: >
      Obligation text contains embedded single quotes ('Unsafe – Do Not Use'),
      colons (safety points: a. Do not...), and commas. Three-step regex broke
      on all of these. Key-boundary approach scans for 'word': patterns which
      never appear inside values.
    result: Zero parse failures on JSP-375-CH23 (was 4 failures with regex)

  - what: Full replace for RACI per source, upsert for obligations
    why: >
      Obligations have stable obligation_id for upsert identity. RACI has no
      natural unique key (same role can appear multiple times). Delete-then-insert
      per source_id is clean and idempotent.
    result: Re-publishes produce identical row counts

metrics:
  obligations: { total: 117, mandatory: 79, recommended: 21, permissive: 5, with_competence: 22 }
  raci: { total: 32, responsible: 28, informed: 4, distinct_roles: 7 }
  tests: { total: 30, new: 3 }

lessons:
  - title: DuckDB struct VARCHAR breaks on any regex-to-JSON normalisation
    detail: >
      DuckDB list-of-structs as VARCHAR has three quoting styles (unquoted, single-quoted,
      embedded-quoted) and values can contain colons, commas, and literal single quotes.
      Regex substitution always misidentifies a boundary. Scan for key patterns ('word':)
      instead — they're unambiguous because they won't appear in legal text.
    tag: zenoh

  - title: String.slice/3 raises on negative length
    detail: >
      When a trim operation produces val_end < val_start, String.slice(str, start, negative)
      raises instead of returning "". Always guard with max(length, 0).
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/legal/secondary_obligation.ex
  - backend/lib/sertantai_legal/legal/secondary_raci.ex
  - backend/lib/sertantai_legal/zenoh/secondary_taxa_subscriber.ex
  - backend/priv/repo/migrations/20260719113500_add_secondary_obligations_and_raci.exs

depends_on:
  - 2026-07-19-references-extension.md

enables:
  - Baserow sync of obligations and RACI for customer compliance workbench
  - "All obligations for role X across applicable JSPs" query
  - Phase 4: mandated_artefacts_json column in same payload
---

# Obligations & RACI Extension to SecondaryTaxaSubscriber

**Started**: 2026-07-19
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (obligations_json + raci_json sections)
**Depends on**: 2026-07-19-references-extension.md

**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/126

## Todo
- [x] Create SecondaryObligation resource (`secondary_obligations` table)
- [x] Create SecondaryRaci resource (`secondary_raci` table)
- [x] Register in Api domain
- [x] Generate + run migration
- [x] Parse `obligations_json` in subscriber (DuckDB struct syntax)
- [x] Parse `raci_json` in subscriber (DuckDB struct syntax)
- [x] Upsert obligations keyed on `obligation_id` (`{section_id}:ob.{index}`)
- [x] Full replace RACI per source_id
- [x] Tests
- [x] Verify with live publish

## Notes
- One provision → many obligations (lettered lists "a. X must... b. Y must...")
- One obligation → many RACI assignments
- `obligation_index` is the join key between obligations and RACI within a provision
- Replaced regex DuckDB parser with key-boundary scanner (parse_duckdb_structs)
- Spec says Phase 3 of consolidated payload
