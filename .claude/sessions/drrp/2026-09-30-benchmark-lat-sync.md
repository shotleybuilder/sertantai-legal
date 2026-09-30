---
session: "Benchmark laws: LAT gap and resync (fractalaw gold labels)"
status: closed
opened: 2026-09-30
closed: 2026-09-30
outcome: success
related: ["fractalatai#62", "fractalatai#65", "fractalatai#68"]
depends_on: ["drrp/2026-09-30-drrp-spec-68"]

summary: >
  9,714 rows legal holds in 14 of fractalaw's 20 benchmark laws were never sent. Not a
  scope question: the #62 LAT sync reports on benchmark laws but never applies to them.
  Jason approved syncing all 20 with a gold-label safeguard (snapshot, carry forward
  cosmetic changes as adjudicated, queue substantive changes for review). Legal verified
  every row: 27,428 updated, 20/20 Making, 0 stale types.

decisions:
  - what: "Don't clear the rows as out of scope in legal"
    why: "Legal is the LAT source and none of the laws is scoped; clearing would hide a gap in key laws (Water Industry Act 1991, Wildlife and Countryside Act 1981, EPA 1990)"
    result: "fractalaw resynced its LAT instead"
  - what: "Protect gold labels across the sync"
    why: "Syncing clears classifications on changed rows, and those are hand-checked"
    result: "Snapshot benchmark_gold_snapshot_20260930; 191 carried as adjudicated; 169 queued for Jason (83 + 86); 201 archived; 887 legacy-id labels never matched"

lessons:
  - title: "Row-count gaps against legal's lat_count point to sync, not scope"
    detail: "Compare the hub's rows with legal's lat_count and lat_scope before accepting 'out of scope'"
    tag: process
---

# Session: Benchmark LAT gap and resync (CLOSED)

Split out of `2026-09-27-enrichment-readiness.md` on 2026-09-30.

## Todo

- ✅ Diagnose: legal has no `lat_scope` on these laws and lat_count matches its rows (UK_ukpga_1991_56: 8,288 vs the hub's 809). The gap is fractalaw's.
- ✅ Four large laws synced first (UK_ukpga_1991_56 +7,522, UK_ukpga_1981_69, UK_uksi_2014_1643, UK_ukpga_1990_10): all 11,622 legal rows republished; re-parsed; all four Making by enrichment. 40 Wildlife Act rows held on fractalaw's side for manual matching.
- ✅ Other 16 synced: 19 rows text-changed, 46 inserted, 2,070 archived (per-extent copies legal doesn't hold). Classifier tier restored on unchanged rows.
- ✅ Legal verified: all 27,428 rows updated; the 3 stale typed rows reclassified; 0 actors without a drrp key; 0 raw-with-active; 0 non-active drrp; 82 adjudicated provisions; 20/20 Making.
- ✅ Re-score (not comparable with earlier runs): position 54.4% regex / 61.3% classifier; DRRP 88.4% / 87.7%; 1,309 gold actors.

## Handed off

- Jason: 169 gold labels queued for review (`benchmark_gold_review_20260930`, plus 83 for UK_ukpga_1990_10).
- fractalaw: 887 legacy-id gold labels never matched the hub.
