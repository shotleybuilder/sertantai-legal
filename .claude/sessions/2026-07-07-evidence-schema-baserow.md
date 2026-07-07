---
session: Evidence schema position built for Baserow
project: sertantai-legal
status: closed
opened: 2026-07-07
closed: 2026-07-07
outcome: success
commits: [cc1c944, 49e0801]

summary: >
  Built three new L4 Baserow templates (Artefacts, Judgements, Gaps) from the canonical
  EVIDENCE-SCHEMA.md. Updated four existing templates (Personnel, Controls, Action Tracker,
  Incidents) with calibrator quality, coverage scheduling, gap links, and falsification.
  18 templates total, applied to QQ Baserow (14 tables).

decisions:
  - what: Artefacts replaces Evidence Vault as the artifact register
    why: Renamed to avoid overloading "evidence" (tier name = table name). Judgement fields stripped out to Judgements table.
    result: 14 fields basic, +2 with safety_argument. Clean separation of things (artefacts) from acts (judgements).
  - what: Two new sub-pattern dimensions added (calibration_mode, safety_argument)
    why: Confidence fields, calibrator quality, and safety argument legs should only surface when the customer needs them. Schema-first, projection adapts.
    result: calibration_mode :basic/:calibrator_aware/:full_hubbard. safety_argument :off/:on. Basic mode hides all advanced fields.
  - what: Controls extended with coverage_status and audited override scheduling
    why: fractalaw needs fields to write computed coverage state and recommended intervals. Humans need override with documented reason.
    result: 4 new fields on Controls (Coverage_Status, Recommended_Next_Due, Scheduled_Next_Due, Next_Due_Override_Reason)

metrics:
  templates_total: { count: 18 }
  new_templates: { count: 3, names: "artefacts, judgements, gaps" }
  updated_templates: { count: 4, names: "personnel, controls, action_tracker, incident_register" }
  qq_baserow_tables: { count: 14 }
  fields_created_in_baserow: { count: 51 }

lessons:
  - title: Schema-first design prevents Baserow limitations from warping the model
    detail: L4 was designed as a canonical schema first (EVIDENCE-SCHEMA.md), then projected onto Baserow. This meant the Artefact/Judgement/Gap separation was clean before touching template code. Previous L1-L3 templates were designed for Baserow and will need canonical schemas extracted later.
    tag: schema
  - title: Sub-patterns scale well for feature gating
    detail: calibration_mode and safety_argument sub-patterns follow the established pattern (people, storage_mode, risk_scoring). Templates conditionally include fields based on the mode. Basic customers see 11 Judgement fields; full_hubbard customers see 17. No code duplication — just conditional field lists.
    tag: baserow
  - title: Existing tables accept new fields idempotently
    detail: Re-applying templates to existing QQ tables (Controls, Action Tracker) correctly skipped existing fields and added only the new ones (Coverage_Status, Gap link, etc.). The applicator's field-name-based idempotency check works reliably.
    tag: baserow

artifacts:
  - backend/lib/sertantai_legal/sync/templates/artefacts.ex
  - backend/lib/sertantai_legal/sync/templates/judgements.ex
  - backend/lib/sertantai_legal/sync/templates/gaps.ex
  - backend/lib/sertantai_legal/sync/templates/sub_patterns.ex
  - backend/lib/sertantai_legal/sync/templates/personnel.ex
  - backend/lib/sertantai_legal/sync/templates/controls.ex
  - backend/lib/sertantai_legal/sync/templates/action_tracker.ex
  - backend/lib/sertantai_legal/sync/templates/incident_register.ex
  - backend/lib/sertantai_legal/sync/templates/registry.ex
  - backend/lib/mix/tasks/templates.apply.ex

depends_on:
  - 2026-07-05-evidence-calibration-tier.md
  - 2026-07-03-baserow-compliance-poc.md

enables:
  - fractalaw calibration signal app (Phase 3 of evidence-calibration-tier)
  - Calibration workflow design (Phase 4)
  - QQ user testing of the Artefacts → Judgements → Gaps workflow
---

# Title: Evidence schema position built for Baserow

**Started**: 2026-07-07
**Status**: CLOSED

## Context

Canonical L4 schema defined in `docs/compliance/l4-evidence/EVIDENCE-SCHEMA.md`. Three entities to build as Baserow templates: Artefacts, Judgements, Gaps. Plus extensions to Personnel (calibrator quality), Controls (coverage/scheduling), Action Tracker (gap links), and Incidents (falsification).

Parent session: `2026-07-05-evidence-calibration-tier.md` (ACTIVE, Phase 2)

## Todo
- [x] Build Artefacts template (14 fields basic, +2 safety_argument)
- [x] Build Judgements template (11 fields basic, +6 full_hubbard + safety_argument)
- [x] Build Gaps template (11 fields, three exits)
- [x] Build judgement_artefacts join (link_row Artefacts_Relied_On, full_hubbard only)
- [x] Update Personnel template (calibrator fields when calibration_mode :calibrator_aware/:full_hubbard)
- [x] Update Controls template (Coverage_Status, Recommended/Scheduled_Next_Due, Override_Reason)
- [x] Update Action Tracker (Gap link_row)
- [x] Update Incidents (Judgement + Control link_rows for falsification)
- [x] Register 3 new templates (18 total), update mix task (table_ids + CLI opts), update test count
- [x] Add calibration_mode + safety_argument to SubPatterns
- [x] Apply to QQ Baserow (Artefacts 1064911, Judgements 1064910, Gaps 1064913, Incidents 1065051, Controls + Actions updated)
- [x] Validate end-to-end: 14 tables, all link_rows verified

## Notes
- Schema source of truth: `docs/compliance/l4-evidence/EVIDENCE-SCHEMA.md`
- Sub-patterns: calibration_mode (:basic/:calibrator_aware/:full_hubbard), safety_argument (:off/:on)
- Terminology: `EVIDENCE-CALIBRATION.md` — judgement vs calibration vs drift
