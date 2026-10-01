---
session: "Issue #172: law-level purpose from fractalaw's purpose profile"
status: pending
opened: 2026-10-01
issue: 172
related: ["fractalatai#73"]
---

# Session: #172 purpose profile, legal build (PENDING)

Jason confirmed on 2026-10-01: fractalaw publishes a purpose profile per law (each purpose's count and share of the law's provisions). Legal stores it, derives the `purpose` multi-select from it, and retires its own law-level classifier. Background: legal's `PurposeClassifier` runs over the whole law's text, so any substantial law gets nearly every label. Fractalaw's provision-level vocabulary changes (PURPOSE-CLASSIFICATION.md).

## Agreed with fractalaw and compliance (2026-10-01)

- **New column `legal_register.purpose_profile`:** `[{purpose, count, share}]`, sorted by count. `[]` clears; null/absent = not in this payload.
- **`purpose` stays `{values: [labels]}`** (compliance's browser sync, Browse UI and Baserow all read it). Legal derives it at ingest: share ≥ 0.05, never `Unclassified`, in profile order.
- **Base: whole law.** Inserted text (#57) is excluded; amendment instructions count as `Amendment`.
- **Fallback (legal's default; Jason may revisit):** unprofiled laws keep their current values. Retire the PurposeClassifier run in TaxaParser, so new scrapes get no purpose until fractalaw profiles them.
- Compliance gets a per-law old→new change list from fractalaw's final dry run. There's no 1:1 mapping because Process+Rule splits per provision.

## Todo

- ⬜ Migration: `purpose_profile` jsonb on legal_register (dev-only for delta sync until #133)
- ⬜ TaxaSubscriber: map `purpose_profile`; derive `purpose` (tests: threshold, Unclassified excluded, [] clears, absent keeps)
- ⬜ Retire the law-level PurposeClassifier step in TaxaParser/StagedParser (check the admin UI's parse review)
- ⬜ Docs (ZENOH-SPEC), restart with heads-up (no publish expected before the single run)
- ⬜ Before the single publish: send compliance fractalaw's per-law purpose change list from the final dry run (compliance#38, v0.2: Baserow rows with retired labels). Compliance asked for it to be linked on #38; check with Jason first (no-GH-posts preference)
- ⬜ Verify after the single publish
