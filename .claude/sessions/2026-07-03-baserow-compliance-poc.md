# Title: Baserow Compliance PoC — Solution Design

**Started**: 2026-07-03
**Status**: SUSPENDED

## Todo — Completed
- [x] Review previous template work (Phase 3-7 sessions from June)
- [x] Research Baserow Collaborators field, SSO, Teams, RBAC
- [x] Document Personnel patterns (`docs/BASEROW-PERSONNEL-PATTERNS.md`)
- [x] Personnel template extension (4 people modes, :workspace_member rename)
- [x] Apply Personnel template to QQ Baserow (linked mode, Employee_ID primary)
- [x] Apply Compliance Assessment template (formula primary: field('Law'))
- [x] Apply Action Tracker template (formula primary needs manual fix)
- [x] 7-Layer architecture mapping (`docs/BASEROW-7-LAYERS.md`)
- [x] L3 Controls design with ontology (`docs/BASEROW-CONTROLS-DESIGN.md`)
- [x] Hierarchy table design (adjacency list, multi-hierarchy)
- [x] Control Mapping design (lean join: Law + Obligation + Control + Strength)
- [x] Schema doc (`docs/BASEROW-SCHEMA.md`)
- [x] Commit and push docs

## Todo — When Resumed

### Build new templates
- [x] Build Hierarchy template (adjacency list: Name, Hierarchy, Type, Parent, Description)
- [x] Build Controls template (Properties/Methods/Events/Distance ontology, Org_Unit + Location links to Hierarchy)
- [x] Build Control Mappings template (Law + Obligation + Control + Strength)
- [x] Update Action Tracker template: add Control link_row field
- [x] Update Evidence Vault template: add Control link_row field

### Apply to QQ Baserow
- [x] Apply Hierarchy template (table 1060575, no seed this session)
- [x] Apply Controls template (table 1060576)
- [x] Apply Control Mappings template (table 1060577)
- [x] Re-apply Action Tracker with Control link (Control field added to existing table 1059861)
- [x] Validate end-to-end: LRT → Control Mappings → Controls → Actions (9 tables, all links verified)

### L4 Evidence — DONE (child sessions)
- [x] Apply Evidence Vault (superseded by Artefacts/Judgements/Gaps — see evidence-calibration-tier + evidence-schema-baserow sessions)
- [x] Apply Incident Register (table 1065051, with Judgement + Control falsification links)

### L5 Assurance — the seam
L5 is an interface (seam), not an audit management system. The assurance programme lives in the organisation's own tools. The compliance framework provides inputs, access, and a receiver for findings. See `docs/compliance/l5-assurance/ASSURANCE-INTERFACE.md`.

- [x] Research assurance patterns (1st/2nd/3rd line, defence, ISO 19011, IIA Three Lines) → `docs/compliance/l5-assurance/ASSURANCE-PATTERNS.md`
- [x] Design the assurance interface (3 flows: out/access/back) → `docs/compliance/l5-assurance/ASSURANCE-INTERFACE.md`
- [x] Distinguish L5 from L4 (L4 = first-line judgement; L5 = independent verification via the seam)
- [x] Extend Artefacts canonical schema: `assurance_ref`, `assurance_line`, `assurance_rating`, `source_activity_type` + enums
- [x] Extend Artefacts template with assurance fields (always present, nullable) + "Assurance Findings" view
- [ ] Define standard queries/reports for assurance planning (controls by VoI, coverage gaps, judgement quality)
- [x] Apply updated Artefacts template to QQ Baserow (4 new fields added to existing table)

### L6 Events & Change Intelligence — the interface
L6 is an interface for internal and external events, not the event generator. The compliance framework receives event signals; generating them (horizon scanning, market sensing, regulatory monitoring) is a separate concern.

- [x] Research events patterns → `docs/compliance/l6-events/EVENTS-PATTERNS.md`
- [x] Design events schema (Compliance Events entity, lifecycle, impact mapping, LRT signal sources) → `docs/compliance/l6-events/EVENTS-SCHEMA.md`
- [x] Build Compliance Events template (21 fields: event_type, event_source, signal_source/ref, urgency, triage/response status, impact links, owner)
- [x] Add 7 views: All Events, Open Events, Material Events, By Type, By Urgency (kanban), Event Board (lifecycle kanban), Monitoring
- [x] Register template (19 total), update mix task, update test count (65 pass)
- [x] Apply to QQ Baserow (table 1065389, 20 fields created)
- [ ] Validate: fractalaw ChangeDetector → Event creation pathway (existing Zenoh signals → new L6 records)

