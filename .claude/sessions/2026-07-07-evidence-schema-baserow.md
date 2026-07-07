# Title: Evidence schema position built for Baserow

**Started**: 2026-07-07
**Status**: ACTIVE

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
- [ ] Apply to QQ Baserow
- [ ] Validate end-to-end: Control → Artefact → Judgement → Gap → Action

## Notes
- Schema source of truth: `docs/compliance/l4-evidence/EVIDENCE-SCHEMA.md`
- Sub-patterns: calibration_mode (:basic/:calibrator_aware/:full_hubbard), safety_argument (:off/:on)
- Terminology: `EVIDENCE-CALIBRATION.md` — judgement vs calibration vs drift
