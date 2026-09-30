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

## Data

- Dotted rows: 7,660 in 474 laws. Only 98 rows in 6 laws are fully revoked laws; 6,405 are in part-repealed laws and 1,156 in in-force laws (repealed provisions: exclude, don't recover).
- UK_uksi_2012_3030 is the known exception until as_made exists.

## Todo

- ⬜ (Jason) Decide the proposal after both reviews
- ⬜ (legal) Per-row `status` on legal_articles (backfill repealed; prospective on re-parse)
- ⬜ (fractalaw) Dotted-text rule: dotted provisions not substantive; all-dots law → no verdict (pending Jason)
- ⬜ (legal) Verdict split fields, after the spec
- ⬜ (legal) Made text for amended laws, after the cost sample
