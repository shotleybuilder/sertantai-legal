---
session: Production Hardening and Integration
status: pending
opened: '2026-11-07'
depends_on: ["lat-change-pipeline/2026-11-07-maritime-safety-retrospective"]
---

# Session: Production Hardening and Integration (PENDING)

## Problem

The LAT Change Pipeline is still dev work: it runs by hand, one family at a time, on the local database. Once the third family (Environmental Protection) is switched, the pipeline should be made production hardened, and its labels should reach sertantai-compliance and fractalaw (Jason, 2026-11-07). This is a placeholder for that work. It isn't scoped yet: the scope is planned in plan mode once Family 3's retrospective has reported.

## Todo

Live items carried from the three meta sessions closed as superseded on 2026-11-07 (LAT hand-off, LAT parser refactor, Pipeline to v0.1). Plan these when this session opens:

- ⬜ Plan the scope in plan mode after Family 3's retrospective
- ⬜ The label contract: the delta sync carries `lat_label_timeline` in place of `lat.status`, `effective_from` and `changed_by` (from LAT hand-off LH-05 / v0.1 D2), plus the one message to fractalaw (#167, #168)
- ⬜ sertantai-compliance reads the switched labels (its screening and browse)
- ⬜ Welsh SI duplicates (#178): one record per instrument, compliance checked
- ⬜ Production data: the partition migration (#133) and the prod data sync (#27), each step with Jason's approval
- ⬜ v0.1 sign-off (Jason)
- ⬜ Backups as operations: a retention rule for NAS restore points and snapshots (2026-11-07: the October restore points deleted, the November ones kept)
- ⬜ A retrospective over all the sessions' frontmatter (decisions, lessons, bugs) across the LAT threads (Pipeline to v0.1 backpocket, Jason 2026-10-21)

## Dependencies

- ⬜ Family 3 (Environmental Protection) switched, and its retrospective closed
- ⬜ Before Family 3: the Mines Regulations 2014 repeals-table fault, then #192, then #191
