---
session: Action Status Rollups — Phase 5
project: sertantai-legal
status: closed
opened: 2026-07-20
closed: 2026-07-20
outcome: partial
commits: []

summary: >
  Built action count rollup chain (Actions → Assessments → LRT → Legal Register page)
  using formula 1/0 + sum rollup workaround for Baserow's missing filtered rollups.
  Integrated into template system. Unified page build script deferred to pending session.

decisions:
  - what: Formula 1/0 + sum rollup for filtered counts
    why: Baserow rollup fields don't support filters (community-confirmed limitation). Workaround is formula fields that return 1 or 0 based on status, then sum rollup counts the 1s.
    result: 3 formula fields on Actions, 3 rollups on Assessments, 3 lookups on LRT — clean chain

  - what: Integrate rollup fields into templates, not just scripts
    why: User insisted scripts create tech debt. Template definitions are the repeatable onboarding pipeline — fields must be there for mix templates.apply to create them.
    result: ActionTracker, ComplianceAssessment, Foundation templates all updated. SchemaManager handles :rollup in Phase 3.

metrics:
  formula_fields: 3
  rollup_fields: 3
  lookup_fields: 4
  tables_modified: 3

lessons:
  - title: Baserow rollups don't support filters — use formula 1/0 + sum workaround
    detail: >
      The rollup field's count function counts ALL linked rows. To count only rows
      matching a condition (e.g. Status=Open), create a formula field on the linked
      table returning 1 or 0, then use sum rollup on that formula. Community-confirmed
      pattern, not documented by Baserow.
    tag: baserow

  - title: Temp scripts become tech debt fast — integrate into templates immediately
    detail: >
      User caught that the rollup chain was only in ad-hoc scripts, not in the template
      system. Without integration, the next customer onboarding would require running
      undocumented scripts in the right order. Templates are the single source of truth.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/sync/templates/action_tracker.ex
  - backend/lib/sertantai_legal/sync/templates/compliance_assessment.ex
  - backend/lib/sertantai_legal/sync/templates/foundation.ex
  - backend/lib/sertantai_legal/baserow/schema_manager.ex
  - backend/scripts/build_action_rollups.exs
  - backend/scripts/add_actions_summary_column.exs

depends_on:
  - 2026-07-19-l1-legal-register.md
  - 2026-07-18-meta.md

enables:
  - 2026-07-20-build-pending.md (pending — unified page build)
---

# Action Status Rollups — Phase 5

**Started**: 2026-07-20 08:00
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Research: Baserow rollups DON'T support filters — use formula 1/0 + sum rollup workaround
- [x] Step 1a: Actions table — Is_Open (9637299), Is_Overdue (9637300), Is_Done (9637301)
- [x] Step 1b: Assessments table — Actions_Open (9637302), Actions_Overdue (9637304), Actions_Done (9637305) via sum rollup
- [x] Step 2: LRT table — Actions_Open (9637306), Actions_Overdue (9637307), Actions_Done (9637308) via lookup
- [x] Step 3: Legal Register page — Actions column: `✅ N | ⚠️ N | 🔵 N` (Done/Overdue/Open)
- [x] Re-published

Scripts (temp — need integrating):
- `scripts/build_action_rollups.exs` — creates the full chain (Steps 1-2)
- `scripts/add_actions_summary_column.exs` — adds the column to the Legal Register page (Step 3)

Integrate into repeatable build:
- [x] Add Is_Open, Is_Overdue, Is_Done formula fields to ActionTracker template
- [x] Add Actions_Open/Overdue/Done rollup fields to ComplianceAssessment template
- [x] Add Actions_Open/Overdue/Done + Assessment_Status lookup fields to Foundation (LRT) template
- [x] SchemaManager: add `:rollup` to Phase 3 deferred field types
- [ ] Integrate Legal Register page build into unified app build script (deferred → pending session `2026-07-20-build-pending.md`)
- [ ] Test full onboarding flow: templates.apply → seed → build app → publish (deferred → pending session)

## Approach
Baserow rollups can't filter. Workaround: formula fields on Actions that return 1 or 0
based on status, then sum rollup on Assessments gives the filtered count.

```
Actions table:
  Is_Open = if(field('Status') = 'Open' OR field('Status') = 'In Progress', 1, 0)
  Is_Overdue = if(field('Overdue') = 'OVERDUE', 1, 0)
  Is_Done = if(field('Status') = 'Completed', 1, 0)

Assessments table:
  Actions_Open = rollup(sum, Actions link, Is_Open)
  Actions_Overdue = rollup(sum, Actions link, Is_Overdue)
  Actions_Done = rollup(sum, Actions link, Is_Done)

LRT table:
  lookup(Assessments link, Actions_Open) → number
  lookup(Assessments link, Actions_Overdue) → number
  lookup(Assessments link, Actions_Done) → number
```

## Notes
- Actions statuses: Open, In Progress, Completed, Cancelled
- Actions Overdue: formula field already exists (9564846)
- Rollup sum on number formulas = filtered count
