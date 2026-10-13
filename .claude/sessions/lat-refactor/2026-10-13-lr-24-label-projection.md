---
session: 'LR-24: Label Projection'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-24 Label Projection — When (ACTIVE)

## Problem

Row change labels (`effective_from`, `changed_by`, the change part of `status`, `change_provenance`) are computed inside the LAT parse (`ChangeFacts.row_facts`). LR-22 makes them a pure projection of `lat_change_log`. The rules: the row's own changes and its ancestors' whole-provision changes; the latest dated change; the authority order (law > derived data > auto-derived > editorial, never notes); each label linked to its change ids. Recomputed by `mix lat.relabel` without re-parsing LAT.

## Todo

- ✅ Measure first: rows whose `effective_from` today comes from a modification / application rather than a text change
- ⬜ Jason: what `effective_from` means (since when the current text has had effect; modifications excluded), what each operation contributes to status, and what whole-instrument effects (LR-23 D5) mean for a row (LR-22 Q2)
- ⬜ Golden test cases: rows with known change histories (effective_from, changed_by, status, change ids), scrubbed of `key-` ids
- ⬜ `LabelProjection` (pure) from change-log records; status contributions to `LatStatus` with no note text
- ⬜ `mix lat.relabel --laws|--all --dry-run`: offline diff against today's labels, classified (expected: effect labels equal; the 14,709 note-sourced labels empty)
- ⬜ Gap queries: rows with a note pointer and no change; changes with no date; changes resolving to no row
- ⬜ Gemini acceptance

## Decisions for Jason

- **R2 — Revision after Gemini (see "Gemini on labels as a query"):** the query is the truth; the existing label columns stay as a dated cache of "as at today" (refreshed daily and after each collect, stamped with the date and code version); the manifest hash includes the labels so fractalaw re-pulls when today's labels change; valid-time semantics; 'today' is the UK date. **Jason: approve R2**
- **R — Revision (proposed 2026-10-13, superseded by R2):** labels computed at query time from the register as at a date (default today), no stored labels; D1–D3 become the rules of that function; modifications shown through the register for v0.1; LR-25 reduced (no relabel wave). Gemini review, then Jason.
- **D1 — What `effective_from` means.** Superseded by R: as at T, the start of the provision's version in force at T (text changes and its own commencement; not modifications).
- **D2 — Whole-instrument effects.** Superseded by R: a commencement dates every row from its date; a repeal makes every row repealed from its date; a modification is shown like D1's.
- **D3 — Status.** Superseded by R: at T, only changes in force by T count (prospective = not yet in force at T; partly in force at T; repealed at T, savings → repealed_saved). No note text.

## Dependencies

- ✅ LR-23 table filled (closed 2026-10-13: 132,965 records, view `lat_change_log_rows` exact)
- ✅ LR-22 the two questions (where, when); authority order law > derived data > auto-derived > editorial

## Measure: what dates a row today (2026-10-13)

Every row with an `effective_from` (233,114). Its date and changed_by were matched to the register's changes on the row or its ancestors (`lat_change_log_rows`, excluding whole-instrument joins, which today's labels don't use). Scripts: scratchpad `lr24_measure.exs`, `lr24_nomatch.exs`.

| Today's label source | Dated by | Rows |
|---|---|---|
| effect | text change (substituted, inserted, repealed, renumbered, amended) | 107,721 |
| effect | commencement | 105,060 |
| effect | modification / application | **248** |
| effect | no matching change in the register | 8,716 |
| note | no matching change | 10,629 |
| note | commencement / text change / modification | 315 / 288 / 137 |

**Modifications barely date rows today:** 385 rows (0.2%). The worry in the sense check is real in principle but small in practice. Dates come from text changes and commencement in roughly equal shares.

**The 8,716 effect-labelled rows with no matching change** (300-row sample; scaled estimate):
- **Same law, but the register's change is undated: 123/300, about 3,600 rows.** Today's date came from the note's text and was labelled `effect`. This is LR-20's provenance mislabel (note dates shown as effect), still open, now measured. Under the projection these rows lose their date.
- **A whole-instrument change by the same law on that date: 112/300, about 3,300 rows.** Today's join reached the row another way (a note's placement); in the register it arrives as a whole-instrument change, for example ssi 2025/165, a commencement order "Regulations". Kept if whole-instrument commencements date rows (decision below).
- **Other laws only: 32/300; same law, another date: 24/300.** Today's spreading of note placement (LR-23's fan-out bug) and pooling.
- **No change on the row or its ancestors: 9/300.** Tables and inserted regulations.

## Labels as a query (proposed 2026-10-13)

