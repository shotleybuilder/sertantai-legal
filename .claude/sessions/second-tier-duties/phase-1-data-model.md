---
session: Phase 1 — Second-Tier Data Model & Manual Registration
project: sertantai-legal
status: closed
opened: 2026-07-15
closed: 2026-07-15
outcome: success
commits: [4221961]

summary: >
  Created 3 new Ash resources (SecondarySource, SourceLink, OrgSecondaryApplicability)
  with 6 enums, 4 migrations, and 3 mix tasks. Seeded 29 HSE ACoPs with parent law links.
  Extended OrgScreeningProfile with certifications and contract_requirements fields.

decisions:
  - what: SecondarySource in Api domain, OrgSecondaryApplicability in Sync domain
    why: Secondary sources are shared reference data (like laws); applicability is org-scoped (like OrgApplicability)
    result: Clean separation matching existing domain boundaries
  - what: Dedicated SecondaryApplicabilitySource enum (manual/inherited/screener) instead of reusing ApplicabilitySource
    why: Primary applicability has enhesa_import; secondary sources have inherited (from parent law)
    result: Each enum has only relevant values
  - what: Existing sector field on OrgScreeningProfile sufficient — added certifications + contract_requirements only
    why: Plan called for sectors array but OrgScreeningProfile already had it
    result: No duplicate field, 2 new arrays added

metrics:
  resources_created: 3
  enums_created: 6
  migrations: 4
  mix_tasks: 3
  acops_seeded: 29
  source_links_seeded: 30

lessons:
  - title: Ash.create requires explicit action name when no primary create action exists
    detail: "Ash.create(Resource, attrs) fails with 'Required primary create action'. Must pass action: :create when the create action isn't marked as primary via defaults."
    tag: schema
  - title: Ash.Query.filter needs require Ash.Query and variable binding outside the macro
    detail: "Can't use ^String.to_atom(x) inside Ash.Query.filter — must bind to a variable first (type_atom = String.to_atom(type)) then use ^type_atom in the filter expression."
    tag: schema

artifacts:
  - backend/lib/sertantai_legal/legal/secondary_source.ex
  - backend/lib/sertantai_legal/legal/source_link.ex
  - backend/lib/sertantai_legal/sync/org_secondary_applicability.ex
  - backend/lib/mix/tasks/secondary.seed_acops.ex

depends_on:
  - second-tier-duties/meta.md

enables:
  - Phase 2 provision parsing (secondary_source_provisions table)
  - Phase 4 Baserow sync (SecondarySourcesTemplate)
---

# Title: Phase 1 — Second-Tier Data Model & Manual Registration

**Started**: 2026-07-15
**Parent**: second-tier-duties/meta.md
**Plan**: `.claude/plans/second-tier-duties.md` (Phase 1 section)

## Todo
- [x] Create gitignored `data/secondary-sources/` directory for source PDFs
- [x] Create `SecondarySource` Ash resource + migration
- [x] Create `SourceLink` Ash resource + migration
- [x] Create `OrgSecondaryApplicability` Ash resource + migration
- [x] Add `certifications`, `contract_requirements` to `OrgScreeningProfile`
- [x] Mix task: `mix secondary.register`
- [x] Mix task: `mix secondary.list`
- [x] Seed ~30 HSE ACoPs with parent law links

## Notes
- Source PDFs (paywalled standards, JSPs) must never be committed
- `data/` already gitignored — use `data/secondary-sources/{acop,jsp,standard,guidance}/`
- OrgScreeningProfile already had `sector` field — no need for separate `sectors`
