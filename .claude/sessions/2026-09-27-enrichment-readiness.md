---
session: "Corpus Enrichment Readiness"
status: pending
opened: 2026-09-27
related: ["fractalatai#56", "fractalatai#58", "fractalatai#59", "fractalatai#60", 166, 165]
---

# Session: Corpus Enrichment Readiness (PENDING)

## Problem

Enrichment runs cost most in spin-up, so the aim is **one large fractalaw batch** that leaves no known reason for another round. Today that isn't possible:
- 2,430 in-force Making laws have no LAT, and 456 uncertain laws have none either;
- 314 Making laws with LAT have no provision enrichment;
- fractalaw fixes #56, #58, #59 and #60 are still open;
- laws enriched while they had sort breaks got scrambled fitness input.

Fractalaw's current list covers only the 101 re-parsed enriched laws, the 2 PDF laws and the 5 hub-only in-force laws. The LAT parse strategy must be agreed with Jason **before** starting.

## Todo

- ⬜ `legal_register.lat_history` (JSONB, append-only event array): `parsed` / `enriched` / `discarded` events with `at`, `source`, `lat_hash`, `row_count`, plus `reason` (discarded) or `verdict` (enriched). Written by every parse, by the enrichment verdict path (TaxaSubscriber) and by every LAT delete path (admin delete, cleanup), which must give a reason. See "LAT retention" below.
- ⬜ Backfill `lat_history` from the LAT session log (`scrape_session_records`: parsed / cleaned), `record_change_log` LAT-deletion entries (172 laws) and existing `making_enrichment_verdict`/`making_enriched_at`
- ⬜ Making funnel: derive `lat_evidence` (`enriched_then_discarded` | `parsed_then_discarded` | `lat_held` | `none`) from `lat_history`
- ⬜ Agree the LAT parse strategy with Jason (draft below, revised for LAT retention)
- ⬜ Resolve `live` status for the 2,052 UK laws with none, before deciding whether to parse them
- ⬜ LAT-parse per the agreed strategy (gated `mix lat.reparse` / workflow API; the PDF-only backlog and #166 scopes are handled as they arise)
- ⬜ Build ONE complete enrichment worklist with a reason code per law: `no_lat_enrichment`, `reparsed_blanked`, `sort_scrambled_fitness`, `fractalaw_56/58/59/60`, `pdf_backlog`, `hub_only_reparsed`
- ⬜ Line the worklist up with fractalaw's fixes (#56 thin trees, #58 actor gaps, #59 law-level fitness roll-up, #60 duties separated from holders) so one batch covers everything
- ⬜ Legal fix: `has_fitness` should derive from `compiled_applicability`, not the stale `fitness_entities` (the funnel `enrich` count is unreliable until then)
- ⬜ Carried from the LAT sync session: 2 control mappings on repealed EPA 1990 s.40(4), s.74(3) (control 4080cd6c…); migration `down` for 20260926160743 / 20260926192907 not exercised; id quality (`#n` duplicate ids, EU `art.Article N`)
- ⬜ Jason decisions carried: the 9 revoked laws #58 flipped to Making

## Dependencies

- ✅ LAT quality: merge/gate, sort order 0 breaks, manifest + renames (LAT sync session, closed 2026-09-27)
- ⬜ Fractalaw unparked (Jason) and its diff-apply's first hub sync
- ⬜ Fractalaw #56 / #58 / #59 / #60

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
- Capture it in a dedicated JSONB `lat_history`, an append-only event list, not a blob and not `record_change_log` (free-form, mixed).
- Include **enrichment run against LAT since deleted**: it is the strongest not-Making evidence and means "don't re-enrich".

QQ's 87 in-force laws without LAT, all not Making:
- 26: triage with LAT parsed then cleaned (evidenced)
- 4: reviewed not Making (evidenced)
- 4: detector with a LAT session, LAT since gone (partial)
- **45: legacy flag only; 8: detector only (no LAT evidence)**

## Draft LAT parse strategy (to agree)

0. **Goal per law:** a Making law **holds LAT**; a not-Making law has an **evidenced** verdict (`lat_evidence` ≠ `none`, or a review), not LAT. Weak not-Making verdicts (legacy / detector only) get parse → decide → discard (LAT not retained).
1. **Exclude** laws confidently no longer in force: `live` Revoked / Repealed / Abolished (4,642). Laws with no `live` status (2,052) are neither in nor out: resolve their status first, don't parse blind.
2. **Tier 0 — QQ register full cover:** every in-force QQ law is either Making with LAT (395/395 already) or not Making with evidence. That leaves the 53 legacy- or detector-only QQ laws (plus the 4 partial) to parse → decide → discard.
3. **Tier 1 — key families:** OH&S (all), FIRE (all), ENVIRONMENTAL PROTECTION, WASTE, WATER & WASTEWATER, POLLUTION, AIR QUALITY, CLIMATE CHANGE, NOISE, NUCLEAR & RADIOLOGICAL, PUBLIC: Building Safety / Consumer Safety, transport *safety* families. Making laws without LAT: parse and keep. Not-Making / uncertain laws without evidence: parse → decide → discard.
4. **Tier 2 — the remaining families**, largest Making gap first, as capacity allows before the enrichment batch.
5. Large Acts: whole-body parse unless Jason sets a #166 scope. PDF-only laws go to the backlog.
