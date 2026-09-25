---
plan: "Fractalaw brief — QQ data readiness (sertantai-legal #161)"
status: active
created: 2026-09-25
for: fractalaw Claude session (~/fractalaw)
from: sertantai-legal QQ data readiness (.claude/plans/qq-data-readiness.md)
---

# Fractalaw brief: QQ data readiness

## Why this matters

- QQ, our test customer, loses its ENHESA legal register on **31 Oct 2026**.
- sertantai-compliance ships v0.1 to QQ around 27 Oct, with feature freeze on 20 Oct.
- The compliance applicability screener is tuned and is now limited by data. Much of that data is fractalaw output:
  - `duty_type`, which decides `is_making`;
  - `compiled_applicability`, the expression trees.
- Legal's data fixes must land by **17 Oct**. Fractalaw is on the critical path: fixes by about **6 Oct**, then one combined re-enrichment.

## Read first

All in `/var/home/jason/Desktop/sertantai-legal/` unless stated otherwise.

- `.claude/plans/qq-data-readiness.md`: the overall plan, metrics and ordering
- `.claude/sessions/qq-data-readiness/2026-09-25-qq-01-making-triage.md`: the Making funnel state of 163 QQ laws
- `.claude/sessions/qq-data-readiness/2026-09-25-qq-03-tree-extraction-fixes.md`: tree defects, lint baseline and per-law lists
- `.claude/sessions/qq-data-readiness/worklists/*.csv`: per-law lists (`01-not-making.csv` has `funnel_state`)
- `docs/zenoh/ZENOH-SPEC.md` (v2.3, tree spec at about lines 720–786) and `docs/fitness/FITNESS-APPLICABILITY.md`
- In fractalaw:
  - `crates/fractalaw-core/src/taxa/applicability.rs` (tree compiler)
  - `crates/fractalaw-cli/src/commands/fitness.rs`
  - `.claude/sessions/fitness/07-13-26-fitness-expression-compiler.md`
  - `.claude/sessions/fitness/07-13-26-fitness-reconcile-publish.md`

Legal's dev DB is `sertantai_legal_dev` on `localhost:5436` (user `postgres`, password `postgres`). Tables: `legal_register` and `legal_articles`. Treat it as **read-only** from fractalaw. Data goes back to legal only through the normal Zenoh taxa publish, which `TaxaSubscriber` stores unchanged. The DB is shared with sertantai-compliance, so changes are visible there straight away.

## Ground rules

- Open a fractalaw session in its own convention, `.claude/sessions/<topic>/MM-DD-YY-slug.md`.
- Keep investigation (T1, T2) separate from fixing (T3). Report findings before changing code.
- Don't touch prod. Commit only in the fractalaw repo. Don't edit the legal or compliance repos.
- Before any re-publish that overwrites trees, legal snapshots `compiled_applicability` (QQ-03). Tell Jason before publishing so the snapshot is taken first.

## Tasks, in order

### T1. Investigate: 37 laws with a tree but no duty types

These laws have LAT, fitness data and a `compiled_applicability` tree, but `duty_type` is empty. Legal's `TaxaSubscriber` then sets `is_making = false`, so they are never screened. We need to know which of these it is, for each law:
- (a) fractalaw confirmed there are no duties;
- (b) the DRRP stage didn't run;
- (c) DRRP ran but the result wasn't published, or was dropped in the Arrow payload;
- (d) DRRP ran and missed duties.

```
UK_ssi_2004_112 UK_ssi_2004_332 UK_ssi_2004_512 UK_ssi_2005_52 UK_ssi_2005_63 UK_ssi_2006_181
UK_ssi_2011_368 UK_ssi_2011_418 UK_ssi_2012_148 UK_ssi_2014_367 UK_ssi_2015_188 UK_ssi_2015_214
UK_ssi_2021_50 UK_ssi_2026_49 UK_uksi_1969_1263 UK_uksi_1998_3111 UK_uksi_2004_2736 UK_uksi_2004_701
UK_uksi_2006_2988 UK_uksi_2008_198 UK_uksi_2014_2366 UK_uksi_2014_2868 UK_uksi_2014_3277
UK_uksi_2015_1360 UK_uksi_2015_1393 UK_uksi_2015_307 UK_uksi_2016_1245 UK_uksi_2016_336
UK_uksi_2017_81 UK_uksi_2018_24 UK_uksi_2021_1315 UK_uksi_2024_49 UK_uksi_2025_140
UK_wsi_2011_971 UK_wsi_2018_721 UK_wsi_2020_1489 UK_wsi_2026_71
```

