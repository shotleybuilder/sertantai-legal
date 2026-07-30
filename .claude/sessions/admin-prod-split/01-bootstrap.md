---
session: Bootstrap Compliance Repo
status: closed
opened: 2026-07-30
closed: 2026-07-30
outcome: success

summary: >
  Bootstrapped sertantai-compliance from empty scaffold to working app with auth infrastructure
  (JwksClient, AuthPlug, LoadFromCookie), 10 read-only Ash resources for reference data (462K+
  rows), and shared database connection to sertantai_legal_dev. Compiles cleanly, JWKS fetches
  successfully, health endpoint confirms DB connectivity.

decisions:
  - what: "Compliance dev shares sertantai_legal_dev — no separate compliance dev database"
    why: "Single developer, same machine. Org-scoped tables already exist in legal_dev. A separate DB would require delta sync locally for zero benefit."
    result: "dev.exs points at port 5436 / sertantai_legal_dev. No docker-compose needed for dev."
  - what: "Defer Electric config to Phase 3 (frontend move)"
    why: "Electric is only needed when the frontend moves. Compliance backend can operate without it."
    result: "One less moving part in bootstrap. Legal's Electric on port 3002 available if needed."
  - what: "Use :atom with constraints instead of custom Ash enum types for reference resources"
    why: "Read-only mirrors don't need full enum module definitions. Inline constraints are simpler and avoid cross-repo type dependencies."
    result: "10 resources with clean inline enum constraints, no shared type modules needed"

metrics:
  reference_tables: { count: 10, total_rows: 462868 }
  rows_by_table: { legal_register: 20696, legal_articles: 306840, amendment_annotations: 74447, controls: 4274, control_mappings: 4092, evidence_patterns: 1333, artefact_templates: 4532, secondary_sources: 228, secondary_source_provisions: 46101, source_links: 325 }
  files_created: { auth: 3, resources: 10, total: 13 }

lessons:
  - title: "Scaffold HelloController had copy-paste artifact from sertantai-controls"
    detail: "The greeting said 'Hello from Sertantai Controls API!' — always check scaffold output for copy-paste artifacts from the source template."
    tag: tooling
  - title: "Org-scoped migrations are a non-issue when sharing the dev database"
    detail: "Originally planned as a separate todo (extract + replay migrations). Since compliance dev points at legal_dev, all tables already exist. Migration porting is only needed for production (Phase 5)."
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_compliance/auth/jwks_client.ex
  - backend/lib/sertantai_compliance_web/plugs/auth_plug.ex
  - backend/lib/sertantai_compliance_web/plugs/load_from_cookie.ex
  - backend/lib/sertantai_compliance/legal/legal_register.ex
  - backend/lib/sertantai_compliance/legal/legal_article.ex
  - backend/lib/sertantai_compliance/legal/amendment_annotation.ex
  - backend/lib/sertantai_compliance/legal/control.ex
  - backend/lib/sertantai_compliance/legal/control_mapping.ex
  - backend/lib/sertantai_compliance/legal/evidence_pattern.ex
  - backend/lib/sertantai_compliance/legal/artefact_template.ex
  - backend/lib/sertantai_compliance/legal/secondary_source.ex
  - backend/lib/sertantai_compliance/legal/secondary_source_provision.ex
  - backend/lib/sertantai_compliance/legal/source_link.ex

depends_on:
  - meta.md

enables:
  - "Phase 2: Move customer backend (screening, sync, webhooks)"
---

# Session: Bootstrap Compliance Repo (CLOSED)

## Problem

sertantai-compliance is a pure scaffold (2 commits, zero domain code). It needs auth infrastructure, read-only Ash resources for legal reference data, org-scoped migrations, and an Electric config before customer-facing code can move in. Dev mode points at `sertantai_legal_dev` — no separate compliance database.

## Todo

- ✅ Strip scaffold boilerplate (renamed "Starter App"/"Controls" strings, removed placeholder User/Organization resources)
- ✅ Port auth infrastructure from legal: JwksClient, AuthPlug, LoadFromCookie
- ✅ Configure dev.exs to connect to sertantai_legal_dev (port 5436)
- ✅ Add jose + req deps to mix.exs, JwksClient to supervision tree
- ✅ Health endpoint returns OK with DB connection confirmed, JWKS fetched
- ✅ Define read-only Ash resources for reference data (10 resources: LegalRegister, LegalArticle, AmendmentAnnotation, Control, ControlMapping, EvidencePattern, ArtefactTemplate, SecondarySource, SecondarySourceProvision, SourceLink)
- ✅ Org-scoped tables already exist in legal_dev (shared DB) — no migration porting needed for dev. Tables: org_applicabilities, org_screening_profiles, org_entitlements, sync_profiles, sync_configurations, sync_jobs, sync_row_mappings, org_secondary_applicabilities, organizations
- ⏸️ (Phase 5) Create standalone migrations for compliance_prod
- ⏸️ Configure Electric instance (deferred — compliance dev uses legal's Electric on port 3002 for now. Own Electric instance needed when frontend moves in Phase 3)

## Dependencies

- ✅ Split plan written and reviewed: .claude/plans/admin-prod-split.md
- ✅ Meta tracker: admin-prod-split/meta.md
- ✅ sertantai-compliance repo accessible at ~/Desktop/sertantai-compliance
