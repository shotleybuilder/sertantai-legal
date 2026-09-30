---
session: "Corpus Enrichment Readiness"
status: active
opened: 2026-09-27
related: ["fractalatai#56", "fractalatai#58", "fractalatai#59", "fractalatai#60", 166, 165]
bugs:
  - pattern: "Provision OL→DRRP mapping took any governed actor present as the holder: an Obligation/Liberty held by the government (governed counterparty) became Duty/Right (EPA 1990 s.20(7); legal #141 → fractalatai #67)"
    category: drrp_mapping
    module: zenoh/provision_subscriber.ex map_drrp_types/1
    affected: "7,678 provision rows in 417 laws"
    fix: "Map by the role of the actor(s) with position active; both roles → both types; remapped by mix drrp.remap (snapshot drrp_remap_snapshot_20260929_1416). Fractalaw #67 will add data for a finer expansion"
    status: fixed
---

# Session: Corpus Enrichment Readiness (ACTIVE)

## Problem

Enrichment runs cost most in spin-up, so the aim is **one large fractalaw batch** that leaves no known reason for another round. Today that isn't possible:
- 2,430 in-force Making laws have no LAT, and 456 uncertain laws have none either;
- 314 Making laws with LAT have no provision enrichment;
- fractalaw fixes #56, #58, #59 and #60 are still open;
- laws enriched while they had sort breaks got scrambled fitness input.

Fractalaw's current list covers only the 101 re-parsed enriched laws, the 2 PDF laws and the 5 hub-only in-force laws. The LAT parse strategy must be agreed with Jason **before** starting.

## Todo

- ✅ `lat_events` table (Ash `LatEvent`, migration `20260927093413`): composite FK `(law_id, country)` → `legal_register`; indexes on law_name/law_id + at, event, run id; unique `(law_id, country, event, op_key)` so there is one event per law per operation.
- ✅ Triggers (parent + both partitions): `trg_lat_a_events_del` fires *before* the stats trigger (pre-delete hash/count) and `trg_lat_z_events_ins` *after* it (final hash). `discarded` only when the law has no LAT left and reason ≠ `reparse`; a missing reason gives `unknown`. `LatPersister` sets `op_id` (unique per call), `reason=reparse`, `source`, `actor` and `app_version`, and **clears the context after its writes**, so a caller's later delete in the same transaction is not taken for a re-parse. Keying on `op_id` (not txid) also keeps events separate inside one transaction. Dev migrated; tests cover parse, batched parse, re-parse, discard with reason/archive_ref, unknown delete, and partial delete / enrichment update (no event).
- ✅ `enriched` events from the TaxaSubscriber: one per provenance family entry (`LatEvent.Provenance.entries/1`, pure), or one blank entry (verdict only, no family/run/hashes asserted) until fractalaw ships `provenance`; housekeeping (empty payload) records `no_obligations`. Failures are logged and never fail the taxa write. A test with a `provenance` column alongside taxa confirms backward compatibility (the named-columns read is unaffected).
- ⬜ Enrichment provenance: store which fractalaw version, run and models produced each enrichment (spec in "Enrichment provenance" below). **Decision (Jason, 2026-09-27): legal builds its side in full against the agreed spec** (`lat_events` family events; TaxaSubscriber reads the `provenance` list column, and tolerates its absence until fractalaw ships), then raises the payload formally. Fractalaw implements after the raise (its capture work is its own issue).
- ✅ NAS archive (`LatArchive`): `archive/2` writes `<nas>/lat-archive/<law>/<lat_hash>.jsonl.gz` (`row_to_json`, all columns incl. enrichment); `discard/3` archives, sets the event context and deletes the LAT + annotations, so the trigger records `discarded` with `archive_ref`. It refuses if the archive fails, unless `archive: false`. The admin `DELETE /api/lat/laws/:law/data` goes through it (`?reason=`, `?archive=false`), and the admin LRT delete dialog now asks for a reason (defaulting to revoked / not_making / admin_action). Tests write to a temp dir (config), never the NAS.
- ✅ Backfill (`mix lat.backfill_events`, idempotent, `backfill_*` sources; live events never touched): 1,049 parsed from LAT sessions (874 laws), 153 parsed from current LAT, 62 discarded `not_making` from cleaned sessions (40 laws), 8 inferred `unknown` discards, 736 enriched from verdicts. **Correction:** `record_change_log` is not a source; the earlier "172 laws" was a text match on words like "relating"/"translation".
- ✅ `making_funnel.lat_evidence` (migration `20260927094454`): `lat_held` | `lat_held_stale_enrichment` | `enriched_then_discarded` | `parsed_then_discarded` | `none`. In-force UK today: **none 14,166** (Making 2,430 + not Making **11,736**) · lat_held 976 (Making 881 + **not Making 95**, candidates to discard under the lean policy) · parsed_then_discarded 33 · enriched_then_discarded 0.
- ✅ LAT parse strategy agreed (Jason, 2026-09-27): start with Tier 0 and go in order, one session per tier: `2026-09-27-lat-tier0-qq.md` → `2026-09-27-lat-tier1-key-families.md` → `2026-09-27-lat-tier2-remaining.md`. The "decide" step (triage/enrichment) waits for fractalaw to be unparked.
- ⬜ Resolve `live` status for the 2,052 UK laws with none, before deciding whether to parse them
- ⏸️ LAT-parse per the agreed strategy: moved into the three tier sessions
- ⬜ Build ONE complete enrichment worklist with a reason code per law: `no_lat_enrichment`, `reparsed_blanked`, `sort_scrambled_fitness`, `fractalaw_56/58/59/60`, `pdf_backlog`, `hub_only_reparsed`
- ⬜ Line the worklist up with fractalaw's fixes (#56 thin trees, #58 actor gaps, #59 law-level fitness roll-up, #60 duties separated from holders) so one batch covers everything
- ⬜ Legal fix: `has_fitness` should derive from `compiled_applicability`, not the stale `fitness_entities` (the funnel `enrich` count is unreliable until then)
- ⬜ Carried from the LAT sync session: 2 control mappings on repealed EPA 1990 s.40(4), s.74(3) (control 4080cd6c…); migration `down` for 20260926160743 / 20260926192907 not exercised; id quality (`#n` duplicate ids, EU `art.Article N`)
- ⬜ Jason decisions carried: the 9 revoked laws #58 flipped to Making

