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
- ✅ Jason: the pipeline must decide itself, so fix the extent/application data first (not a human review list)
- ✅ Changes feed (`ChangesFeed`): per-effect AffectedExtent / AffectingEffectsExtent / AffectingTerritorialApplication; LiveStatus uses them; parser enriches revocation rows
- ✅ ExtentResolver source `affected_effects` (legacy "UK" extents re-resolved)
- ✅ Batched fetch plan (Jason: a 10-hour fetch is too long); see "Effects fetch batching plan"
- ✅ Batches meta-batched by readiness tier (Jason): `Legal.ReadinessTiers`
- ⬜ Batch 0 (Tier 0, QQ register, 427) → apply_effects + recompute dry runs → Jason approves `--apply`
- ⬜ Tier 1 family list confirmed with Jason (draft in the Tier 1 session)
- ⬜ Batches 1a–1e (Tier 1 clusters) → dry runs → apply
- ⬜ Batches 2.01–2.08 (Tier 2, with a Family) → dry runs → apply
- ⬜ Batches 2n.01–2n.06 (Tier 2, no Family; last) → dry runs → apply
- ⬜ Remaining conflicts (Revoked laws with only partial rows, e.g. Feed Additives 2024/1101)
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

## Extent and application fix (2026-09-28, Jason's direction)

Jason: flagging 289 laws for human review is not a solution. The pipeline must make the determination, so if the data is bad, fix the data. The problem is extent vs application.

Findings:
- 234 of the 289 have `geo_extent = UK` with **no source** (legacy import). Their revokers mostly have `law_level` extents.
- legislation.gov.uk's changes feed (`/changes/affected/{law}/data.feed`) carries three things per effect, all editorial data, that the HTML table legal scraped drops:
  - `AffectedExtent` (extent of the affected provision / law);
  - `AffectingEffectsExtent` (extent of the change);
  - `AffectingTerritorialApplication` (where the change applies).

End-to-end parse with the feed (no DB writes):

| Law | Extent (source) | live |
|---|---|---|
| Special Waste Regs 1996 | GB (law_level) | Revoked in E+W; in force in S (territorial application E, W) |
| Control of Asbestos at Work Regs 1987 | GB (affected_effects; was UK) | Revoked (effect extent E+W+S+N.I.) |
| CoP (Amendment) Act 1989 | GB | Revoked in S; in force in E+W |
| Coal Industry Act 1994 | UK | Part revoked |
| Smoke Control (Exempted Fireplaces) (No. 2) Order 1983 | E+W (affected_effects; was UK) | Revoked in E; in force in W |
| Energy Information Regs 1996 | UK | Revoked (not yet applied to the text) |
| Forestry Act 1967 | GB | Revoked in S; in force in E+W |

Application proper (where a law operates, as distinct from its extent) is computed by fractalaw (#163, `application_regions`) for enriched laws only. For live status, the effect's territorial application is the application of the revocation. The revoked law's own application is bounded by its devolved type, title marker and AffectedExtent.

`geo_extent` feeds compliance screening, so the extent backfill is a gated dry run (`mix live.apply_effects`) before any write.

## Effects fetch batching plan (2026-09-28)

The full fetch is 16,521 laws at the client's 2 s delay, about 10.5 h. Jason: too long. Batches are **meta-batched by the readiness tiers** (parent: the enrichment readiness session), and Tier 1 is sub-batched by family cluster.

Tier definitions live in `SertantaiLegal.Legal.ReadinessTiers` (`tier_sql/0`), reusable by the tier sessions:
- **Tier 0**: laws QQ marks `yes` in compliance's `org_applicabilities` (651).
- **Tier 1**: the key families (the Tier 1 session's draft list, pending Jason's confirmation), excluding Tier 0.
- **Tier 2**: the rest. Laws with a Family (`2`) come before the 6,615 laws with none (`2n`, last; Jason).

Commands:
- `mix live.fetch_effects --batches` lists the plan.
- `--batch <label>` fetches one batch.
- Batches are ≤ 1,000 laws (~40 min). Cached laws are skipped, so re-running a batch resumes it. The cache is `backend/data/cache/changes-feed/`, with 848 laws already cached.

Within a batch, the order is:
1. Revoked, then part-revoked, then in force with revocation rows, then unsourced extent, then type-floor extent.
2. Within each of those, Making laws first, then laws with no extent source.

| Batch | Tier / cluster | Laws | ≈ time |
|---|---|---|---|
| 0 | Tier 0: QQ register | 427 | 17 min |
| 1a | OH&S (all) + FIRE (all) | 480 | 19 min |
| 1b | Waste + Water & Wastewater | 880 | 35 min |
| 1c | Environmental Protection, Pollution, Air Quality, Noise | 895 | 35 min |
| 1d | Climate Change, Nuclear & Radiological | 424 | 17 min |
| 1e | Building Safety, Consumer / Product Safety, Transport (Rail/Road/Air/Maritime) Safety | 690 | 27 min |
| 2.01–2.08 | Tier 2 with a Family (Revoked first, extent-only last) | 7,312 | 8 × ≤ 40 min |
| 2n.01–2n.06 | Tier 2 without a Family (last) | 5,413 | 6 × ≤ 40 min |

After each batch:
1. `mix live.apply_effects` (dry run: extent diff), then `--apply` on Jason's go. It acts only on cached laws.
2. `mix live.recompute` (dry run), then `--apply` on Jason's go. Laws with no effect data yet keep the no-feed rules, so it is safe to run part-way.
