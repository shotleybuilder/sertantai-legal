---
session: "QQ-05: Controlled Vocabulary & Actor Roles"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [132]
---

# Session: QQ-05 Controlled Vocabulary & Actor Roles (PENDING)

## Problem

Tree Match codes are uncontrolled:
- 648 distinct `material` codes, 323 of them used only once.
- Some are non-material codes: `person`, `authority`, `body_corporate`, `licence`, `offence`.
- Synonyms are split across codes: `ship`/`vessel`, `chemicals`/`substances`/`dangerous_substances`, `construction_work`/`building_work`.

Several evidenced QQ roles have no tree code: consignor and consignee, tenant, laboratory, F-gas, lasers or optical radiation, firearms, legionella, vibration, acetylene, confined spaces.

Compliance scrapes the vocabulary from the trees. It needs a published, controlled table instead, for the profile wizard, API validation and the MCP interface.

On QQ's benchmark this is a small lever: only 14 condition misses (material 10, territorial 3, multi 1). It matters more for every other customer and for compliance's product.

## Todo (loose; rewrite on resume)

- ⬜ Build a synonym and dimension map, published with the vocabulary table. Fractalaw emits canonical codes from it (source fix), and the lint reports non-canonical codes.
- ⬜ Publish a `fitness_vocabulary` table (code, dimension, label, definition, synonyms[], law_count) for compliance to read over the shared DB and delta sync.
- ⬜ #132: persist ActorDictionary to a DB table. Map actor-library roles (consignor, consignee, …) to tree personal codes.
- ⬜ Settle the `territorial` vs `locational` question with QQ-04.
- ⬜ Grow the `conditional` dimension beyond `at_work`. Scope this only; it's probably post-v0.1.
- ⬜ Benchmark `legal-05-vocab`

## Dependencies

- ⬜ QQ-03 lint and the fractalaw re-enrichment slot
- ⬜ Compliance v0.1-04a (suspended) consumes the table. Agree the schema with compliance before building.

## Exit criteria

- `material_condition_miss` + `territorial_condition_miss` + `multi_condition_miss`: 14 → ≤ 5.
- Singleton material codes cut by at least half.
- Vocabulary table live and read by compliance.
