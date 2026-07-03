# Title: Mix Task for Baserow Template Management

**Started**: 2026-07-03
**Status**: ACTIVE

## Problem
Each template application currently requires a fresh `mix run -e` which:
- Starts a new BEAM (slow, Zenoh port conflicts)
- Needs manual JWT auth + database_id resolution each time
- Loses state (created table IDs) between calls
- Error-prone and not repeatable

## Todo
- [ ] Create `mix templates.apply` — single task that authenticates once, resolves database_id, applies templates in order
- [ ] Accept `--config UUID`, `--templates personnel,compliance_assessment`, `--people linked` etc.
- [ ] Persist created table IDs back to sync_configurations.target_config
- [ ] Handle existing tables (idempotent — skip if already exists)
- [ ] Handle Baserow default columns (Name, Notes, Active) that auto-create with new tables
- [ ] Delete Notes default column after table creation
- [ ] Rename/repurpose Name primary field (can't be deleted)
- [ ] Handle Active field collision (template vs Baserow default)
- [ ] Add Collaborator field to Personnel table
- [ ] Create `mix templates.list` — show available templates and current state
- [ ] Create `mix templates.destroy` — tear down template tables (with confirmation)

## Notes
- Applicator already handles idempotency and dependency resolution
- Need to resolve database_id from existing table IDs (one API call)
- Table IDs should persist in sync_configurations.target_config so `mix sync.run` can reference them
- Consider running from the Phoenix server context to avoid Zenoh conflicts
