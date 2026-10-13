---
session: 'LR-24: Label Projection'
status: active
opened: 2026-10-13
bugs:
  - pattern: "Modification effect types read as text changes by a later verb: 'applied in part … (as inserted)' → inserted, 'modified by S.I. 2003/281' → amended, 'construed as one with …' → substituted"
    category: change-kind
    module: ChangeFacts.kind/2
    affected: "~1,100 register records; whole-instrument ones re-dated every row (2010/15: 2021-03-31 on whole Parts)"
    fix: "modification verbs (applied, modified, excluded, extended, restricted, disapplied, construed, continued, transferred, functions, power) added to kind/2 as 'other' — the earliest verb wins"
    status: fixed
  - pattern: "A territorial repeal (for S only, or part of the extent) read as repealing the whole row"
    category: label-status
    module: LabelProjection (D3)
    affected: "~6,500 rows in the first dry run (in_force → repealed / repealed_saved); 31 of a 40-row sample were territorial"
    fix: "a repeal counts for status and versions only where its extent covers the row's; it narrows territory instead (LR-26)"
    status: fixed
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
- ✅ Offline diff: the timeline as at today against today's labels, classified (expected: effect labels mostly equal; note-sourced and note-dated labels empty)
- ✅ Gap queries: rows with a note pointer and no change; changes with no date; changes resolving to no row
- ❌ Gemini acceptance — dropped (Jason, 2026-10-13: "drop the gemini review from the session")

## Decisions for Jason

- **J1 — approved 2026-10-13.** Before the earliest known event (no data case):
  - the timeline starts at the earliest date we have evidence for: the provision's insertion (it didn't exist before), its own commencement, or the law's `md_coming_into_force_date` (`uk_lrt`; held for 564 of 1,066 LAT laws);
  - with none of those, it starts at the earliest change we hold;
  - before that start there's no row ("unknown"), never a guessed "in force".
- **J2 — approved 2026-10-13.** Today's period vs the CLML markup: When the timeline as at today disagrees with the revised text's markup (e.g. the text shows the provision repealed but no repeal change is dated), the markup wins for the current period and the disagreement is listed as a gap. The revised text is legislation.gov.uk's current state; a dated change can't be invented to explain it.
- **J3 — approved 2026-10-13** as the J1 order (Jason: "this repeats that"): the law's coming into force from the register, else its CLML metadata. Start for laws with no coming-into-force date (44,327 rows in 357 laws have no timeline: `uk_lrt.md_coming_into_force_date` is empty for 502 of 1,066 LAT laws and the rows have no dated change). Recommend:
  - **Acts:** start at Royal Assent (`ukm:EnactmentDate` in our CLML; 335 Acts). That's the Interpretation Act 1978 s.4 default, "at the beginning of the day on which the Act receives the Royal Assent" unless provision is made otherwise. Sections commenced later by order are prospective until their commencement (post-2002 from effects; pre-2002 from LR-08).
  - **SIs:** start at `ukm:ComingIntoForce` where the CLML has it (13).
  - **The rest** (about 125 SIs with neither): no timeline (J1), listed.
