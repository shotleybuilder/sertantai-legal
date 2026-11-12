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
- ⬜ All the steps run as one process (Jason, 2026-11-12: "production hardening means running all steps as one process")
- ⬜ From Environmental Protection (its retrospective): Welsh SIs held twice or under UK names (two parked Register bugs, with #178); a scheduled run of the switched families' checks (`lat.stale --strict --switched`, golden, the checked rows); no task writing copies to `public` (lat.reparse, making.resolve); an incremental refresh of the laws legislation.gov.uk changes (fetch, read, build, refold, switch)
- ⬜ A retrospective over all the sessions' frontmatter (decisions, lessons, bugs) across the LAT threads (Pipeline to v0.1 backpocket, Jason 2026-10-21)

## Dependencies

- ✅ Family 3 (Environmental Protection) switched, and its retrospective closed (2026-11-12)
- ✅ Before Family 3: the Mines Regulations 2014 repeals-table fault, then #192, then #191
- ⬜ The review tooling, then a few QQ register families run one at a time with the backlog fixed, until the steps are reliable enough to run as one process (Environmental Protection retrospective, Decision 3)
