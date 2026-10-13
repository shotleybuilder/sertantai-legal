---
session: 'LR-24: Label Projection'
status: active
opened: 2026-10-13
bugs:
  - pattern: "legislation.gov.uk feed spells AffectingEffectsExtent 'same as affected' as S+A+M+E+A+S+A+F+F+E+C+T+E+D; stored as an extent code it reads as Scotland (+ junk)"
    category: feed-extent
    module: ChangesFeed (parse) / anything reading effect_extent
    affected: "17,881 lat_change_log records"
    fix: "LabelProjection reads it as 'same as the provision'; the feed parser should normalise it to nil at source (LR-26 territory)"
    status: open
  - pattern: "Effects changing an earlier amending or affecting provision ('amendment to earlier affecting provision SI 1995/3128 reg. 10(2) (as substituted)') classified as text changes by their trailing verb; they date rows as if this law's text changed"
    category: change-kind
    module: ChangeFacts.kind/2
    affected: "1,267 register records (565 as text ops); HSWA 409 rows dated 2009-08-05 by SI 2009/1750 today"
    fix: "kind/2 returns 'other' for types naming an earlier amending/affecting provision; register re-collected"
    status: fixed
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-24 Label Projection — When (ACTIVE)

## Problem

Row change labels (`effective_from`, `changed_by`, the change part of `status`, `change_provenance`) are computed inside the LAT parse (`ChangeFacts.row_facts`). LR-22 makes them a pure projection of `lat_change_log`. The rules: the row's own changes and its ancestors' whole-provision changes; the latest dated change; the authority order (law > derived data > auto-derived > editorial, never notes); each label linked to its change ids. Recomputed by `mix lat.relabel` without re-parsing LAT.

## Todo

- ✅ Measure first: rows whose `effective_from` today comes from a modification / application rather than a text change
- ✅ Jason: what `effective_from` means (since when the current text has had effect; modifications excluded), what each operation contributes to status, and what whole-instrument effects (LR-23 D5) mean for a row (LR-22 Q2)
- ✅ Jason: labels as a query as at a date; published as a timeline (R3 + timeline, approved 2026-10-13, v0.1)
- ✅ Compliance: the timeline in v0.1 — requirements received (see "Compliance's requirements"); the final DDL goes to compliance before it ships; final shape in dev by about 17 Oct for a release/0.1 exception (Jason confirms with compliance)
- ✅ Golden test cases: rows with known change histories (effective_from, changed_by, status, change ids), scrubbed of `key-` ids
- ✅ `LabelProjection` (pure): `timeline/4` (a law's rows + register records → periods) and `as_at/2`; status from changes, no note text
- ✅ `lat_label_timeline` (Ash resource + migration) and `mix lat.timeline --laws|--all [--apply]` (rebuild after each collect: the LR-25 hook)
- ⬜ Offline diff: the timeline as at today against today's labels, classified (expected: effect labels mostly equal; note-sourced and note-dated labels empty)
- ⬜ Gap queries: rows with a note pointer and no change; changes with no date; changes resolving to no row
- ⬜ Gemini acceptance

## Decisions for Jason

- **J1 — approved 2026-10-13.** Before the earliest known event (no data case):
  - the timeline starts at the earliest date we have evidence for: the provision's insertion (it didn't exist before), its own commencement, or the law's `md_coming_into_force_date` (`uk_lrt`; held for 564 of 1,066 LAT laws);
  - with none of those, it starts at the earliest change we hold;
  - before that start there's no row ("unknown"), never a guessed "in force".
- **J2 — approved 2026-10-13.** Today's period vs the CLML markup: When the timeline as at today disagrees with the revised text's markup (e.g. the text shows the provision repealed but no repeal change is dated), the markup wins for the current period and the disagreement is listed as a gap. The revised text is legislation.gov.uk's current state; a dated change can't be invented to explain it.
- **R3 + timeline — APPROVED 2026-10-13 (Jason: "it's needed in v0.1. I approve the timeline - that's a great solution").**
  - **Truth:** labels are a query as at a date.
  - **Published:** legal publishes a labels timeline, `lat_label_timeline`: one row per provision per period (section_id, valid_from, valid_to, status, in_force_from, changed_by, territory, change ids, code version). It's built from the register whenever the register changes.
  - **Reading:** "as at T" in any database is a lookup, `valid_from <= T < valid_to` (T = the UK date for today). There's no daily job anywhere, and nothing depends on the dev machine being on. Known future dates are already in the timeline; only new legal data waits for a sync.
  - **Sync:** the delta sync stops exporting `status`, `effective_from` and `changed_by`, keeps `extent_code`, and carries the timeline in **v0.1**.
  - **Rules:** D1–D3 are the timeline's rules, each judged per period.
- **R3 — (proposed; approved with the timeline above)** (see "Compliance on the label columns"):** labels are a query as at a date (the truth; time machine); no stored label columns. v0.1: the delta sync stops exporting `status`, `effective_from` and `changed_by` (`extent_code` stays); fractalaw's pull computes as-at-today labels when it serves, with a labels hash in the manifest. v0.2: a legal-owned dated labels table for compliance (section_id, as_at, status, in_force_from, changed_by, territory, code version). **Jason: approve R3**
- **R2 — superseded by R3:** (see "Gemini on labels as a query"):** the query is the truth; the existing label columns stay as a dated cache of "as at today" (refreshed daily and after each collect, stamped with the date and code version); the manifest hash includes the labels so fractalaw re-pulls when today's labels change; valid-time semantics; 'today' is the UK date. **Jason: approve R2**
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