- **J4 — approved 2026-10-13** (Jason: "important that compliance and subsequently users know the provision is repealed … 'outstanding effect' is on the source"). A repeal in force but not yet applied to the text (`applied: false`; 18 of 40 sampled new repeals). The law has repealed the provision by its date; legislation.gov.uk hasn't updated the revised text. Recommend: the repeal counts from its date (the law outranks the derived text), and the row is listed as an "outstanding effect" gap. The alternative is to wait for the text.
- **J5 — approved 2026-10-13** (Jason: "Notes should already ONLY act as pointers and make sure the real fix is logged in the right session"). Built: the pointer withholds the law's start; the fallback start counts only changes on the row, not whole-instrument ones; gap `insertion_not_in_register`. Real fix: LR-27 (text-only effect refs) and LR-08 (pre-2002). An inserted provision whose insertion isn't in the register (7,157 rows / 144 laws). The row carries a whole-provision insertion or substitution note ("Ss. 27U-27Y and cross-heading inserted …"), the register has no dated insertion on it, and J3's default would date it from the law's own start (1996/18 s.27V: Royal Assent 1996-05-22 for a section inserted in 2024). Recommend: the note acts as a pointer only — it withholds the default, it supplies no fact. The start is unknown (no period before the first change held); listed as a gap "insertion not in the register". The data comes later from the join (the feed's "Part 2B inserted" has no structured refs: 25 such effects) or LR-08.
- **TRUTH decided 2026-10-13 (Jason):**
  - **T3:** "I'm okay with implied, avoids lots of extra row noisiness": no row = unknown.
  - **W1:** "leave that to the session" (LR-26); the table documents that it is not a "where" source until then.
  - **T1:** "a text change we cannot date should communicate that fact". Built with no new schema: `in_force_from` empty with status in_force = "changed, date unknown" (documented on the table), plus an `undated_change` gap.
  - **T2:** "default dates do have some basis in truth - do we need another column - more schema to explain": no column; the defaults stand.
- **TRUTH — Jason, 2026-10-13 (the question): "we cannot have wrong data for when and where"; where fidelity isn't possible, a clear value must say so.** Audit (see "Truth audit"), each a decision:
  - **W1:** a provision repealed for one territory shows `in_force` with no territory (12,276 rows). Until LR-26 the timeline must not be read for "where"; LR-26 becomes a v0.1 blocker for any reader.
  - **T1:** a text change we know happened but can't date makes the version date `unknown`, never an older date. Sources: undated change markup (15,398 rows), a note pointing to an amendment the register lacks (up to 14,709 rows; the J5 rule generalised from insertions to every text change), unreached gaps on the row.
  - **T2:** Royal Assent / law-start defaults carry `basis = law_default`, not `evidence`; or are `unknown` (the pre-2002 Act whose sections were commenced by order is the risk).
  - **T3:** an explicit `unknown` period from `-infinity` (a Postgres date) instead of a missing row, so every provision has a value for every date.
- **F — Fill: approved and applied 2026-10-13** (Jason: "fill approved - don't message compliance, we're not finished building or enriching"); to be rebuilt after the truth decisions. `mix lat.timeline --all --apply` writes `lat_label_timeline` only (empty today; nothing reads it until LR-25 and compliance's badge); see "Dry run with J5". **Jason: approve**
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

**Second and third dry runs (all laws).** Repeal and classification faults found and fixed (bugs above):
- **Territorial repeals** read as whole repeals: in force → repealed fell from about 9,800 rows to about 3,300.
- **Modification types read as text changes** by a trailing "(as inserted)": about 1,100 register records; whole-instrument ones re-dated whole Parts.
- **Whole-instrument words-level changes** (a blanket "words substituted") started a version on every row; they now count like an ancestor's.

The register was re-collected after each classifier fix (fidelity 0).

**No start (J3):** 44,327 rows in 357 laws. Laws lacking `md_coming_into_force_date`: 502, of which 335 are Acts with `ukm:EnactmentDate` in the CLML, 13 SIs with `ukm:ComingIntoForce`, and about 125 SIs / NI instruments with neither.

**Fourth dry run (after the classifier fixes).** Dates moving: 25,173 → 6,632 rows. Losing their date with status unchanged: 14,310. A sample shows these are correct under the rules:
- dates from note text (no dated change at that date);
- dates from the "earlier affecting provision" fix (HSWA 2009-08-05);
- partly-in-force rows (`in_force_from` empty by D1);
- J2 prospective markup.

In force → repealed: 3,763 rows. Of a 40-row sample:
- 18 are repeals in force but not applied to the text (J4);
- 21 are applied, with the text still present. These include "repealed in part (except s. 31)", now not a repeal (LR-06 "revoked in part"; test added; suite 2,665).

## Final dry run with J3 / J4 (2026-10-13)

`backend/data/reports/lat-refactor/lr24_dry.csv` and `.diff.csv`: 1,066 laws, 0 errors.

| | |
|---|---|
| Periods | 514,115 |
| Rows with no start (J1) | 19,826 in 173 laws (was 45,868 before J3) |
| Markup conflicts (J2) | 8,175 |
| Outstanding effects (J4) | 1,367 |
| Status unchanged / changed | 348,480 / 26,386 |
| effective_from: unchanged / moved / emptied / gained | 229,178 / 24,479 / 9,381 / 111,828 |

**A problem with J3's default.** Of the moved dates, 13,556 go earlier, most of them to the law's own start. Example: 1996/18 s.27V, inserted in 2024 by 2023/13 ("Part 2B inserted": the feed gives the Part as text only, no structured refs, so it reaches no row), dated from Royal Assent 1996-05-22. Rows carrying a whole-provision insertion or substitution note, with no dated insertion in the register and dated from the law's own year: **7,157 rows in 144 laws** (J5).

## Dry run with J5 (2026-10-13, for the fill)

1,066 laws, 0 errors.

| | |
|---|---|
| Periods | 476,075 |
| Rows with no timeline | 34,287 (9%): no start 22,203; insertion not in the register 12,084 (J5; LR-27 / LR-08 will date them) |
| Markup conflicts (J2) | 7,925 |
| Outstanding effects (J4) | 1,343 |
| Status vs today: same / changed | 334,794 / 40,072. Of the changes, 33,626 are "unknown" (no timeline row) |
| Other status moves | in force → repealed_saved 1,885 / repealed 857; repealed_saved → in force 899 (territorial or "in part" repeals) |
| effective_from vs today: same / moved / emptied / filled | 232,432 / 14,188 / 20,387 / 107,859 |
| Inserted-looking ids still dated from the law's own year | 53 (was about 5,750 before J5) |

Moved dates: 12,993 earlier, 1,195 later. Sampled causes:
- note-text dates replaced by the law's start or the version held;
- territorial repeals no longer starting versions;
- the "earlier affecting provision" fix;
- today's labels carrying a future date (now as at today).

## Truth audit (2026-10-13)

Jason: "does our when and where data tell the truth and when it cannot have fidelity does it default to a clear value signalling that fact — we cannot have wrong data for when and where". Answer: not yet. Where the timeline can state a wrong value rather than "unknown":

| # | Where it can be wrong | Rows | Proposal |
|---|---|---|---|
| W1 | A territorial repeal (e.g. repealed for S) leaves `status = in_force` and `territory` empty, so it's wrong for that territory | 12,276 with a territorial repeal in force | LR-26 (territory per period) before any reader; until then the timeline is not a "where" source |
| T1 | A text change happened but can't be dated (undated change markup; a note pointing to an amendment the register lacks; an unreached change on the row): `in_force_from` shows an older version date | 15,398 rows with undated markup; up to 14,709 note-labelled rows | `in_force_from` unknown whenever the row has a pointer to an undatable text change (generalises J5) |
| T2 | Law-start defaults (register date, CLML, Royal Assent) state "in force since" for provisions whose commencement the feed doesn't hold (pre-2002 commencement by order) | the 107,859 newly filled dates are mostly defaults | a `basis` column (`evidence` / `law_default` / `markup`), or `unknown` |
| T3 | No row = unknown is implicit; a reader can't tell "unknown" from "missing" | 34,287 rows | an explicit `unknown` period from `-infinity` |

The fill runs on (it writes only the new table; nothing reads it). It's rebuilt after these.

## Fill (2026-10-13)

`mix lat.timeline --all --apply --tag lr24_fill`: 1,066 laws, 0 errors; **476,075 periods** (equal to the dry run) for 340,579 provisions in 1,003 laws, `code_version` 31bf7029. The EXCLUDE constraint held for every insert (no overlapping periods). As at today for HSWA: in force 993, repealed 39, repealed_saved 4, prospective 2, read in 1.5 ms. **Compliance not told** (Jason: not until building and enrichment are finished).

## Dry run with T1 (2026-10-13, for the rebuild)

1,066 laws, 0 errors. Periods are unchanged: 476,075 (T1 only empties dates). **Undated changes: 16,231 rows** now carry an empty `in_force_from` with status in_force ("changed, date unknown") instead of an older date. Against today: effective_from same 227,043 / moved 11,157 (was 14,188) / emptied 29,859 / filled 106,807. Unchanged otherwise: no start 22,203, insertion not in the register 12,084, markup conflicts 7,925, outstanding effects 1,343. **Rebuild (dry run → Jason → apply).**

## Rebuild and gaps (2026-10-13)

**Rebuild** (approved): `mix lat.timeline --all --apply --tag lr24_rebuild`. 1,066 laws, 0 errors; **476,075 periods**, all `code_version` edd5156e. 15,029 provisions' current period reads "changed, date unknown" (`in_force` with no `in_force_from`).

**Gaps: what the labels can't fully answer.** `mix lat.timeline` writes `<tag>.gaps.csv` (law, section_id, gap). Current list: `backend/data/reports/lat-refactor/lr24_gaps.gaps.csv`.

| Gap | Provisions | Means | Fixed by |
|---|---|---|---|
| no_start | 22,203 | no evidence of when it started; no row (unknown) | metadata / LR-08 |
| insertion_not_in_register | 12,084 | a note points to an insertion the register doesn't date | LR-27, LR-08 |
| undated_change | 16,231 | the text changed; no source dates it | LR-08, LR-27 |
| markup_conflict | 7,925 | the CLML says repealed / prospective, no dated change explains it (markup wins today) | review |
| outstanding_effect | 1,343 | a repeal in force not yet applied by legislation.gov.uk (repealed shown) | source-side |

**Register gaps** (queries on `lat_change_log`):
- changes reaching no row: `section_id IS NULL`, 14,140 (586 laws);
- feed changes with no date, not prospective: `collector = 'feed' AND effective_from IS NULL AND NOT prospective`, 265;
- prospective with no date yet: 19,325;
- change markup no effect explains: `collector = 'markup'`, 8,547.
