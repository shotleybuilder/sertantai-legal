---
session: "AR-09: Territory of a Devolved Amending Law"
status: pending
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-09: Territory of a Devolved Amending Law (PENDING)

## Problem

An amending-law record carries no territory: a devolved instrument's change (nisr / ssi / wsi, nia / asp / anaw) reads as UK-wide — NI SR 2009/248 repealing Explosives Act 1875 ss.53–76 for NI only (AR-04 open bug; `Amendment.Collect`). The LabelProjection guard stops its false repeals; the dates still spread.

## Todo

- ⬜ Decide (Jason): the territory a devolved amending law's record carries — from the law's type, or the row's own extent
- ⬜ Record it on the amending-law record (`Amendment.Collect`); the projection reads it as it reads the feed's
- ⬜ Count the rows it changes; batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
