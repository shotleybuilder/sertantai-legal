---
session: "DRRP over time: as made vs as amended (fractalatai #73)"
status: pending
opened: 2026-09-30
related: ["fractalatai#73", "fractalatai#68"]
depends_on: ["drrp/2026-09-30-drrp-spec-68"]
---

# Session: DRRP over time, legal side (PENDING)

Proposal: fractalaw `docs/architecture/DRRP-TEMPORAL-PROPOSAL.md` (draft; legal and Gemini reviews to be combined before any decision). Jason: review first, build nothing yet.

## Problem

"What are my obligations?" should need no status filter, while is_making keeps the 2026-09-28 ruling (revocation never un-makes a law). One classification per provision can't answer both.

## Legal's review (sent 2026-09-30)

- **Hard requirement:** `making_enrichment_verdict` = as_made (feeds is_making); a new `current_verdict` = as_amended, with a distinct `revoked` value. Otherwise every revoked Making law flips is_making.
- **Q1:** legal adds per-row `status` (in_force | repealed | prospective). Today LatParser marks some repealed rows `[Repealed]`/`[Revoked]` (544) and leaves 7,675 dotted rows; repealed can be backfilled, prospective needs a re-parse (CLML `Status="Prospective"`).
- **Q2:** as_made at law level only for now.
- **Q4:** `/body/made/data.xml` works (tested: UK_uksi_2012_3030, 151 KB, full text). Only amended laws (800 of 1,069 LAT laws) + laws first loaded after revocation; separate `legal_articles_made` table.
- **Q5–Q7:** prospective → none; extent is a query filter; point-in-time deferred; measure cost on a sample first.

## Legal's review of section L, the LAT change contract (2026-10-01)

fractalaw added section L (6c2ef8f): per-row `status`, `effective_from`, `changed_by`; per-law `amended`, `as_of`, `effects_unapplied`; per-change `cause`. Gemini's harsh review: `fractalaw/data/code-review/drrp-temporal-section-L-gemini.md`. Legal's answers (sent):
- **cause** per re-parse operation, not guessed: source CLML unchanged → parser; LatScope → scope; fix tasks → correction; source changed → legislative only with a new note or status change, else `unattributed` (overwrite + review, never versioned). The rename log shows churn is mostly parser-driven (19,309 dropped, 1,879 extent_tag, 363 unique_text), so defaulting unknown to legislative was wrong (Gemini right).
- **effective_from / changed_by** from `amendment_annotations` (58,751 amendment notes: 82% dated, 95% cite the instrument). A pure note parser; compound dates (2,644 partial commencements) → date list + `in_force_partial`.
- **effects_unapplied**: from the changes feed's `applied` flag, already used by LiveStatus (669 laws revoked_unapplied). Target → section_id mapping is best-effort.
- **Lifecycle:** 238 renumbered notes → legislative renames; 51 Part/Schedule substitutions → shared `change_id` (hash of law + normalised note, not the F-number); extent versions are already separate rows (2,753 in 49 laws); 0 revival notes.
- **Ordering:** no replay needed (legislation.gov.uk consolidates), but versions follow observation order; `effective_from` is an attribute only.
- **Dependents:** reuse legal's definition graph (legislative_definitions + definition_link); cap at same-law uses plus explicit cross-refs.

## Data

- Dotted rows: 7,660 in 474 laws. Only 98 rows in 6 laws are fully revoked laws; 6,405 are in part-repealed laws and 1,156 in in-force laws (repealed provisions: exclude, don't recover).
- UK_uksi_2012_3030 is the known exception until as_made exists.

## Todo

- ⬜ (Jason) Decide the proposal after both reviews
- ⬜ (legal) Per-row `status` on legal_articles (in_force / repealed / prospective / in_force_partial; backfill repealed; prospective on re-parse)
- ⬜ (legal) Structured note parser: effective_dates, changed_by, effect, change_id (pure module, TDD)
- ⬜ (legal) `source_hash` + `md_dct_valid_date` on parsed lat_events → cause per operation
- ⬜ (legal) Manifest: `amended`, `as_of`, `effects_unapplied`; a change log (cause, change_id) beside the rename log
- ⬜ (Jason) D1–D4 in section L
- ⬜ (fractalaw) Dotted-text rule: dotted provisions not substantive; all-dots law → no verdict (pending Jason)
- ⬜ (legal) Verdict split fields, after the spec
- ⬜ (legal) Made text for amended laws, after the cost sample
