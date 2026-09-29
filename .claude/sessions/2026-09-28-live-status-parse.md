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
  - pattern: "REACH (UK_eur_2006_1907, Making, QQ register) Revoked by a blank-target 'repeal' row that legislation.gov.uk records only as annex repeals"
    category: live_status_false_revoked
    module: scraper/live_status.ex whole?/1
    affected: "3 in batch 0 (REACH, Reg 561/2006, Directive 98/24)"
    fix: "Changes feed is authoritative: a whole-looking row with no whole-instrument revocation effect is not whole (feed: unmatched)"
    status: fixed
  - pattern: "'partial repeal' (EU wording) counted as a whole revocation"
    category: live_status_false_revoked
    module: scraper/live_status.ex whole?/1
    affected: unknown
    fix: "'partial' is a partial marker"
    status: fixed
  - pattern: "legislation.gov.uk effect extent 'S+A+M+E+A+S+A+F+F+E+C+T+E+D' (SAME AS AFFECTED) parsed as regions S and E"
    category: live_status_extent_parse
    module: scraper/live_status.ex regions/1
    affected: "281 cached laws carry it"
    fix: "Recognised: the change reaches wherever the law does"
    status: fixed
  - pattern: "Changes-table rows and feed effects name the whole instrument differently ('' / 'Regulation', 'Act' / 'Regulations', 'revoked' / 'repealed')"
    category: live_status_feed_match
    module: legislation_gov_uk/changes_feed.ex lookup/4
    affected: "whole rows matched 98/176 → 105/107"
    fix: "Whole-instrument fallback: same revoker's whole-instrument revocation effect"
    status: fixed
  - pattern: "Revoked law's current LAT text is '. . .' placeholders, so its application clause is gone; the law looked unresolvable"
    category: live_status_application
    module: scraper/extent_backfill.ex + live_status.ex
    affected: "4 of batch 0's 11"
    fix: "text_repealed (≥95% of substantive provisions dotted) = revoked in full; text read with no clause = applies throughout its sourced extent; SI regions bounded by the enabling Act's extent"
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
- ✅ Batch 0 fetched (426/427; 1 regnal-year name 404)
- ✅ Batch 0 dry runs: bugs found and fixed; see "Batch 0 results"
- ✅ Law **application** built into LAT (Jason: LRT must not pull full text); see "Application clause"
- ✅ Batch 0 applied (Jason: "run all four"); see "Batch 0 applied"
- ⬜ Batch 1a (Tier 1: OH&S + FIRE); needs Jason's go and the Tier 1 family list
- ✅ Fractalaw live-fix publish (8 laws) verified; see "Live-fix enrichment"
- ✅ Tier 1 fetch (1a–1e): 3,360 fetched; 5 pre-1948 SR&Os (`uksro`) have no changes feed
- ✅ Tier 1 dry runs; see "Tier 1 dry runs"
- ✅ Tier 1 applied; see "Tier 1 applied"
- ✅ Parent-Act bound narrows but never determines (Jason); applied: T&CP (Trees) 1999 and 4 Surface Waters regs held at Revoked
- ✅ Fractalaw restored 3 PPC orders; Surface Waters held (legal now Revoked, so no restore)
- ✅ Enabling-provision extent built; batch 0 applied (see "Enabling provisions")
- ⬜ Tier 1: `live.enabling` dry run → re-parse its parent Acts → apply → recompute
- ⬜ Tier 1 parents: 78 with LAT (re-parse), 25 Making without LAT (parse and keep, e.g. MSA 1995), 89 non-Making without LAT (**scoped LAT of the cited sections, #166**; Jason: data in LAT, not caches)
- ⬜ Legal rename log `created_at` is naive (no timezone); make it RFC 3339 (fractalaw's first sync consumed no renames because of it; fractalaw has fixed its parser)
- ⬜ Corpus LAT re-parse for the extent-inheritance fix (all ~1,000 LAT laws); decide with Jason
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
0. Cross-check fractalaw's hub archive (`~/fractalaw/data/lat-sync/archive61.txt`: 61 laws archived as revoked, `not_in_legal`). Any law that comes out not fully Revoked is reported to fractalaw so it can `--restore-laws`. At 2026-09-28 after batch 0, all 61 are still Revoked.
1. `mix live.apply_effects` (dry run: extent diff), then `--apply` on Jason's go. It acts only on cached laws.
2. `mix live.recompute` (dry run), then `--apply` on Jason's go. Laws with no effect data yet keep the no-feed rules, so it is safe to run part-way.

## Batch 0 results (2026-09-28)

Fetch: 426 of 427. `UK_ukpga_1961_Eliz2/9-10/62` returned 404 because regnal-year names need a different path. Malformed names (`UK__…`, `…_` with no number) are now excluded from the targets; `UK_eur_2006_` had fetched a whole year's feed.

`mix live.apply_effects --batch 0` (dry run):
- revocation rows matched: 2,545 of 2,774, and 105 of 107 whole-instrument rows;
- 238 laws' rows gain effect data;
- 25 extent changes, 8 of which change the value (UK → GB 5, UK → E+W 2, ∅ → UK 1).

`mix live.recompute --batch 0 --with-effects` (a preview that applies the planned effect data in memory): 14 changes, 3 conflicts, 5 Making laws leaving Revoked.

| Verdict | Laws |
|---|---|
| Right: falsely Revoked today | REACH 1907/2006, Drivers' Hours 561/2006, Chemical Agents Directive 98/24 → Part revoked |
| Right: territorial | Special Waste Regs 1996 (in force S), Conservation (Natural Habitats) Regs 1994 (in force S), Forestry Act 1967 and Reservoirs Act 1975 (in force E+W), Groundwater Regs 1998 (in force S), Marine Works EIA Regs 2007 (revoked S) |
| Wrong: the law's **application** is unknown, and its recorded extent "UK" is too wide | Smoke-free (Signs) Regs 2007 and Environmental Damage Regs 2009 (England only; revoked in E ⇒ revoked), T&CP (Trees) Regs 1999 ("in force in W+S+NI" is wrong for S and NI) |
| Unclear (feed says so; the NI remainder may be a UK extent on a GB regime) | Heavy Fuel Oil (Amendment) Regs 2014, H&S (Misc Amendments) Regs 2017 |

Conflicts (live kept): Food and Environment Protection Act 1985 (Revoked), Data Protection Act 2018 and Confined Spaces Regs 1997 (In force).

**Next, Jason's point:** extent is not application. A territorial decision needs the law's application: where it applies, not the legal system it forms part of.

Proposed: only for laws where the decision would be territorial, read an application clause from the law's own text. That is the citation/application provision, e.g. "These Regulations apply in relation to England", fetched from legislation.gov.uk. Fractalaw's `application_regions` would be used where present. The law's regions then become devolved type > title > **application clause** > AffectedExtent > geo_extent.

## Application clause (2026-09-28)

Jason: the LRT parser must not pull full text, since that mixes LRT and LAT. The application clause folds into LAT parsing.

Design, as built:
1. **`Scraper.ApplicationClause`** (pure) reads whole-instrument clauses only:
   - "These Regulations / This Order / This Act … apply(ies) [only] (in relation) to|in X";
   - the application half of "extend to X and|but apply …";
   - "They apply in X" when the text names the instrument;
   - exclusions ("do not apply to X").
   
   The target must be a nation list, optionally followed by "and …" extras. Rejected: partial subjects ("This regulation", "Part 2 of …"), qualified clauses ("Subject to …", "except", "outside", "as they apply"), and scope phrases ("the compulsory purchase of land in England").
2. **Folded into `ExtentBackfill`**, which already runs at every LAT persist and reads extent clauses. The same lateral query collects application clauses: no extra fetch and no extra pass. The result is stored as `application_clause` (legal-owned JSONB: regions, clauses with section_id, kind and text, lat_hash). It is written only when the law holds LAT, so a lean-LAT discard never clears it. Fractalaw's `application_regions` stays as received.
3. `ExtentBackfill.refresh/1` then calls `LiveStatus.Recompute.refresh/1`, so a LAT parse re-decides the law's live status automatically.
4. **`LiveStatus`**: the law's regions come from devolved type, then title, then **application** (its own clause, else fractalaw's when sourced from text or title), then AffectedExtent, then geo_extent. A territorial result resting on the last two is `application_unknown`: the parser keeps the changes status, and recompute holds it as `needs_application`. "Revoked in …" comes from the revokers' regions.
5. **`mix live.application --batch N`** lists them. `--parse` LAT-parses them through `LatReparse`; LAT that wasn't held before and isn't Making is then discarded with an archive (reason `application_clause`).

Checks:
- Parser samples (12 of 12 correct after tightening) include "These Regulations apply in relation to England only" → E, "…extend to England and Wales and apply in relation to England only" → E, and "shall not apply to Northern Ireland" → E+W+S.
- `mix extent.resolve` dry run: 941 laws hold LAT, 72 of them have a whole-instrument clause (E 34, W 31, E+W+S 5, NI 1, S 1), and there are 0 pending extent changes.
- Batch 0 needs_application (preview with effects): 11 laws. These are the territorial candidates, including Smoke-free (Signs), Environmental Damage and T&CP (Trees).
- End-to-end test: an England-only law revoked in England stays Revoked on basis `application`, and its application survives the discard.

## Batch 0 applied (2026-09-28)

1. `mix extent.resolve --apply`: `application_clause` written for 943 laws holding LAT (72 with a clause), with 0 extent changes. Snapshot `extent_backfill_snapshot_20260928`.
2. `mix live.apply_effects --batch 0 --apply`: effect data on 291 laws' revocation rows (2,546 of 2,774 rows matched) and 25 extent updates. Snapshot `effects_backfill_snapshot_20260928_b0`.
3. `mix live.application --batch 0 --parse`: the 11 needs_application laws were LAT-parsed. 9 not-Making laws were discarded with archive (reason `application_clause`); Forestry Act and Special Waste are Making and keep their LAT.
   - A gap surfaced: a revoked law's current text is ". . ." placeholders, so its clause is gone. Three rules were added:
     - text ≥ 95% repealed ⇒ revoked in full;
     - text read with no clause ⇒ applies throughout its sourced extent;
     - an SI is bounded by its enabling Act's extent (`enacted_by`).
   - The 9 were re-read (`--names`), and the persist hook re-decided them.
4. `mix live.recompute --batch 0 --apply`: 5 changes, 3 conflicts kept, 283 descriptions. Snapshot `live_status_snapshot_20260928_b0`.

Results (9 live changes, each in record_change_log; is_making unchanged at 3,623):

| Law | Was | Now | Basis |
|---|---|---|---|
| REACH 1907/2006 (Making) | Revoked | Part revoked | feed: only annex repeals |
| Drivers' Hours Reg 561/2006 (Making) | Revoked | Part revoked | feed |
| Chemical Agents Directive 98/24 (Making) | Revoked | Part revoked | feed |
| Forestry Act 1967 (Making) | Revoked | Revoked in S; in force in E+W | affected_extent |
| Special Waste Regs 1996 (Making) | Revoked | Revoked in E+W; in force in S | territorial application E, W |
| Reservoirs Act 1975 | Revoked | Revoked in S; in force in E+W | affected_extent |
| Conservation (Natural Habitats) Regs 1994 | Revoked | Revoked in E+W; in force in S | affected_extent + parent |
| T&CP (Trees) Regs 1999 | Revoked | Revoked in E; in force in W | extent + parent (T&CP Act 1990) |
| Marine Works EIA Regs 2007 | Revoked | Revoked in S; in force in E+W+NI | extent + parent |

Confirmed Revoked (determinations): Smoke-free (Signs) 2007 (application E), Environmental Damage 2009, Groundwater 1998, Heavy Fuel Oil (Amendment) 2014, H&S (Misc Amendments) 2017 (text repealed in full).

Conflicts kept, for review: Food and Environment Protection Act 1985 (Revoked), Data Protection Act 2018 and Confined Spaces Regs 1997 (In force). **Resolved:** see "Guard: rules agree".

The 5 Making laws leaving Revoked re-enter the Making funnel.

## Guard: rules agree (2026-09-28)

Jason: FEPA 1985, DPA 2018 and CSR 1997 aren't revoked; did the data say otherwise? **No.** For all three, the old rule and the new rule read **Part revoked** from the stored rows. The current values (FEPA Revoked; DPA and CSR In force) came from elsewhere, probably the legacy import, so the guard kept them as "conflicts".

The guard now also changes `live` when **both rules agree** on a value that differs from the current one. The change-log reason notes that the legacy value was replaced, and the evidence carries `replaced_legacy_live`. A conflict is now only where the rules disagree with each other *and* with the current value.

Re-run of batch 0: 3 changes, **0 conflicts**:
- FEPA 1985 (Making): Revoked → Part revoked;
- DPA 2018 and Confined Spaces Regs 1997 (Making): In force → Part revoked.

Snapshot `live_status_snapshot_20260928_1402_b0`. Snapshot names now carry the time, so same-day re-runs don't collide.

## Live-fix enrichment (2026-09-28)

Fractalaw ran the full pipe on the 8 Making laws that the live fix brought out of Revoked, and published with provenance. Log: `~/fractalaw/data/qq-readiness/livefix/LIVEFIX-publish-log.md`.

Verified against `live_fix_*_snapshot_20260928`:
- all 8 `is_making` true→true (3,623 total unchanged), verdict making;
- the Making source is now enrichment, including for Forestry 1967, FEPA 1985 and Special Waste 1996, which previously rested on legacy sources;
- significance: HIGH for REACH, DPA 2018 and Dir 98/24; MEDIUM for the rest;
- 5,902 provision rows enriched today, and 0 previously enriched rows lost;
- 24 enriched events (taxa, fitness and significance × 8), **all against the current lat_hash**. The four July-enriched laws now have a hashed trail;
- the only unenriched rows are `section` rows (structural; e.g. 220 in DPA 2018).

Leftover: the Making funnel still shows `enrich` for FEPA, Forestry, Special Waste and DPA 2018. `has_fitness` is generated from `fitness_mention_count`, and these laws have `compiled_applicability` but no fitness mentions. This is the readiness session's carried item ("has_fitness should derive from compiled_applicability"). The fix touches a GENERATED column under the `uk_lrt` view (INSTEAD OF triggers), so it gets its own change.

## Tier 1 dry runs (2026-09-28)

| Batch | Cached | Rows matched | Extent changes | live changes | needs_application |
|---|---|---|---|---|---|
| 1a OH&S + FIRE | 475 | 884/965 | 37 | 10 | 16 |
| 1b Waste + Water | 880 | 766/840 | 98 | 7 | 24 |
| 1c Env protection, pollution, air, noise | 895 | 677/718 | 104 | 14 | 79 |
| 1d Climate + nuclear | 424 | 310/331 | 22 | 1 | 4 |
| 1e Public + transport safety | 690 | 999/1,091 | 19 | 5 | 5 |

- **live changes (37):** mostly Revoked → Part revoked (EU law and NI Acts such as the Factories Act (NI) 1965 and the HSW (NI) Order 1978), plus 7 PPC (Designation) (England and Wales) Orders that become revoked in E and in force in W (title marker, territorial application E).
- **Part → Revoked (9):** all genuine and superseded. They are NI regulations revoked with savings by later NI regulations (Control of Asbestos (NI) 2007, H&S Fees (NI) 2010, water/WFD/EIA (NI), Nitrates (NI) 2014), the Prevention of Oil Pollution Act 1986 (repealed by the Merchant Shipping Act 1995), and PPC Designation 2019. Their legacy rows were unreadable to the old rule.
- **Fix found:** `affected_effects` took a single provision's extent as the law's (PUWER 1992: 1 of 12 effects). Now: whole-instrument AffectedExtent first, else provision extents only when ≥ 3 effects carry them, which removes 24 changes. PUWER's remaining "E+N.I." is on its own whole-instrument revocation effect (a legislation.gov.uk editorial quirk) and has no live impact (it stays Revoked).
- **archive61:** 3 of fractalaw's hub-archived laws (PPC Designation 2015/1352, 2016/150, 2016/398) become "Revoked in E; in force in W". Fractalaw must restore them after apply.

## Tier 1 applied (2026-09-28)

For each batch 1a–1e: `apply_effects --apply` (1,630 laws' revocation rows enriched, 280 extents), then `application --parse` (128 laws LAT-parsed, 119 not-Making discarded with archive), then `recompute --apply` (37 changes as previewed).

Bugs found in the results and fixed:
- **Parent bound counted as evidence when it didn't narrow.** A UK Act over a legacy UK extent made the result "determined". Now `+parent` applies only when the bound narrows.
- **`lat_provisions` took a single coded provision as the law's extent.** HASS 2005: 1 of 92 → "NI". Now ≥ 3 coded provisions are required (`lat_coded_provisions`). HASS 2005's extent was restored to UK, with a change-log entry.
- **Undetermined results kept the current value, and `finish` checked "current == decided" first**, so hook-written Part revoked results stuck. Now `needs_application` holds at the context-free old-rule status and is checked first. It's logged, and the CSV lists it.

After the corrected recompute, 28 laws are held (`needs_application`). 20 of them went back from the hook's spurious "in force in NI/S" to Revoked: CDM 1994, CHIP 1994/1997/2008, Construction (HSW) 1996, Ionising Radiation (Medical Exposure) 2000, the Nitrate Sensitive Areas (Amendment) regs, and others. All are GB regimes revoked in full.

**Open question: the parent bound.** Its extent is the Act's union of provision extents. The Water Resources Act 1991 is recorded as GB although its main powers are E+W, so the Surface Waters Regs 1994/1996/1997 read "in force in S", probably spuriously. Proposal:
- the parent bound can narrow a law's regions, but it is not a determination;
- for held laws with an unsourced (legacy) extent, run the LRT metadata/extent stages to source the extent (law-level RestrictExtent), then recompute. This is LRT's own data, not full text.

archive61: 6 are now not fully Revoked. The PPC Designation orders 2015/1352, 2016/150 and 2016/398 (title "(England and Wales)", revoked in E) are solid. The Surface Waters regs 1994/1057, 1996/3001 and 1997/2560 are doubtful (parent-bound only).

## Proper extent vs legacy values (2026-09-28)

Jason: the key is getting the proper extent rather than using legacy values.

- **Parent-Act bound:** it narrows a law's regions but never determines alone, because it's the union of all the Act's provision extents. Applied: T&CP (Trees) Regs 1999 (batch 0) and the 4 Surface Waters (…) (Classification) Regs (1b) are held at Revoked (`needs_application`). 1,965 tests pass.
- **Unsourced extents are the unrevised laws.** A trial of the LRT metadata + extent stages on 15 unsourced Tier 1 laws (including the Surface Waters regs, Special Waste (Amendment) 1997 and T&CP (Trees) 1999) found every one `document_status = final`. legislation.gov.uk's law-level extent for an unrevised document is only the "E+W+S+N.I." placeholder, which ExtentResolver rightly ignores. A metadata re-scrape therefore gives nothing for them, and the re-scrape module was dropped. Unsourced by tier: 0: 110, 1: 1,441, 2: 6,887.
- **Where a proper extent can come from for unrevised laws:**
  1. an extent clause in the text (LAT, `text_clause`, already read);
  2. editorial `AffectedExtent` on effects (≥ 3 or whole-instrument; done);
  3. **proposed: the enabling sections.** The SI's preamble ("in exercise of the powers conferred by sections 82 and 219(2) of the Water Resources Act 1991") names them. Their extents come from the parent Act's LAT `extent_code` (parents are Making and hold LAT with per-provision extents). This is read in the same LAT pass as the application clause and is precise, unlike the whole-Act bound. `enacted_by_meta` holds only the Act, not sections.

## Enabling provisions (2026-09-28/29)

Jason: build the enabling-section extent.

Found along the way:
- The **LAT parser didn't inherit extent**. A provision without its own RestrictExtent took the document root's extent, not its nearest ancestor's: WRA 1991 Part III is E+W, but s.82 got E+W+S. Fixed. Parallel-provision detection is now keyed on schedule + provision, since a body reg. 1 is not a schedule para. 1. Existing LAT stays wrong until re-parsed.
- The SI preamble is not in LAT. The LRT enacted_by stage already fetches it (the introduction, not the body), so enabling provisions are parsed there.

Built:
- `EnactedBy.EnablingProvisions` (pure): parses the powers clause for sections and schedules per parent, resolving markers via the url map and matching by year.
- `enabling_provisions` JSONB, written by the enacted_by stage.
- `EnactedBy.EnablingExtent` (parent LAT extent_code, all-or-nothing).
- `ExtentResolver` source `enabling_provisions` (rank 5). It is a **ceiling**: intersected with a devolved type's floor; an empty intersection gives no verdict.
- `mix live.enabling --batch N [--apply]`.

Batch 0 results:
1. 162 SIs had no proper extent source; enabling provisions were parsed for 107, citing 67 parents (39+ with LAT).
2. **Parents re-parsed** (42 laws, `lat_reparse_enabling_parents_b0`):
   - 1,462 section_id renames, from corrected parallel qualifiers, with enrichment carried; they are logged for fractalaw's rename queryable.
   - 50,195 of 50,220 enriched rows carried; **25 need re-enrichment** (changed/dropped text: FSA 1990 17, CDPA 1988 4, Radioactive Substances Act 1993 3, anaw 2017/2 1).
3. **First apply** treated the enabling union as the extent. It widened SSIs (S → GB/UK/E+W), which was wrong because the provisions are a ceiling. All 54 were restored from `enabling_b0_snapshot_20260929` and re-applied with the ceiling fix.
4. Final: 23 extents sourced, all legacy UK SIs narrowed: UK → GB 14, UK → E+W 6, UK → S 2 (pre-devolution "(Scotland)" SIs under Scottish Acts), ∅ → E+W 1.
5. live: **T&CP (Trees) Regs 1999: Revoked → Revoked in E; in force in W** (T&CP Act 1990 ss.199, 212, 316, 323 and 333 are all E+W). Batch 0 recompute: 0 held, no further changes.

## Tier 1 enabling dry run (2026-09-29)

2,390 SIs have no proper extent source (1a 301, 1b 653, 1c 615, 1d 331, 1e 490). Enabling provisions parsed for 1,323 of them, citing 194 parents:
- **78 hold LAT:** re-parse with the extent-inheritance fix; preview first;
- **25 are Making without LAT:** LAT parse and keep. They include MSA 1995 (50 SIs), Finance Act 1996 (32), Water Environment and Water Services (Scotland) Act 2003 (20), Water Services etc. (Scotland) Act 2005, Water Industry (Scotland) Act 2002, Reservoirs (Scotland) Act 2011 and Landfill Disposals Tax (Wales) Act 2017;
- **89 are not Making without LAT:** scoped LAT of the cited sections under #166 (not a cache);
- 3 are not in the register.

The Climate Change Act 2008 (UK_ukpga_2008_27) already holds LAT (891 rows, Making).
