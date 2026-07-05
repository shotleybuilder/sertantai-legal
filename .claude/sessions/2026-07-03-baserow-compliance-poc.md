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

### Remaining templates
- [x] Apply Evidence Vault (table 1061002, with Artifact/Judgement nature, judgement fields)
- [ ] Apply Incident Register
- [ ] Apply Audit Management
- [ ] Apply Training Tracker

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
