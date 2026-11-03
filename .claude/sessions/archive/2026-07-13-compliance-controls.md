---
session: Control domain model — bridge fractalaw to Baserow
project: sertantai-legal
status: closed
opened: 2026-07-13
closed: 2026-07-13
outcome: partial
commits: []

summary: >
  Built Control + ControlMapping Ash resources, Zenoh ControlsSubscriber, and Baserow sync integration
  to bridge fractalaw AI-generated controls into sertantai-legal. Ingested full QQ corpus (1,341 controls +
  219 predicates across 219 laws). Discovered and diagnosed linked_provisions schema drift between
  fractalaw and sertantai (4 issues), plus a pre-existing LAT parser bug (#120) affecting 4,325 section_ids.

decisions:
  - what: Controls are shared reference data (no organization_id), like LegalRegister
    why: Controls are generated from law text, not customer-specific. Customer scoping happens at Baserow sync time by filtering to laws in the customer's Legal Register.
    result: Simple upsert model, no multi-tenancy complexity on the controls table

  - what: Predicates share the controls table with is_predicate boolean
    why: Predicate schema is a subset of Control — same law_name+control_id key, same content fields. Separate table would duplicate 90% of the schema.
    result: 219 predicates stored alongside 1,341 controls, trivially filterable

  - what: Plain strings for constrained fields (no Ash enums)
    why: fractalaw may add new control_type/nature/domain values. Ash enums require migrations to extend. Postgres text column with Elixir-side validation avoids migration churn.
    result: Zero schema changes needed when fractalaw vocabulary evolves

  - what: Normalize art.→reg. for domestic instruments on ingest
    why: fractalaw has 244 SIs sending art. prefix. Convention is art.=EU only, reg.=all domestic. Fixing at ingest avoids depending on fractalaw fix timeline.
    result: Subscriber-side normalization catches prefix drift without upstream dependency

metrics:
  controls: { total: 1560, controls: 1341, predicates: 219, laws: 219 }
  control_mappings: { total: 4050, resolved: 3902, unresolved: 148, pct: 96.3 }
  field_completeness: { all_fields: "100%", honest_limit: "76%" }
  type_distribution: { Preventive: "52%", Directive: "28%", Corrective: "11%", Detective: "9%" }
  lat_parser_corruption: { affected_rows: 4325, affected_laws: 68 }

lessons:
  - title: fractalaw section_id format drifts from sertantai LAT despite pulling the same data
    detail: >
      fractalaw pulls parsed LAT from sertantai, yet 4 distinct section_id format mismatches emerged:
      doubled law_name prefix, doubled reg numbers, wrong art./reg. prefix, LLM hallucinated refs.
      Root causes: LLM output used directly instead of validating against actual LAT section_ids,
      and prefix logic reconstructed instead of read from source data.
    tag: zenoh

  - title: art. prefix is ONLY for EU retained law — all domestic UK instruments use reg.
    detail: >
      Including Orders, Rules, and mixed Order+Regulations instruments (e.g. Fire Scotland SSI 2006/456).
      The LAT parser convention is based on type_code (eudr/eur = art., everything else = reg.),
      not on what legislation.gov.uk calls the provisions internally.
    tag: schema

  - title: LAT parser has a pre-existing P2 wrapper bug doubling provision numbers
    detail: >
      4,325 section_ids across 68 laws have reg.N(N) pattern where P2 Pnumber repeats P1 provision.
      Caused by legislation.gov.uk using P2 as a structural container (not a subsection) for some SIs.
      When provision==sub, the (sub) component should be omitted. Filed as #120.
    tag: schema

  - title: Ash.Type.Enum stores as text in Postgres — no ALTER TYPE migration needed
    detail: >
      SourceType enum values (:controls, :control_mappings) added without any Postgres migration.
      The Ash.Type.Enum validates in Elixir but the column is text in Postgres. This was a pleasant
      surprise vs the expected ALTER TYPE ... ADD VALUE dance.
    tag: schema

  - title: Zenoh ** wildcard needed for multi-depth key expressions
    detail: >
      controls/{law_name} and controls/predicate/{law_name} have different path depths.
      Single * matches one segment only. Used controls/** to catch both patterns in one subscriber.
    tag: zenoh

artifacts:
  - backend/lib/sertantai_legal/legal/control.ex
  - backend/lib/sertantai_legal/legal/control_mapping.ex
  - backend/lib/sertantai_legal/zenoh/controls_subscriber.ex
  - backend/priv/repo/migrations/20260713154111_add_controls.exs
  - docs/controls/ZENOH-CONTROL-SPEC.md

depends_on:
  - 2026-06-03-onboarding-phase5b-lat-taxa.md
  - 2026-07-03-baserow-compliance-poc.md

enables:
  - Baserow Controls + Control Mappings sync for customers
  - Control generation request publisher (Phase 4 deferred)
  - LAT parser section_id fix (#120)
---

# Title: Control domain model — bridge fractalaw to Baserow

**Started**: 2026-07-13
**Scope**: Add Control + ControlMapping Ash resources, Zenoh subscriber, Baserow sync

## Todo
- [x] Understand existing Zenoh subscriber + Baserow sync patterns
- [x] Design Control + ControlMapping Ash resources
- [x] Phase 1: Create Control + ControlMapping resources, register in domain, migrate
- [x] Phase 2: Create ControlsSubscriber, register in Zenoh supervisor
- [x] Phase 3: Baserow sync — SourceType enum, provider fields/formatters, engine integration
- [ ] Phase 4: Control generation request publisher (low priority) (deferred)

## Notes
- Spec: docs/controls/ZENOH-CONTROL-SPEC.md
- Baserow design: docs/compliance/l3-controls/BASEROW-CONTROLS-DESIGN.md
- Plan file: ~/.claude/plans/memoized-prancing-fox.md
- Controls = shared reference data (like LegalRegister), no org_id
- Predicates share controls table with `is_predicate: true`
- ControlMapping derived from `linked_provisions` → section_ids (fractalaw sends full IDs)
- SourceType is Ash.Type.Enum (text in pg — no ALTER TYPE needed)
- Sync order: LRT → LAT → ActorTuples → Controls → ControlMappings

## QQ Corpus Ingest (2026-07-13)
- 1,341 controls + 219 predicates across 219 laws
- 3,949 control_mappings, 2,786 resolved (70.5%), 1,163 unresolved
- Field completeness: 100% except honest_limit (76%)
- Type dist: Preventive 52%, Directive 28%, Corrective 11%, Detective 9%
- Admin UI updated: separate tab per subscriber (Taxa, Provisions, Controls)

## linked_provisions schema drift — 4 issues
fractalaw pulls parsed LAT from sertantai, so section_ids should match exactly. They don't.

- [x] **Issue 1: doubled law_name prefix** — subscriber prepended law_name when fractalaw already sent full section_ids. Fixed in subscriber (detect prefix, handle both formats).
- [ ] **Issue 2: doubled reg numbers (38 remaining)** — `reg.49(49)(5)` instead of `reg.49(5)` for SSI laws. Mostly fixed, 38 residual in SSI laws. fractalaw permanent fix in progress. (deferred)
- [x] **Issue 3: EU sub-article granularity** — was 1,026, now resolved. Was LLM hallucination, fractalaw now validates against LAT section_ids.
- [ ] **Issue 4: edge cases (43)** — 33 LLM hallucinated refs (don't exist in LAT), 4 lettered sections (`s.11A`), 2 `#position` suffix leaks, 4 regs missing from LAT. All fractalaw-side, permanent fix in progress. (deferred)

**Current**: 3,902/4,050 resolved (96.3%). Remaining 148 = mix of fractalaw validation + LAT parser bugs.

## LAT parser section_id corruption — Issue #120
- 4,325 legal_articles rows across 68 laws with doubled provision numbers (e.g. `art.30(30)`)
- 63 of those also use `art.` instead of `reg.` on domestic SIs
- Root cause: P2 Pnumber repeats P1 provision number when XML uses P2 as structural wrapper
- Cascades to control_mappings, amendment_annotations
- Separate fix + data migration needed — not part of this session
