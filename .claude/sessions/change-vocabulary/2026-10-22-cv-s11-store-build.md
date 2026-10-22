---
session: 'CV-S11: Store and Build'
status: pending
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S11: Store and Build (PENDING)

## Problem

Step 11 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Repeatable, fast enough, and it shows what is stale.

The session does not close until its results pass.

## Todo

- ⬜ Define what good looks like (the acceptance check): a hand-checked sample from the OH&S core family, and the measures, each defined in words with a test
- ⬜ Build the acceptance check; run it (ask Jason before any long run)
- ⬜ Same input gives the same output (rebuild twice, diff)
- ⬜ Speed: cache each law's parsed markup facts and feed effects, keyed by the stored document's version (CV-07)
- ⬜ `mix lat.vocabulary --check` / `--family` (CV-07 `83e15ae7`, fixed `41f9afe0`) proven
- ⬜ Staleness: `changes_built` events and code versions shown per law (LabelStaleness learns :changes_version at the switch-over)
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ⬜ The steps before it passed (CV-00 order)

## What good looks like

To be defined at the session's start.
