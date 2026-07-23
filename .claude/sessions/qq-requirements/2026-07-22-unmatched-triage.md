---
session: QQ Requirements — Unmatched Law & Provision Triage
project: sertantai-legal
status: closed
opened: 2026-07-22
closed: 2026-07-23
outcome: success

summary: >
  Resolved 45 of 46 unmatched QQ law titles using a whitelist approach (raw title →
  LRT name), avoiding fragile parser regex changes. LRT no_lrt dropped from 219 rows
  to 7 (1 unique title, triaged as not in register). Classified 783 no_lat provisions:
  289 orphan schedule refs (expected — schedules don't carry obligations), 263 under
  zero-LAT laws (10 revoked, 19 making+in-force = real LAT backlog), 231 format
  mismatches. Re-ran aggregate (269 laws) and pushed updated compliance to Baserow
  (196 rows updated).

decisions:
  - what: Title whitelist instead of parser regex fixes
    why: >
      Parser was already at 98.9% provision parse rate. The 46 unmatched titles were
      caused by Scottish S.S.I., Welsh S.I., S.I. No., asp, and other non-standard
      formats. Adding regex for each risked regressions in the existing 1,900+ matched
      rows. A whitelist is auditable, zero regression risk, and trivially extensible.
    result: >
      TITLE_WHITELIST dict maps 46 raw QQ titles to LRT names (or guidance/skip/None).
      --rematch flag on match command resets no_lrt rows and re-runs with whitelist.
      218 of 219 no_lrt rows resolved on first run, +1 after adding missed title.

  - what: Schedule no_lat provisions are orphan refs, not gaps
    why: >
      Schedules are referenced from the main body text of the law — they don't add
      new obligations. LAT correctly omits them. The 289 schedule refs in QQ point
      to structural containers, not obligation-bearing text.
    result: Reclassified as expected no_lat, not a coverage gap.

metrics:
  lrt_no_lrt_before: 219
  lrt_no_lrt_after: 7
  lrt_unique_titles_resolved: 45
  lrt_unique_titles_remaining: 1  # Water Supply Byelaws — not in register
  lrt_matched_laws: 269           # up from 227 (aggregate)
  lat_no_lat_initial: 783
  lat_no_lat_after_lat_parse: 695 # after parsing 42 zero-LAT laws (+88 matched)
  lat_no_lat_final: 447           # after schedule resolution (+248 matched)
  lat_matched_final: 1622         # up from 1286
  lat_orphan_schedules: 289       # schedules don't carry obligations
  lat_schedules_resolved: 248     # reverse-lookup into body provisions (85.8%)
  lat_schedules_unresolvable: 40  # no body text references schedule
  lat_under_zero_lat_laws: 263    # 54 laws, 10 revoked, 19 making+in-force
  lat_format_mismatch: 231        # range refs, compound refs etc.
  baserow_rows_updated: 196       # up from 174
  baserow_rows_missing: 27        # newly matched laws not yet in Assessments table
  org_compliant: 163
  org_action_required: 60
  org_not_applicable: 46
  zero_lat_revoked: 11            # confirmed via rescrape session qq-revoked-verify-2026-07-23
  zero_lat_making_in_force: 19    # genuine LAT parse backlog
  revoked_site_req_rows: 252      # site×requirement rows against revoked laws
  revoked_applicable: 126         # marked Applicable against revoked laws
  revoked_action_required: 3      # open actions against revoked laws

lessons:
  - title: Whitelist beats regex at the tail — known finite set of mismatches
    detail: >
      The 46 unmatched titles were 7 distinct format categories (S.S.I., Welsh S.I.,
      S.I. No., asp, Ch., Acts without chapter, data artefacts). Each would need its
      own regex with ordering concerns. A dict literal is faster to write, easier to
      verify against PG, and impossible to regress.
    tag: tooling

  - title: Scottish instruments are type_code=ssi not uksi, pre-devolution are uksi
    detail: >
      QQ titles like "(S.S.I. 219)" map to ssi type_code in our register.
      Exception: pre-devolution Scottish SIs (e.g. 1992) remain as uksi.
      The cross-type-code fallback in match handles this, but the whitelist
      makes it explicit.
    tag: data

  - title: Schedule refs are orphan — schedules don't carry obligations
    detail: >
      Schedules are referenced from the body text of the law. They are structural
      containers, not obligation-bearing provisions. LAT correctly omits them.
      289 of 783 no_lat provisions are schedule refs — expected, not a gap.
    tag: data

  - title: QQ register is stale — 11 fully revoked laws still cited
    detail: >
      Of 54 zero-LAT laws, 11 are fully revoked/repealed. All 11 confirmed via
      rescrape session (qq-revoked-verify-2026-07-23). 126 applicability assessments
      and 3 open actions maintained against revoked laws across 22 sites.
      The making_classification column on legal_register distinguishes
      duty-carrying from non-duty laws.
    tag: data

  - title: legislation.gov.uk applied field is editorial status, not legal status
    detail: >
      The `applied: "Not yet"` field in rescinded_by annotations means legislation.gov.uk
      hasn't updated their published text — NOT that the revocation hasn't legally taken
      effect. UK_ssi_2006_133 has applied="Not yet" but the revoking law (SSI 2017/389)
      came into force 2018-01-01. The revocation is legally effective; leg.gov.uk just
      has a data processing backlog. Our live derivation is correct.
    tag: data

  - title: lrt-create-session skill refactored from SQL templates to Mix task
    detail: >
      Replaced raw SQL templates (8 critical rules to remember) with
      `mix lrt.create_session` — validates laws, enriches parsed_data, enforces
      constraints via Ash. Skill doc now just describes the workflow and CLI flags.
    tag: tooling

artifacts:
  - backend/scripts/qq-requirements/map_requirements.py  # TITLE_WHITELIST + --rematch
  - backend/data/qq/requirements/output/org_compliance_by_law.csv  # updated aggregate
  - backend/data/qq/requirements/output/zero_lat_laws_making_status.csv
  - backend/data/qq/requirements/output/qq-exec-brief.md  # executive brief (in progress)
  - backend/lib/mix/tasks/lrt.create_session.ex  # new Mix task replacing SQL templates
  - .claude/sessions/second-tier-duties/2026-07-23-qq-secondary-requirements.md

depends_on:
  - qq-requirements/2026-07-22-qq-requirements-mapping.md

enables:
  - LAT parse sessions for the 19 making+in-force zero-LAT laws
  - second-tier-duties/2026-07-23-qq-secondary-requirements.md
---

## Context

The QQ requirements mapping pipeline (22 sites, 1,771 requirements) identified
unmatched items that need manual triage. These don't block the org-level compliance
assessment but represent gaps in coverage.

## Unmatched LRT — Resolution

### Approach: Title Whitelist

Rather than extending the citation parser with more regex (risking regressions at the
98.9% parse rate tail), we added a `TITLE_WHITELIST` dict that maps raw QQ title
strings directly to the correct LRT `name`.

### Categories resolved (45 unique titles)

| Category | Titles | Rows | Example |
|----------|--------|------|---------|
| Scottish S.S.I. | 19 | ~120 | `(S.S.I. 219)` → `UK_ssi_2018_219` |
| Welsh S.I. | 7 | ~25 | `(S.I. 1821/W.178)` → `UK_wsi_2010_1821` |
| S.I. No. format | 4 | ~30 | `(S.I. No. 2786)` → `UK_uksi_2002_2786` |
| Acts without chapter | 4 | ~5 | `Occupiers´ Liability Act 1957` → `UK_ukpga_1957_31` |
| Scottish Acts (asp/Ch.) | 2 | ~5 | `(asp 2)` → `UK_asp_2014_2` |
| SIs without number | 3 | ~8 | Title match → `UK_uksi_2008_296` |
| Misparses (QQ data errors) | 2 | ~3 | `(c.18)` wrong chapter → `UK_ukpga_1954_68` |
| `(2015 No. 307)` format | 1 | ~5 | → `UK_uksi_2015_307` |
| Scottish transitional | 1 | 1 | `(No. 1309 (S. 2))` → `UK_uksi_2021_1309` |
| International codes → guidance | 2 | ~22 | IMDG, ICAO |
| Data artefacts → skip | 2 | 2 | "Regulation 3", "Section 9" |

### Remaining (1 unique title, 7 rows)

- **The Water Supply (Water Fittings) (Scotland) Byelaws 2014** — genuinely not in
  our register (byelaws, not an SI/Act). Mapped to `None` in whitelist (stays no_lrt).

### Implementation

- `TITLE_WHITELIST` dict in `map_requirements.py` (~50 entries)
- `--rematch` flag on `match` command: resets no_lrt → pending, re-runs match with whitelist
- Whitelist checked first (before parser-based key match and title fuzzy match)
- Handles `"guidance"`, `"skip"`, `None` (triaged, stays no_lrt), and LRT name strings

## Unmatched LAT — Classification

783 provisions where the parent law matched LRT but the provision isn't in LAT.

### Breakdown

| Category | Count | Cause | Action |
|----------|-------|-------|--------|
| Orphan schedule refs | 289 | Schedules don't carry obligations — body text refs them | None needed |
| Under zero-LAT laws | 263 (54 laws) | Law not yet parsed into LAT | See below |
| Format mismatch | 231 | Range refs, compound refs | LAT match refinement |
| **Total** | **783** | | |

### Zero-LAT laws by status (54 laws)

| Status | Laws | Notes |
|--------|------|-------|
| ❌ Fully revoked | 11 | QQ out of date — confirmed via rescrape session |
| ⭕ Part revoked | 14 | 7 making, 7 unclassified |
| ✔ In force, making | 12 | **Genuine LAT parse backlog** |
| ✔ In force, not making | 6 | No LAT expected (amendment-only, transitional) |
| ✔ In force, unclassified | 10 | Need making classification first |
| ⚠ Planned / unknown | 2 | Edge cases |

CSV export: `backend/data/qq/requirements/output/zero_lat_laws_making_status.csv`

## Baserow Update (post-whitelist)

Re-ran aggregate and Baserow update with reconciled data:

| Metric | Before | After |
|--------|--------|-------|
| Matched laws | 227 | 269 |
| Compliant | 139 | 163 |
| Action Required | 53 | 60 |
| Not Applicable | 35 | 46 |
| Baserow rows updated | 174 | 196 |
| Baserow rows missing | 18 | 27 |

27 newly matched laws have no assessment row in Baserow — these are Scottish/Welsh/older
laws not yet in the Assessments table. Will appear at next Assessments seed.

## QQ Guidance → Secondary Sources

26 guidance items (389 lrt rows) classified from QQ — 14 are HSE ACoPs with L-codes
that should map to existing secondary sources. Pending session raised:
`.claude/sessions/second-tier-duties/2026-07-23-qq-secondary-requirements.md`

## Revoked Laws — Deep Dive

### Rescrape verification

Created session `qq-revoked-verify-2026-07-23` (11 laws) via `mix lrt.create_session`.
All 11 confirmed revoked/repealed after rescrape.

### `applied: "Not yet"` investigation

UK_ssi_2006_133 flagged as suspicious — legislation.gov.uk doesn't show the usual
revocation banner. The `applied` field in our rescinded_by annotations says "Not yet".

**Finding**: `applied` is an editorial status on legislation.gov.uk — it means they
haven't updated their published text to reflect the change. It does NOT mean the
revocation hasn't legally taken effect. The revoking law (SSI 2017/389) came into force
on 2018-01-01, so the revocation has been legally effective for 7+ years. Legislation.gov.uk
just has a data processing backlog for applying the change to the published text.

Our `live` derivation is correct — no bug.

### Executive brief

Started `backend/data/qq/requirements/output/qq-exec-brief.md` with revoked laws
findings: 126 applicability assessments, 124 compliant records, and 3 open actions
maintained against laws that no longer exist. Building incrementally.

## Skill Refactors

- `lrt-create-session` → `mix lrt.create_session` Mix task (8 critical rules now enforced by Ash)
- `lat-session-build` → `mix lat.create_session` Mix task (with built-in filtering)
- Both skill docs updated with naming convention for LAT queue dropdown visibility
- LAT queue dropdown fixed to fetch from `/api/lat/sessions` and show `lat-parse-*` sessions
- `/api/sessions/:id/law-names` updated to return all non-skipped records for lat_parse sessions
- Raised #129 for stale `function` column after fractalaw updates `is_making`

## LAT Parse Session

Created `lat-parse-qq-gaps-2026-07-23` with 42 laws (53 input, 11 revoked excluded).
40 of 42 parsed successfully. LAT section_ids grew from 277,545 → 291,950.
Re-running match resolved 88 additional provisions (1,286 → 1,374).

## Schedule Orphan Resolution

289 orphan schedule refs — QQ cites a schedule but not the body provision that
references it. Schedules don't carry obligations; the body text does.

**Approach**: Reverse-lookup from schedule into LAT text. For each orphan `sch.N`,
search `legal_articles.text` for body provisions (reg/s/art) containing
"Schedule N" or "Sch. N". Store resolved body provision(s) in new `resolved_ref`
column on the SQLite lat row.

**Results**:

| Category | Count |
|----------|-------|
| Resolved (1+ body provision found) | 248 (85.8%) |
| -- Clean (exactly 1 match) | 45 |
| -- Ambiguous (2+ matches) | 203 |
| Unresolvable (0 matches) | 40 |
| -- No LAT for law | 2 |
| -- Schedule not referenced in body text | 38 |

**Final LAT match status**:

| Status | Count |
|--------|-------|
| matched | 1,622 |
| no_lat | 447 |
| dash | 736 |
| pending | 890 |
| unparsed | 6 |

## Tasks

- [x] Categorise the 46 no_lrt titles (missing vs format vs artefact)
- [x] Build TITLE_WHITELIST mapping raw titles → LRT names
- [x] Add --rematch flag to match command
- [x] Verify all whitelist entries against PG (names exist)
- [x] Run rematch — 219 → 7 no_lrt rows
- [x] Classify no_lat provisions (schedule gaps, zero-LAT laws, format mismatch)
- [x] Check revocation status of zero-LAT laws (11 revoked, 19 making+in-force)
- [x] Re-run aggregate with reconciled data (269 laws)
- [x] Update Baserow Assessments (196 rows updated)
- [x] Raise pending session for QQ secondary requirements → ACoP mapping
- [x] Export zero-LAT laws making status CSV
- [x] Create rescrape session for 11 revoked laws (qq-revoked-verify-2026-07-23)
- [x] Confirm all 11 revoked via rescrape
- [x] Investigate `applied: "Not yet"` on UK_ssi_2006_133 — editorial status, not legal
- [x] Refactor lrt-create-session skill → Mix task
- [x] Refactor lat-session-build skill → Mix task
- [x] Fix LAT queue dropdown to show lat-parse-* sessions
- [x] Fix law_names endpoint for lat_parse sessions (include pending records)
- [x] Start executive brief (revoked laws section)
- [x] Create LAT parse session (lat-parse-qq-gaps-2026-07-23, 42 laws)
- [x] Re-run match after LAT parse (+88 provisions)
- [x] Resolve orphan schedule refs via reverse-lookup (+248 provisions)
- [x] Raise #129 for stale function column