## Dependencies

- ✅ LAT quality: merge/gate, sort order 0 breaks, manifest + renames (LAT sync session, closed 2026-09-27)
- ⬜ Fractalaw unparked (Jason) and its diff-apply's first hub sync
- ⬜ Fractalaw #56 / #58 / #59 / #60
- ⬜ Fractalaw provenance capture + `provenance` payload column (after legal raises it; not blocking legal's build)

## Data for the strategy (2026-09-27)

UK `live` status: in force 10,927 (668 with LAT); part-revoked 2,174 (306); revoked 4,642 (4); **no status 2,052** (1); planned 19; newly published 1.

QQ register (651 "yes" laws):

| QQ laws | Count | With LAT | Making | Making with LAT |
|---|---|---|---|---|
| In force / part-revoked | 547 | 460 | 395 | **395** |
| Revoked | 104 | 4 | 25 | 3 |

So every in-force QQ Making law has LAT; the **87 in-force QQ laws without LAT are all not Making**.

In-force + part-revoked laws by Family, largest Making-without-LAT gap first (full table in chat 2026-09-27):

| Family | Making | Making without LAT |
|---|---|---|
| OH&S: Occupational / Personal Safety | 143 | 3 |
| FIRE | 24 | 1 |
| FIRE: Dangerous & Explosive Substances | 32 | 0 |
| ENVIRONMENTAL PROTECTION | 131 | 79 |
| WASTE | 117 | 78 |
| WATER & WASTEWATER | 140 | 95 |
| CLIMATE CHANGE | 99 | 56 |
| POLLUTION | 48 | 32 |
| AIR QUALITY | 34 | 22 |
| NUCLEAR & RADIOLOGICAL | 54 | 35 |
| AGRICULTURE / FISHERIES / HARBOURS & SHIPPING / ENERGY / WILDLIFE / ANIMALS | 150–190 each | 145–190 each |
| (no family) | 191 | 158 |

## LAT retention (agreed 2026-09-27)

LAT is kept **only for Making laws**, to keep the table lean. A not-Making verdict is often reached by parsing LAT (and perhaps enriching it), then deleting the LAT. That history was not captured in a queryable form:
- `legal_register` records *why* a law is not Making (source, reason, verdict, review) but not whether LAT evidence was used and then discarded.
- The parse → decide → delete trail lives only in the LAT session log (funnel stage `cleaned`: 33 laws) and as free text in `record_change_log` (172 laws). Admin or bulk deletions outside a session leave no trace.

Decision (Jason, 2026-09-27):
- ~~JSONB `lat_history` on `legal_register`~~, changed after Gemini review 2026-09-27 (`backend/data/code-reviews/2026-09-27-lat-history-{brief,review}.md`): a **separate `lat_events` table**, with events written by DB triggers (so every path is covered) and a **NAS archive** of discarded LAT (Jason agreed).
- Include **enrichment run against LAT since deleted**: it is the strongest not-Making evidence and means "don't re-enrich".

QQ's 87 in-force laws without LAT, all not Making:
- 26: triage with LAT parsed then cleaned (evidenced)
- 4: reviewed not Making (evidenced)
- 4: detector with a LAT session, LAT since gone (partial)
- **45: legacy flag only; 8: detector only (no LAT evidence)**

### `lat_events` design (agreed 2026-09-27)

```
lat_events
  id            bigserial PK
  law_id        uuid        ─┐ FK → legal_register (id, country); partitioned parent
  country       text        ─┘
  law_name      text        (denormalised, for queries / fractalaw)
  event         text        parsed | enriched | discarded   (check constraint)
  at            timestamptz default now()
  source        text        lat_session:<id> | workflow_api | admin | cleanup | reparse | trigger | backfill_*
  actor         text        user:<id> | system:<name>
  app_version   text        git sha at parse time (parsed)
  lat_hash      text        content hash at the event
  struct_hash   text
  row_count     int
  reason        text        discarded: not_making | revoked | superseded | out_of_scope | admin_action | unknown
  verdict       text        enriched: making | no_obligations | empowering
  enrichment_run_id / enrichment_version  text  (enriched, when fractalaw sends them)
  archive_ref   text        discarded: NAS path of the archived LAT
  indexes: (law_id, at DESC), (law_name, at DESC), (event), (enrichment_run_id)
```

Write paths:
- **parsed:** the INSERT trigger on `legal_articles` (statement-level; one event per law per statement), reading `sertantai.lat.source` / `actor`.
- **discarded:** the DELETE trigger. `reason = reparse` is skipped (a merge re-parse replaces rows; the INSERT trigger logs `parsed`). A missing reason logs `unknown`.
- **enriched:** the TaxaSubscriber (application), with the hashes enriched against.
- **archive:** the delete paths call the archiver *before* deleting (the trigger cannot write to the NAS) and pass `archive_ref` via `SET LOCAL`.

Gemini points not adopted: a BIGINT law id (ours are UUIDs on a country-partitioned table); replacing the one big enrichment batch with per-law event-driven runs (the batch is deliberate because of pod spin-up cost; small changes already flow through fractalaw's manifest watch).

### Enrichment provenance (planned 2026-09-27; fractalaw reviewed the same day; raise formally after `lat_events` is built)

Why: fractalaw has several enrichment families and models, but law level in legal records only a verdict and a time. Without provenance we can't tell what a model upgrade makes stale, target laws enriched by weak tiers, or explain a verdict.

**Payload (fractalaw's preferred carrier):** one additive `provenance` JSON column in the existing law-level taxa payload, holding a **list of per-family entries**. A full publish carries several families (`--fitness-only` carries one), and keeping provenance in the same message keeps it atomic with its data. Legal's TaxaSubscriber reads named columns only, so the addition is backward compatible (add a test when built). Each entry:
- `family`: `triage` | `taxa` | `fitness` | `significance`
- `enrichment_run_id` (uuid), `run_started_at`, `fractalaw_version` (git sha)
- `enriched_against`: {lat_hash, struct_hash} **that this family's stages actually read**. Fractalaw's current `lat_sync_state` hash is not enough: a family's enrichment can predate the current text.
- `stages`: per stage run, {method, model, model_version, prompt_version?, ran_at}
- `provision_method_counts` for the family

**Stages by family** (fractalaw's actual pipeline):
- **triage** (its own family: Pass 1 regex making-detection at sync, before enrichment)
- **taxa:** parse (regex: scope incl. amendment, purposes, DRRP, actors, duty family/sub-type, POPIMAR, clauses) → dependency features (spaCy) → embed (ONNX, 384-dim) → classify (DRRP/position classifiers, versioned weights e.g. v8/v3) → infer (Hohfeldian correlatives) → SLM (RunPod) → LLM / agentic → **reconcile** (per-actor tier precedence) → derive_hierarchy → **law-level DRRP roll-up** (#55). Reconcile and the roll-up produce the verdict legal receives.
- **fitness:** extract (regex polarity + dictionaries) → SLM entity extraction (fine-tuned `gemma3-fitness`) → **propagate** (law-scope mentions to provisions) → reconcile (ft > regex > slm) → application (nations, extent fallback) → compile (expression trees)
- **significance:** provision scoring (SLM: scope / gravity / strength / hierarchy) → law-level roll-up (Approach L), whose **method version includes the frozen thresholds** (LOW ≤ 6.14, HIGH ≥ 11.06)

**Per-provision method counts:**
- **Taxa:** from fractalaw's `provision_actors.extraction_method` (the reconciled truth, per actor), **not** legal's provision-level `extraction_method` (mostly the parse tier). Hub, 2026-09-27: slm 134,301 · regex 30,384 · llm 2,449 · inferred 1,997 · agree 1,619 · pending_llm 1,092 · classifier 360 · pending_slm 310. Legal's `actors` maps carry no per-actor method, so legal can't compute this itself. ~~Legal's "81% regex-only" was the wrong field.~~
- **Fitness:** per mention (tier columns regex/slm/ft/llm, `source_detail` e.g. `gemma3_fitness_finetuned`, extraction_method regex | propagated): cheap to publish.
- **Significance:** none per provision (only `significance_confidence`, on 35,256 of 54,958 rated); needs fractalaw work.

**Fractalaw work needed first** (its own issue, when raised):
- Nothing records a run id today, and no git sha is built in.
- Model versions are implicit (weight filenames, pod-script SLM tags, prompts in code).
- Provenance must be **captured when each stage runs** (per law, per family), not reconstructed at publish time. Rough work: embed the git sha at build, add a runs table, write per-law/per-family provenance (run id, lat_hash read, stage → method/model/version) as stages run.

**Legal storage:** `lat_events` gets one `enriched` event per family entry: `family`, `enrichment_run_id` and `enrichment_version` as indexed columns (e.g. "everything from run X", "significance before version Y"), and `stages` + counts as `provenance jsonb`.

**Uses:** a per-family `model_upgrade_stale` worklist reason; targeting laws with high regex / pending_slm / pending_llm shares (taxa, per actor); per-law verdict explanation.

## Draft LAT parse strategy (to agree)

0. **Goal per law:** a Making law **holds LAT**; a not-Making law has an **evidenced** verdict (`lat_evidence` ≠ `none`, or a review), not LAT. Weak not-Making verdicts (legacy / detector only) get parse → decide → discard (LAT not retained).
1. **Exclude** laws confidently no longer in force: `live` Revoked / Repealed / Abolished (4,642). Laws with no `live` status (2,052) are neither in nor out: resolve their status first, don't parse blind.
2. **Tier 0 — QQ register full cover:** every in-force QQ law is either Making with LAT (395/395 already) or not Making with evidence. That leaves the 53 legacy- or detector-only QQ laws (plus the 4 partial) to parse → decide → discard.
3. **Tier 1 — key families:** OH&S (all), FIRE (all), ENVIRONMENTAL PROTECTION, WASTE, WATER & WASTEWATER, POLLUTION, AIR QUALITY, CLIMATE CHANGE, NOISE, NUCLEAR & RADIOLOGICAL, PUBLIC: Building Safety / Consumer Safety, transport *safety* families. Making laws without LAT: parse and keep. Not-Making / uncertain laws without evidence: parse → decide → discard.
4. **Tier 2 — the remaining families**, largest Making gap first, as capacity allows before the enrichment batch.
5. Large Acts: whole-body parse unless Jason sets a #166 scope. PDF-only laws go to the backlog.

## Provision DRRP by holder (2026-09-29)

Jason confirmed the model: an Obligation on the governed is a Duty, on the government a Responsibility; a Liberty on the governed is a Right, on the government a Power. Legal holds the expansion (`ProvisionSubscriber.map_drrp_types/1`, #134). It had treated "any governed actor present" as the holder, and now maps by the actors with `position: "active"` (5d67753). `mix drrp.remap --apply` corrected 7,678 rows in 417 laws: Duty → Responsibility 3,502, Right → Power 2,550, Duty → Duty + Responsibility 739, Right → Right + Power 355, and others. A re-run finds 0.

Next: fractalaw is expanding fractalatai #67 to publish the data legal needs for a more accurate OL → DRRP expansion (Jason is driving it); legal's mapping will then be tweaked. Whether to model the public's correlative Right is still open (Jason).

## fractalatai #67 publish: implied Rights (2026-09-29)

Fractalaw now puts a per-actor `drrp` (Obligation | Liberty | none) on each provision actor, and infers a Liberty for the Public / Ind: Person where a government actor's active Obligation grants access (inspection, copies, supply). Legal maps per actor (8fba7bc). When no actor is active it falls back to the presence rule (a5c3fa2). Published: 49 laws, 49,717 provisions.

Verified against `implied_rights_*_snapshot_20260929`:
- is_making is unchanged (0 of 49);
- UK_ukpga_2003_21 s.108(6) = {Right, Responsibility};
- **57 implied Rights in 23 laws** (fractalaw expected 60);
- no over-assignment where active actors carry a per-actor type.

`mix drrp.remap` covers raw OL rows too: 3,917 rows in 50 laws remapped (snapshot `drrp_remap_snapshot_20260929_1521`).

Data gaps raised with fractalaw:
1. 11,981 provisions carry Obligation/Liberty with **no actors** (2,863 in the 49 laws, 9,118 in 390 others), so no holder can be typed and they stay raw;
2. 46 provisions whose drrp_types union includes a type no active actor holds. Legal falls back, adding Responsibility or Duty.

## DRRP spec agreed: legal aligned (2026-09-30)

fractalaw's `docs/architecture/DRRP-CLASSIFICATION.md` (fractalatai #68, fractalaw 5df3f8e) is agreed. It took legal's three amendments: holder class from the actor dictionary, the verdict as one input to `Legal.Making`, and no active actor = holder unknown (Jason). It also drops `Rule`.

Legal now follows it (af431c5 + this commit):
- no active actor → raw Obligation/Liberty (the presence rule is gone);
- `Spc: Notifying Authority` is government;
- Making needs Duty/Responsibility, and raw OL gives no enrichment or legacy verdict;
- legacy `Rule` → Obligation (holder unknown).

`mix drrp.remap --apply`: 16,659 rows in 500 laws, plus 89 laws' `duty_type` Rule → Obligation. Snapshots: `drrp_remap_snapshot_20260930_0900` (+ `_lrt`).
- About 15,000 rows reverted to raw because no actor is active. 1,471 of them are older payloads with null `actors` (flat lists only).
- 106 rows re-stamped actor roles (Notifying Authority).
- A re-run finds 0. `is_making` is unchanged (3,623).

Docs: FUNCTION_VALUES rewritten. Obligation content is derived, not stored in `function`; `is_making` comes from the resolver tiers; there is no LAT pruning (#110); Housekeeping ↔ no_obligations. HOLDER_VALUES and PURPOSE_VALUES link to the spec.

Hub Postgres (fractalaw-pg.service, :5433) was down after the power outage and has been restarted. Its quadlet has no `[Install]`, so it won't start on boot.

Open: #69 (provision_function), #70 (Immunity, needs Jason). fractalaw conformance is still to do: active-only roll-up, and `none` for non-active actors.

## #68 republish verified (2026-09-30)

fractalaw republished 685 laws (the 20 benchmark laws excluded) with the active-only roll-up and the holder-unknown shape. Snapshots were taken first: `drrp68_lrt_snapshot_20260930_1141`, `drrp68_provisions_snapshot_20260930_1141`.
- All 29 changed verdicts match fractalaw's list (`fractalaw/data/audit/drrp68_changed_verdicts_20260930.tsv`). is_making went from 3,623 to 3,604.
- 13 holder-unknown laws: verdict cleared, raw Obligation kept.
  - 4 are held Making by human review.
  - 8 now rest on the detector. UK_uksi_2004_701 and UK_uksi_2013_755 dropped to not Making.
  - 1 (UK_uksi_2009_3155) is on the default tier.
- 250,541 provisions updated; 0 non-active actors carry a drrp; the old null-actor DRRP rows are cleared.
- Payload gaps raised with fractalaw:
  1. 5,659 republished rows keep pre-#67 actors because the payload's actors was NULL (43 raw rows show an "active" stale actor). Asked fractalaw to send `[]`. Not remapped.
  2. 75,139 rows in these laws weren't republished; 557 of them keep old types.
- For Jason to review: the holder-unknown laws resting on the detector or default tier, and the questionable not-Making verdicts (Hedgerows Regs 1997, NI Explosives HIPS Regs 2009, Waste Management Regs 2006).
