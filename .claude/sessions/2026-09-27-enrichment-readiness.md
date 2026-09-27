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

- ⬜ Agree the LAT parse strategy with Jason (draft below)
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

## Draft LAT parse strategy (to agree)

1. **Exclude** laws confidently no longer in force: `live` Revoked / Repealed / Abolished (4,642). Laws with no `live` status (2,052) are neither in nor out: resolve their status first, don't parse blind.
2. **Tier 0 — QQ register full cover:** the 87 in-force QQ laws without LAT (all not Making).
3. **Tier 1 — key families:** OH&S (all), FIRE (all), ENVIRONMENTAL PROTECTION, WASTE, WATER & WASTEWATER, POLLUTION, AIR QUALITY, CLIMATE CHANGE, NOISE, NUCLEAR & RADIOLOGICAL, PUBLIC: Building Safety / Consumer Safety, transport *safety* families. Open question: all in-force laws in these families, or only Making + uncertain?
4. **Tier 2 — the remaining families**, largest Making gap first, as capacity allows before the enrichment batch.
5. Large Acts: whole-body parse unless Jason sets a #166 scope. PDF-only laws go to the backlog.