### L7 Decisions & Governance — the meta-layer
L7 governs the compliance framework itself. Six functions: policy, risk appetite, management review, senior reporting, accountability, decision provenance. Interface pattern — governance uses its own tools, compliance framework provides data and receives decisions.

- [x] Research governance patterns → `docs/compliance/l7-governance/GOVERNANCE-PATTERNS.md`
- [x] Determine L7 schema → `docs/compliance/l7-governance/GOVERNANCE-SCHEMA.md`
  - One entity: Governance Parameters (key-value with provenance, version-controlled by supersession)
  - Decisions entity repositioned from L4 to L7 (deferred — governance decisions in external tools for now)
  - Policy documents are Artefacts (artefact_type = Policy)
  - Accountability = governance_role field on Personnel
  - Reports = projections/views on L1–L6 data, not persisted
- [ ] Build Governance Parameters template
- [ ] Add governance_role field to Personnel template
- [ ] Apply to QQ Baserow

### Remaining templates
- [ ] Apply Document Control
- [ ] Apply PDCA
- [ ] Review Training Tracker — is it L5 (competence assurance) or L3/L4 (training records)? Likely split.

## Key Design Decisions Made

1. **Control Mapping is a lean join** — 4 fields: Law, Obligation (optional), Control, Strength (Primary/Supporting/Ancillary). No status, justification, or inheritance metadata.
2. **Two-tier obligation mapping** — Law field always populated (coarse), Obligation field optional (provision-level for targeted controls).
3. **Hierarchy as adjacency list** — single table, self-referential Parent, multi-hierarchy via Hierarchy field (org/geo/finance). Replaces chained Sites/Divisions tables.
4. **Controls carry organisational context** — two link_row fields to Hierarchy (Org_Unit, Location). Not on the mapping.
5. **Actions target Controls** — you can only change compliance by changing controls. Actions fix/improve/create controls.
6. **Two assessments coexist** — Compliance Assessment (L2, per law, human judgement) and Control Effectiveness (L5, per control, tested via audits). A broken control ≠ automatic non-compliance (redundancy).
7. **Control ontology** — Properties (type, nature, domain, owner, tier), Methods (consequence/exposure/likelihood, blast radius), Events (frequency, demand mode), Distance (Westrum information distance).
8. **DRY via hierarchy** — inheritance implied by tree position, not duplicate records. Corporate control visible at all tiers without re-mapping.
9. **Primary fields are descriptive formulas** — for link_row dropdown display. No UUID needed (row_id() exists if needed).
10. **Evidence has two natures: Artifact and Judgement** — Artifacts prove the *form* (document exists, log recorded). Judgements prove the *substance* (named person's assessed conclusion with basis, reasoning, confidence). A vault full of artifacts with no judgements has the legible boxes ticked but the load-bearing reality unwatched. Driven by the operationalisation paradox (Rae & Provan 2018, Hubbard 2007).

## Docs Created
- `docs/BASEROW-7-LAYERS.md` — layer status mapping
- `docs/BASEROW-CONTROLS-DESIGN.md` — L3 detailed design
- `docs/BASEROW-SCHEMA.md` — full workspace table relationships
- `docs/BASEROW-TEMPLATES.md` — template module reference
- `docs/BASEROW-COMPLIANCE-ASSESSMENT-PATTERNS.md` — assessment options
- `docs/BASEROW-ACTION-TRACKER-PATTERNS.md` — action tracker options
- `docs/BASEROW-PERSONNEL-PATTERNS.md` — personnel people modes
- `docs/BASEROW-CONFIG-RECIPES.md` — manual Baserow UI configuration
- `docs/EVIDENCE-VAULT-PATTERNS.md` — L4 evidence design, operationalisation paradox, control-driven evidence strategy
- `docs/reviews/2026-07-03-gemini-baserow-template-architecture.md` — Gemini architecture review

## Known Issues
- Action primary field created as text not formula on second run (cleanup skipped for existing tables)
- Cross-table rollups deferred (Baserow auto-names reverse link fields — Phase 2 #112)
- Schema updates to existing tables need reconciliation (Phase 2 #112)
- Baserow and() only takes 2 args (fixed with nested and())
