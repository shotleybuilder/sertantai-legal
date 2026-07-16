# Evidence Layer — fractalaw → sertantai-legal → Baserow

**Started**: 2026-07-16 13:11

## Context
Build Evidence layer in sertantai-legal to receive evidence patterns from fractalaw via Zenoh, store in Postgres, and sync to Baserow. Mirrors the Controls pattern. Spec: `docs/zenoh/ZENOH-EVIDENCE-SPEC.md`

## What exists already
- **Zenoh spec**: `docs/zenoh/ZENOH-EVIDENCE-SPEC.md` (fully defined)
- **Baserow templates**: `evidence_vault.ex`, `artefacts.ex`, `judgements.ex`, `gaps.ex` — customer-facing operational tables (customer fills these in, NOT fractalaw-generated)
- **Controls pattern to mirror**: `control.ex`, `control_mapping.ex`, `controls_subscriber.ex`, migration `20260713154111_add_controls.exs`

## Todo

### Phase 1 — Ash Resources + Migration
- [x] `EvidencePattern` resource (`backend/lib/sertantai_legal/legal/evidence_pattern.ex`) — keyed on `(law_name, control_id)`, 1:1 with controls
- [x] `ArtefactTemplate` resource (`backend/lib/sertantai_legal/legal/artefact_template.ex`) — child table, unpacked from `artefacts_json`
- [x] Generate migration (`20260716135644_add_evidence_patterns.exs`) + added law_name index
- [x] Register in `api.ex`

### Phase 2 — Zenoh Subscriber
- [x] `EvidenceSubscriber` (`backend/lib/sertantai_legal/zenoh/evidence_subscriber.ex`) — subscribe to `fractalaw/@{tenant}/evidence/**`
- [x] Decode Arrow IPC, upsert evidence patterns, unpack `artefacts_json` into artefact_templates
- [x] No Postgres FK needed — `(law_name, control_id)` as strings, resolution at query/sync time
- [x] Register in Zenoh supervisor (after ControlsSubscriber)
- [x] Add to ZenohController admin dashboard + frontend Zenoh page (Evidence tab)

### Phase 3 — Baserow Sync
- [x] Add `:evidence_patterns` and `:artefact_templates` to `SourceType` enum
- [x] Add field specs + format functions to Baserow provider (`evidence_patterns_field_specs`, `artefact_templates_field_specs`, format functions)
- [x] Add `table_id` clauses to `Baserow.Client` for both new table types
- [x] Add `maybe_sync_evidence_patterns` and `maybe_sync_artefact_templates` to engine
- [x] Customer scoping: same duty filter as controls (via control_id → control's linked_provisions → candidate_duties)
- [x] Wire into `execute_sync` chain (after control_mappings), `build_provider_config`, and `clean` table list

## Design decisions
- Evidence patterns are **shared reference data** (no org_id), like Controls — customer scoping at sync time
- `ArtefactTemplate` = fractalaw-generated template; existing `artefacts.ex` Baserow template = customer's operational table they fill from these templates
- Plain strings for constrained fields (no Ash enums) — same rationale as Controls
- FK to controls: **no Postgres FK**. Key on `(law_name, control_id)` as strings — same identity as Controls. 1:1 logical relationship, resolution at query/sync time. Evidence can arrive in any order.

## Key files (Controls pattern reference)
- Resource: `backend/lib/sertantai_legal/legal/control.ex` (identity, upsert action, by_law_name(s) reads)
- Child: `backend/lib/sertantai_legal/legal/control_mapping.ex` (belongs_to, upsert identity)
- Subscriber: `backend/lib/sertantai_legal/zenoh/controls_subscriber.ex` (@field_atoms whitelist, Arrow decode, rebuild_mappings)
- Migration: `backend/priv/repo/migrations/20260713154111_add_controls.exs`
- Sync engine: `backend/lib/sertantai_legal/sync/engine.ex:534-656` (maybe_sync_controls, candidate_duties scoping)
- Baserow format: `backend/lib/sertantai_legal/sync/providers/baserow.ex:333-428`
- Domain: `backend/lib/sertantai_legal/api.ex:36-37`
- Supervisor: `backend/lib/sertantai_legal/zenoh/supervisor.ex:27`

## Corpus Stats

### Postgres (full corpus)
- 1,333 evidence patterns across 220 laws
- 4,532 artefact templates (avg 3.4 per pattern)
- 89% control coverage (1,333 of 1,499 non-predicate controls)

### Baserow QQ Sync (customer-scoped)
- 1,126 evidence patterns (of 1,333 — 207 filtered by duty scoping)
- 3,851 artefact templates
- Tables: Evidence Patterns (1082800), Artefact Templates (1082801)

## Notes
- No GitHub issue
- #124 raised: mix tasks for Baserow build should use running server instead
