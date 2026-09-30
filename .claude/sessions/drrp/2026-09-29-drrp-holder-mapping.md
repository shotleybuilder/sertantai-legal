---
session: "Provision DRRP by holder + implied Rights (fractalatai #67)"
status: closed
opened: 2026-09-29
closed: 2026-09-29
outcome: success
related: [141, "fractalatai#67"]
depends_on: ["2026-09-27-enrichment-readiness"]
enables: ["drrp/2026-09-30-drrp-spec-68"]

summary: >
  Legal's Obligation/Liberty → DRRP expansion (ProvisionSubscriber.map_drrp_types/1) took
  any governed actor present as the holder. It now maps by the holder's role: the actor
  with position active, and from fractalatai #67 each actor's own drrp. mix drrp.remap
  corrected 7,678 rows in 417 laws, then 3,917 raw OL rows in 50 laws after the #67
  publish (49 laws, 49,717 provisions, 57 implied Rights in 23 laws). Superseded in part
  by the #68 spec (no active actor = holder unknown).

decisions:
  - what: "Map Obligation/Liberty by the holder (position active), not role presence"
    why: "EPA 1990 s.20(7): an enforcing authority's duty to the public was typed a Duty because a governed actor was present"
    result: "Governed holder → Duty/Right, government holder → Responsibility/Power; both roles → both, never cross-assigned (Jason)"
  - what: "Per-actor expansion from each actor's own drrp once #67 ships it"
    why: "A provision-level union can't say which actor holds which type"
    result: "8fba7bc; the fallback to all active actors stays for actors without a drrp"

lessons:
  - title: "Remap tooling pays for itself"
    detail: "mix drrp.remap (dry run, snapshot, apply, re-run finds 0) let every later mapping change be applied and verified in minutes"
    tag: tooling

bugs:
  - pattern: "Provision OL→DRRP mapping took any governed actor present as the holder: an Obligation/Liberty held by the government (governed counterparty) became Duty/Right (EPA 1990 s.20(7); legal #141 → fractalatai #67)"
    category: drrp_mapping
    module: zenoh/provision_subscriber.ex map_drrp_types/1
    affected: "7,678 provision rows in 417 laws"
    fix: "Map by the role of the actor(s) with position active; both roles → both types; remapped by mix drrp.remap (snapshot drrp_remap_snapshot_20260929_1416)"
    status: fixed
---

# Session: Provision DRRP by holder + implied Rights (CLOSED)

Split out of `2026-09-27-enrichment-readiness.md` on 2026-09-30.

## Problem

Jason confirmed the model: an Obligation on the governed is a Duty, on the government a Responsibility; a Liberty on the governed is a Right, on the government a Power. Legal holds the expansion (`ProvisionSubscriber.map_drrp_types/1`, #134), but treated "any governed actor present" as the holder.

## Todo

- ✅ Map by the actors with `position: "active"` (5d67753). `mix drrp.remap --apply` corrected 7,678 rows in 417 laws: Duty → Responsibility 3,502, Right → Power 2,550, Duty → Duty + Responsibility 739, Right → Right + Power 355, and others. A re-run finds 0.
- ✅ Per-actor mapping from #67's `drrp` (8fba7bc). No active actor fell back to the presence rule (a5c3fa2), which was later removed by #68.
- ✅ #67 publish verified against `implied_rights_*_snapshot_20260929`: is_making unchanged (0 of 49); UK_ukpga_2003_21 s.108(6) = {Right, Responsibility}; **57 implied Rights in 23 laws** (fractalaw's 60 are Liberties: some provisions give two holders); no over-assignment.
- ✅ `mix drrp.remap` covers raw OL rows: 3,917 rows in 50 laws (snapshot `drrp_remap_snapshot_20260929_1521`).
- ✅ Data gaps raised with fractalaw, both resolved under #68 → `drrp/2026-09-30-drrp-spec-68.md`:
  1. 11,981 provisions with Obligation/Liberty but no actors: "holder unknown", kept raw;
  2. 46 provisions whose drrp_types union held a type no active actor held: fractalaw now unions active actors only.
