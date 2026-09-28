---
session: Live Status Parse
status: active
opened: 2026-09-28
bugs:
  - pattern: "'Appointed day(s) for spec. repeals' (a commencement of repeals) counted as a whole-Act repeal because the affect contains 'repeal' and the target is 'Act'"
    category: live_status_false_revoked
    module: scraper/amending.ex determine_live_status/1
    affected: "≥1 (UK_ukpga_1994_21 Coal Industry Act 1994)"
    fix: "LiveStatus.revocation?/1 excludes appointed-day affects"
    status: fixed
  - pattern: "'revoked in pt', overseas-territory ('(Pitcairn)', '(Sovereign Base Areas)', …) and '(prosp.)' revocations counted as whole UK revocations"
    category: live_status_false_revoked
    module: scraper/amending.ex determine_live_status/1
    affected: "~10 rows"
    fix: "LiveStatus.whole?/1"
    status: fixed
  - pattern: "Legacy-imported revocation rows hold the whole effect text in target with affect null, so no rule could read them"
    category: live_status_legacy_rows
    module: scraper/live_status.ex rows_from_stats/1
    affected: "~220 laws (conflicts 357 → 138)"
    fix: "Split target text at the first repeal/revoke word"
    status: fixed
  - pattern: "Territorial revocation (SSI/WSI or E&W-only instrument with target 'Act'/'Regulations') treated as whole-UK revocation"
    category: live_status_false_revoked
    module: scraper/amending.ex determine_live_status/1
    affected: "≥2 (UK_ukpga_1989_14 by SSI 2025/165; UK_uksi_1996_972 by SI 2005/894 + WSI 2005/1806, Scotland still in force)"
    fix: "Territorial on hard evidence (devolved revoker, affect extent marker); UK-level revoker extent kept as extent_gap evidence (not trusted by default)"
    status: fixed
  - pattern: "live_description never recomputed after the changes stage; legacy values ('Current legislation', 'Revised - has been amended') contradict live = Revoked"
    category: live_status_inconsistent
    module: scraper/staged_parser.ex resolve_live_status/1
    affected: 1088
    fix: "Derive live_description from the same decision as live (parser + recompute)"
    status: fixed
---

# Session: Live Status Parse (ACTIVE)

## Problem

Legal's `live` status comes from the legislation.gov.uk changes table (`Amending.determine_live_status/1`). The rule behind it is right: a whole-instrument revoked/repealed effect counts as revoked, whether it has been applied or not, because the "Applied" column is ignored. Legal already catches unapplied revocations such as the Energy Information regs by SI 2011/1524 and the GPSR 1994 by SI 2005/1803. But the classifier has false positives, and `live_description` goes stale. False "revoked" matters because the Making funnel skips revoked laws: 287 laws are Revoked **and** Making, so they would never be queued for LAT.

Raised by fractalaw's delete-candidate review (2026-09-28), at Jason's request.

## Todo

- ✅ Gemini plan review (`backend/data/code-reviews/2026-09-28-live-status-{brief,review}.md`)
- ✅ Fix: commencement affects ("Appointed day(s) for spec. repeals") are not revocations; also "in pt", overseas territories, "(prosp.)"
- ✅ Fix: territorial revocation on hard evidence (devolved revoker, affect extent marker); law jurisdiction from devolved type > title marker > extent
- ✅ Evidence: `live_evidence` JSONB (kind incl. `revoked_unapplied`, with_savings, revokers with affect, target, revoker_made_date, basis, regions, extent_gap)
- ✅ `live_description` derived from the same decision as `live` (staged parser `resolve_live_status`)
- ✅ `mix live.recompute` (dry run default, guarded, snapshot + record_change_log on apply); dry run done
- ⬜ Jason: decide UK-level revoker extent policy (default: not trusted) and approve `--apply`
- ⬜ Review list: 289 Revoked laws with an `extent_gap`, and 145 conflicts
- ⬜ Re-check the 287 Revoked + Making laws after the recompute; any flip to in force re-enters the Making funnel
- ⬜ Report back to fractalaw (Coal Industry Act 1994, the 4 "not evidenced" laws)

## Findings so far (live changes-table check, 2026-09-28)

| Law | Legal says | Triggering row | Verdict |
|---|---|---|---|
| UK_ukpga_1994_21 Coal Industry Act 1994 | Revoked | target Act, "Appointed day(s) for spec. repeals…" (SI 1995/273) | **false positive** |
| UK_ukpga_1989_14 CoP (Amendment) Act 1989 | Revoked | target Act, "repealed" by SSI 2025/165 | Scotland only, **territorial** |
| UK_uksi_1996_972 Special Waste Regs 1996 | Revoked | revoked by SI 2005/894 + WSI 2005/1806 | E&W only; Scotland in force, **territorial** |
| UK_uksi_1994_2328 GPSR 1994 | Revoked | "rev" by SI 2005/1803, applied "Not yet" | correct (unapplied) |
| UK_uksi_2010_768 CRC Order 2010 | Revoked | "revoked (with savings)" by SI 2013/1119, not yet applied | correct (with savings) |
| UK_uksi_1996_600 Energy Information | Revoked | revoked by SI 2011/1524, not yet applied | correct (unapplied) |

Fractalaw reads data.xml `ukm:UnappliedEffect`. Legal reads the changes table. The two can disagree (GPSR 1994 has no effect in data.xml, but it is in the changes table).

## Dependencies

- ✅ Jason: go-ahead to open (2026-09-28: "bugs in status are critical fixes")
- ⬜ Jason: go-ahead to apply the corpus recompute (after dry-run diff)

## Gemini review and where we differ (2026-09-28)

Gemini agreed with the plan and recommended option (a): trust a UK-level revoker's recorded extent, citing the risk asymmetry (a false Revoked hides duties). It also recommended:
- keep `live_description` simple and put the detail in evidence;
- label the date as the revoker's made date;
- combine territorial revokers.

All of this is done.

**We depart from (a) on the evidence.** A sample of the weak bucket found almost no genuine territorial revocations. The law's *own* recorded extent was too broad instead: GB regimes (the Control of Asbestos at Work Regs 1987, Mines (Inrushes) 1979, the Brucellosis Order) and E+W or England-only regimes (T&CP EIA 1990, the Planning (COMAH) 1999, Plant Health (England)) are recorded as "UK". 216 of the 314 weak cases have no `geo_extent_source`. Under (a), about 300 dead laws would read as in force in NI or S, which is register noise and false customer hits.

So the default does not trust a UK-level revoker's recorded extent. The gap is kept as `extent_gap` evidence (289 laws for review), and `--trust-revoker-extent` switches to (a). The Special Waste Regs 1996, a genuine case, are in the review list.

## Dry run (2026-09-28, default policy)

| Outcome | Laws |
|---|---|
| change (Revoked → Part: 52 territorial, 2 part_revoked) | 54 |
| conflict (live kept; new rule disagrees, old rule doesn't explain current) | 145 |
| describe (live unchanged; description/evidence rewritten) | 6,237 |
| same | 13,381 |
| Revoked with extent_gap (review) | 289 |
| Revoked + Making re-entering the funnel | 7 |

With `--trust-revoker-extent`: 345 changes and 19 Making laws. Examples of the default changes:
- the Forestry Act 1967, Reservoirs Act 1975 and Conservation of Seals Act 1970 are revoked in S and in force in E+W;
- the CoP (Amendment) Act 1989 is revoked in S;
- the Coal Industry Act 1994 becomes Part revoked.

The report is in `backend/data/reports/live-status/recompute-*.csv`.
