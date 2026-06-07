# Title: Compliance Templates — Phase 1: Provider-Agnostic Infrastructure

**Started**: 2026-06-07 13:00
**Plan**: .claude/plans/baserow-compliance-templates.md (Round 3)

## Todo
- [ ] Universal field type system + sub-pattern config struct
- [ ] TemplateBehaviour behaviour module (field_specs/view_specs take sub_patterns)
- [ ] Extended ProviderBehaviour (create_table, create_field, create_view, create_webhook, capabilities)
- [ ] Template registry with dependency resolution
- [ ] TemplateApplicator — idempotent orchestration, capability checking

## Notes
- This session: infrastructure only, no templates yet
- Three layers: Template Definition → Provider Adapter → Provider API
- 9 sub-pattern dimensions
- Plan through 3 Gemini review rounds

## Future Sessions

### Phase 2: Baserow Adapter
- Implement new ProviderBehaviour callbacks on existing Providers.Baserow
- Universal type → Baserow type mapping
- Baserow webhook payload → common event struct parser
- Refactor existing Engine.run to use template infrastructure

### Phase 3: First Templates (Foundation + Personnel + Assessment)
- Foundation template (refactor existing LRT/LAT sync into template pattern)
- Personnel template
- Compliance Assessment template with sub-pattern support
- Seed logic (one Assessment per law, linked to LRT)
- Rollups on LRT (assessment count, compliance %)

### Phase 4: Action Tracker + Evidence Vault
- Action Tracker template with kanban/calendar views
- Evidence Vault with storage_mode sub-pattern (file vs URL)
- Rollups on Assessments (open action count)

### Phase 5: Webhook Pipeline + Dashboard
- Webhook common event struct
- Receive provider webhooks, normalise to common struct
- Update compliance metrics in sertantai
- Surface in /app/stats dashboard

### Phase 6: Remaining Templates
- Incident Register, Audit Management, Training Tracker, Document Control
- RACI template (maps Hohfeldian actors to org roles)
- PDCA / Improvement Initiatives
- Org structure sub-patterns (Sites, Divisions tables)