Jason: put ourselves in a user's shoes. Users mostly want to know what applies today, but may want a "time machine": what applied on a given date. Then: "do static labels need to be applied? They go stale over time. The data is there to apply the 'label' at the time of query."

**Who reads the label columns today.** Nothing in sertantai-compliance's code reads `effective_from` or `changed_by`. fractalaw's pull (`zenoh/data_server.ex`) serves `effective_from`, `changed_by`, status and territory per row from `legal_articles`. That's the only column reader.

**Proposal:**
1. **`LabelProjection.labels(law, as_at \\ today)`**, pure, from the register:
   - the version in force at T and since when (D1);
   - whole-instrument changes from their dates (D2);
   - status from changes in force by T (D3);
   - each label with its change ids.

   The time machine is the same call with another date. Modifications are listed through the register with their dates (v0.1; no new label column, so fractalaw's contract is unchanged).
2. **Rows keep only facts about the text:** text, markup extent, markup status (e.g. prospective in the CLML). Everything that depends on changes and dates is computed.
3. **fractalaw's pull computes as-at-today labels when it serves** (same fields, same shape). Open for LH-05, not raised with fractalaw until Jason says: today's labels change as dates pass while the text doesn't, so how does fractalaw know to re-pull? Today its re-pull follows the content hash.

**Consequences:**
- **LR-25 shrinks.** No relabel wave over 375,000 rows. It becomes: switch fractalaw's pull to the projection; retire `effective_from`, `changed_by`, `change_provenance` and the change-derived part of `status` once LH-05 confirms; delete the parse-time label paths (LR-21). The collect-after-parse hook and the staleness check stay. No scheduled relabel is needed.
- **LR-26 (territory)** takes the same shape: where a provision applied, as at T.
- **Limits:**
  - the time machine gives status and dates at T, not the text as it read at T (only today's revised text is held; #171);
  - before about 2002, answers depend on LR-08.
- **Speed:** a row's changes 6 ms, the largest law 0.7 s from the view. The projection is timed when built.

## Gemini on labels as a query (2026-10-13)

`backend/data/code-reviews/2026-10-13-lr-24-labels-as-query.md`. **VERDICT: ACCEPT WITH CHANGES.**

**Correction to the proposal.** Gemini flagged the sync, and it's right. The `lat` table (`SertantaiLegal.Legal.Lat`), with `status`, `effective_from` and `changed_by`, is exported by the delta sync to compliance's production database (`Sync.Delta.Config`). Compliance's code doesn't read those columns, but they do reach production. Dropping them would be a schema change across the sync.

Taken:
- **Keep one materialisation, as a cache: "as at today".** Consumers that read columns (fractalaw's pull, the delta sync) need them, and so do cross-law questions ("all provisions in force today"). The query stays the source of truth; the cache is its output for one date.
- **Change detection.** The LAT manifest hash fractalaw re-pulls on must include the labels, so a provision coming into force (no text change) triggers a re-pull.
- **Retrospective changes.** The in-force date governs, not the date the change was made: as at T, a change counts if it is in force at T.
- **Rules for missing data.** No supporting change means an empty label, never a guess. That's already the LR-20 rule, now stated for the projection.

Not taken:
- **"Whole-corpus query ≈ 37.5 minutes".** That estimate assumes one 6 ms query per row. The measured corpus-wide view read is 22 s, and the projection runs per law. The cache answers cross-law questions anyway.
- **`effective_from` as an array for partial commencement.** Status `in_force_partial` plus the register's dated entries carry it; a new label shape would change the contract.
- **Hashing labels into the content hash.** The manifest carries the labels hash next to `lat_hash`, so text and label changes stay distinguishable.

Added by Claude:
- **"Today" is the UK date (Europe/London), not UTC.** In-force dates are UK dates; at 00:30 BST, UTC is still the previous day.
- **Semantics are valid time.** As at T means "as the law is known now, what applied at T", not "what we would have said at T". Bitemporal history is out of scope. Audit of what was served comes from the cache's daily changes: a status that changes because a date passes is logged in `lat_changes` (`LatParseLog`), so "what did we serve on date X" is answerable.

**R2 in one line:** labels are a query as at a date; the existing columns become the dated "today" cache (as-at date + code version), refreshed daily and after each collect; the manifest carries a labels hash; changes to the cache are logged. Effect on LR-25: no relabel wave from the parse; instead the cache refresh job, the labels hash in the manifest, deletion of the parse-time label paths, and the staleness check. fractalaw's and compliance's column contracts are unchanged (values move; LH-05 notes the meaning: "as at" the stamped date).