Several are clearly substantive, e.g. `UK_uksi_2025_140` (Separation of Waste (England) Regs), `UK_uksi_2018_24` (Community Drivers' Hours Offences (Enforcement) Regs) and `UK_uksi_2008_198` (Recording Equipment (Downloading…) Regs). (d) is plausible for those.

**Output**: a CSV with `law_name, finding (a|b|c|d), evidence, fix`, plus a count per finding.

### T2. Spot-check: 8 laws enriched as Rights/Powers only

These are treated as confirmed not Making (Empowering). Check they really have no Duty or Responsibility.

```
UK_ssi_2005_22 UK_ssi_2010_435 UK_uksi_2005_1904 UK_uksi_2006_2950 UK_uksi_2006_3368
UK_uksi_2007_765 UK_uksi_2014_549 UK_uksi_2024_666
```

`UK_uksi_2006_3368`, the Smoke-free (Premises and Enforcement) Regulations, requires managers of smoke-free premises to display no-smoking signs. That's a duty, so "Rights only" looks wrong. `UK_ssi_2005_22` (Waste (Scotland) Regs) is also suspicious.

**Output**: a verdict per law. If DRRP classification is wrong, say whether it's a one-off or a pattern (e.g. duties phrased as "must display" missed).

### T3. Fix: tree compiler defects

Legal will lint each defect before and after the re-enrichment with `mix fitness.lint_trees`, built in QQ-03. Baseline over 546 in-force Making trees:

| # | Defect | Trees | Example | Expected |
|---|---|---|---|---|
| L1 | Duplicate sibling nodes (the same Match repeated under one Or) | common | `UK_asp_2021_4`, `UK_anaw_2017_2` | Deduplicate; flatten single-child And/Or |
| L2 | TimeWindow `to` in the past: an assent or commencement date taken as the end date | 50 | `UK_anaw_2017_2`: `from 2017-04-03`, `to 2017-04-15` | Only emit `to` for a genuine sunset or expiry provision |
| L3 | Not on the law's own jurisdiction | 4 | `UK_asp_2021_4`, UK Withdrawal (Continuity) (Scotland) Act: Not `scotland` | Never disapply the law's own extent |
| L4 | `construction` in the statutory-interpretation sense ("Interpretation and construction") compiled as a material code, including inside Not | 251 / 52 | `UK_asp_2021_4`, `UK_anaw_2017_2` | Drop mentions from interpretation or construction provisions; building sense becomes `construction_work` |
| L5 | Government actors (`secretary_of_state`, `local_authority`, `scottish_ministers`, `welsh_ministers`, `enforcement_authority`, `public_authority`) as applicability conditions | 230 | `UK_anaw_2017_2` | These actors are regulators, not the people the law applies to. Keep them out of gating branches |
| L6 | Generic codes gating (`building`, `land`, `licence`, `body_corporate`, `person`, `offence`, `application`) | 21 QQ misses | see QQ-03 list | **Hold**: ownership (fractalaw vs compliance) not yet agreed |
| L7 | No jurisdiction gate: jurisdiction is nested in Or branches next to place types, or missing | 40 NI laws match a GB-only org | NI laws in `worklists/03-screener-only.csv` (`ni_law = t`) | Put the law's extent at the root as an And gate, with place types in their own branch. Legal is fixing `geo_extent` for 481 devolved laws first (QQ-04), so check with Jason which extent source to use |
| L8 | Territory-only trees (no substantive condition) | 48 | QQ-03 `territory_only_tree` list | Decide whether the law is genuinely universal or a condition was lost |

Also common: whole-law `Not` built from scope exclusions ("does not apply to construction work"). If the compiler can scope a Not to provisions rather than negate the whole law, do it. Otherwise flag it; compliance already treats these as soft caveats.

To fetch a tree:
```
psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "select jsonb_pretty(compiled_applicability) from legal_register where name='UK_asp_2021_4'"
```

**Output**: compiler fixes with tests, plus a before/after count per defect on the fractalaw side.

### T4. One combined enrichment and re-publish (after T3, with Jason)

Force-publish these regardless of fractalaw's own triage verdict. Legal's funnel has already decided they should be enriched.

1. **All 546 existing trees**, re-published with the T3 fixes.
2. **51 QQ-register Making laws with LAT but no enrichment** (QQ-02 bucket b):
   ```
   UK_asp_2003_8 UK_asp_2004_6 UK_eudr_2009_104 UK_eudr_2009_161 UK_eur_2017_548 UK_nisi_2006_1254
   UK_ssi_2004_406 UK_ssi_2009_266 UK_ukpga_1960_30 UK_ukpga_1982_16 UK_ukpga_1990_16 UK_ukpga_1990_8
   UK_ukpga_2000_23 UK_ukpga_2003_20 UK_ukpga_2004_21 UK_ukpga_2006_36 UK_ukpga_2006_38 UK_ukpga_2015_30
   UK_ukpga_2018_12 UK_ukpga_2022_30 UK_uksi_1998_1941 UK_uksi_1999_3106 UK_uksi_2001_1701 UK_uksi_2003_2457
   UK_uksi_2004_1309 UK_uksi_2005_1378 UK_uksi_2008_2164 UK_uksi_2009_3155 UK_uksi_2010_1627 UK_uksi_2010_93
   UK_uksi_2011_1885 UK_uksi_2011_2157 UK_uksi_2012_3032 UK_uksi_2015_1640 UK_uksi_2015_21 UK_uksi_2015_668
   UK_uksi_2016_315 UK_uksi_2016_765 UK_uksi_2017_1013 UK_uksi_2018_1203 UK_uksi_2018_139 UK_uksi_2018_482
   UK_uksi_2018_506 UK_uksi_2018_623 UK_uksi_2019_1115 UK_wsi_2005_1806 UK_wsi_2008_1081 UK_wsi_2009_995
   UK_wsi_2012_1085 UK_wsi_2017_567 UK_wsi_2024_1268
   ```
3. **14 QQ laws with LAT that were never enriched** (QQ-01 state L1):
   ```
   UK_asp_2011_6 UK_eur_2008_307 UK_ssi_2005_658 UK_ssi_2008_221 UK_ssi_2010_434 UK_ssi_2011_226
   UK_ukpga_1933_13 UK_ukpga_1947_41 UK_ukpga_1947_48 UK_ukpga_1947_53 UK_uksi_1986_2128
   UK_uksi_1998_3084 UK_uksi_2018_1155 UK_uksi_2018_1214
   ```
4. **Once legal has parsed their LAT**: 22 QQ no-LAT Making laws (QQ-02 bucket a) and 13 never-queued candidates (QQ-01 state Q1). Legal will send the final list.
5. **`UK_ukpga_1990_9`**, the Planning (Listed Buildings and Conservation Areas) Act: fitness exists (24,430 applies mentions) but no tree was compiled. Find out why (size limit?).

Legal monitors `/admin/zenoh`: TaxaSubscriber Received should equal Updated, and Failed should be 0.

## How results are measured

Legal runs both of these after each publish and posts the numbers on sertantai-legal #161:
- `mix fitness.lint_trees`
- the compliance benchmark (read-only for fractalaw; don't commit in compliance):
  ```
  cd ~/Desktop/sertantai-compliance/backend && mix screener.benchmark --org c075d56b-8420-4408-b695-ccfbc1ba15ec \
    --name qq --label legal-03-fractalaw-fixes --profile-file priv/benchmarks/qq/profile_reviewed.json
  ```

The baseline is `runs/2026-09-25T1107-legal-baseline`: evaluable agreement 68.2%, 262 laws in both, 172 screener-only.

## What to hand back

1. T1 CSV plus counts, and T2 verdicts, as soon as they're ready. These unblock legal's QQ-01 cleanup list.
2. The list of T3 fixes with tests and before/after defect counts.
3. The T4 publish log (laws published, failures).
4. Anything that contradicts this brief. In particular, if fractalaw's triage or DRRP disagrees with legal's funnel state for a law, say so. Don't quietly work around it.

## Legal's TaxaSubscriber contract (added 2026-09-25, QQ-01a)

Legal now decides `is_making` with a precedence resolver (`Legal.Taxa.MakingResolver`), and every write is logged. What this means for what fractalaw publishes:

1. **An enrichment verdict is recorded only when a payload carries non-null DRRP columns** (`duty_type`, `duties`, `rights`, `responsibilities`, `powers`).
   - Null columns are dropped during decoding. A payload with only fitness, tree or significance data gives **no verdict** and leaves `is_making` unchanged.
2. **To say "enriched, no obligations", send DRRP columns as empty lists, not nulls, or send an empty payload (zero rows).**
   - Either one records `no_obligations`, which means not Making.
   - That's the right signal for the 33 T1 "a" laws.
3. **The verdict mapping:**
   - Duty, Responsibility or Obligation entries → `making`.
   - Rights or Powers only → `empowering` (not Making).
4. **Enrichment outranks triage and all legacy data. Only a human `making_review` outranks it.** Publish DRRP built from fresh PG `provision_actors`, never the stale DuckDB aggregates (T2). Otherwise stale data becomes the authoritative verdict.
5. **Triage publishes are recorded as estimates only.** They can't change `is_making` when enrichment or legacy Duty/Responsibility evidence exists.
6. **Policy (Jason):** an amending instrument that inserts duties into a principal Act or SI is **not Making**. For the T1 "e" laws, don't publish Making verdicts: the duties belong to the principal instrument.
7. **Before T4:** tell Jason, so that legal can snapshot `compiled_applicability` and start its Phoenix server with this code. `TaxaSubscriber` isn't running when the server is down, so publishes won't land.
8. **What legal already did from T1/T2.** Historical `duty_type` is no longer treated as enrichment evidence; it only counts as legacy evidence. The UK backfill has been applied: 72 laws became Making, none were downgraded.