## Compliance on the label columns (2026-10-13)

Asked the sertantai-compliance session (Jason: "the delta sync to compliance on these columns might be legacy"). Its answer, from compliance's code on main:
- **`lat.status`, `effective_from`, `changed_by`: not used anywhere.** Not on its Ash resource (`SertantaiCompliance.Legal.LegalArticle`), not in any query, not in the frontend Electric LAT schema. "Stop syncing them."
- **`extent_code`: used.** An attribute on `LegalArticle`, selected by the provision drill-down SQL (`screening_controller.ex`) and in `lat-schema.ts` `LAT_COLUMNS`. Don't drop or rename it without agreeing a replacement. Territory columns aren't used yet.
- **v0.1: needs none** (frozen for deploy).
- **v0.2: wants (b), a small labels table keyed by section_id**, with as_at, status, in_force_from, changed_by and territory, stamped with the as-at date and code version. Its uses:
  - #37: provisions not yet in force or repealed are marked or hidden, and don't drive a match;
  - per-site territory (QQ sites in England, Scotland, Wales);
  - "which provisions changed" under a law_amended event.

  "Legal owns the 'as at T' semantics; compliance shouldn't re-implement them from the raw log." Not the raw register.
- **Time machine:** no customer ask yet. A plausible QQ audit need ("what applied on the date of the incident or audit"). Design for it, don't build compliance-side support. If it comes up, compliance would call a legal "as at T" query rather than sync the log.

**R3** follows from this:
- No stored label columns: the query is the truth.
- The v0.1 sync change: drop `status`, `effective_from` and `changed_by` from the export; `extent_code` stays.
- fractalaw's pull computes at serve time, with a labels hash in the manifest.
- The v0.2 dated labels table is legal's output for compliance, and it also gives legal a dated record of what was served.

## Compliance's requirements for the timeline (2026-10-13)

From the compliance session:
- **No compliance migration.** Legal owns `lat_label_timeline` and creates it with its own migration (the prod DB is shared, like `legal_articles`). Compliance reads it read-only with raw SQL per law.
- **No Electric shape.** 0.5–1M rows never go to the browser.
- **Shape:**
  - `law_name` (as in `legal_articles`), plus an index serving `WHERE law_name = $1` and as-at: `(law_name, section_id, valid_from)` or a daterange with GiST;
  - **at most one row per section_id for any date**: `EXCLUDE USING gist (section_id WITH =, daterange(valid_from, valid_to) WITH &&)`;
  - `valid_from` / `valid_to` as `date` (UK dates); `valid_to` exclusive, null = open;
  - section_id format as in `legal_articles`, with the UK / AU partitions; say if the timeline is UK only.
- **Its v0.1 read: drill-down only.** LEFT JOIN as at the UK date for today; a status badge (repealed, repealed_saved, prospective, partial); a missing row means no badge. Repealed and prospective provisions are marked and listed last, not hidden. Not matching: the screener walks `legal_register.compiled_applicability`, so "repealed / prospective don't drive a match" is a tree-compile concern (#37, v0.2).
- **Timing:** the v0.1 feature freeze is 20 Oct. The badge lands on release/0.1 only if Jason confirms with compliance and the table is in dev with its final shape by about **17 Oct**; otherwise v0.2. It must not delay #133 / #27 (the v0.1 critical path).
- **The DDL** (columns, types, indexes) is sent to compliance before it ships, for its test sandbox.

## Build (2026-10-13)

- **`LabelProjection`** (pure): `timeline/4` (D1, D3, J1, J2 as its rules), `as_at/2`, `uk_today/1` (BST from 01:00 UTC on the last Sunday of March to the last Sunday of October; no tz database in the app). 15 golden cases on real provisions (1990/43 s.6(6A), s.162(2), s.78B(2); 1986/44 s.8F(4); 1996/18 s.201(1); 1995/288; 2008/2164 pt.1; 1974/37; 2017/1013) plus the UK date.
- **`lat_label_timeline`** (Ash resource; migrations `…163827` btree_gist, `…163828` table):
  - the EXCLUDE constraint, one period per provision per date (compliance);
  - index `(law_name, section_id, valid_from)`;
  - `territory` column ready for LR-26;
  - `code_version` stamped.
- **`LabelTimeline`** (builder: DB reads, write per law) and **`mix lat.timeline`**: a dry run by default, with the as-at-today diff against today's columns written as it goes.

**First four-law dry run: two faults, both fixed.**
1. **Changes to an earlier amending/affecting provision counted as text changes** (bug logged).
   - HSWA: 409 rows went 2009-08-05 → 2011-04-06, both from "amendment to earlier affecting provision S.I. 2001/2127 …" effects. Today's labels have the same fault.
   - The register holds 1,267 such records, 565 with a text operation picked from a trailing "(as substituted)".
   - `ChangeFacts.kind/2` now returns `other` for them. The register was re-collected.
2. **1990/43: 837 rows went in force → prospective.** Undated change markup (the markup collector) and applied effects with no date counted as commencements that never started. A commencing change now counts only when it has a dated entry, or is genuinely prospective (not applied).

Suite: 2,660 pass.
