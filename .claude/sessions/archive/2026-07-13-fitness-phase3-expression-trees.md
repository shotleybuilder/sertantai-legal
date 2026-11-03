---
session: "Phase 3 — Compiled applicability expression trees"
project: sertantai-legal
status: closed
opened: 2026-07-13
closed: 2026-07-13
outcome: success
commits: [b40e88e]

summary: >
  Built compiled applicability expression tree evaluator. Schema column (jsonb),
  TaxaSubscriber decoder, recursive tree walker with 6 node types, territorial
  hierarchy expansion. Tested against 4 benchmarks and full 585-law corpus.
  Employer in Scotland matches 171 laws (up from 148 without hierarchy).

decisions:
  - what: Store compiled_applicability as jsonb (not text)
    why: Trees are JSON objects evaluated at query time. jsonb enables future PostgreSQL-side queries and indexing without re-parsing.
    result: 694 laws with trees, avg 516 bytes, max 5.8KB
  - what: Expand territorial hierarchies in the evaluator, not in the profile
    why: Hierarchy is a static property of the dimension, not the customer. Expanding at eval time means profiles stay clean and hierarchies can be updated without re-saving profiles.
    result: Scotland 148→171 (+23 laws matching great_britain/united_kingdom)

metrics:
  corpus: { laws_with_trees: 694, making_with_trees: 585, avg_tree_bytes: 516, max_tree_bytes: 5852 }
  evaluation: { employer_scotland: 171, employer_england: 192, employer_ni: 134, employer_wales: 183 }
  hierarchy_gain: { scotland: 23, description: "laws matching great_britain or united_kingdom" }

lessons:
  - title: "put_json_field only accepted lists — maps were silently dropped"
    detail: >
      The TaxaSubscriber's put_json_field helper had `when is_list(parsed)` guard on
      Jason.decode result. compiled_applicability is a JSON object (map), not array.
      Maps were silently dropped — no error, just null in the DB. Fixed by adding
      `when is_map(value)` clause and `is_map(parsed)` to the decode guard.
    tag: zenoh
  - title: "Pipe operator reverses argument order for expand_codes"
    detail: >
      `Map.get(profile, dim, []) |> expand_codes(dim)` passes codes as first arg
      and dim as second — but expand_codes dispatches on dimension as first arg.
      Error was "Enumerable not implemented for BitString" because the string
      dimension was passed where a list was expected. Use explicit call order.
    tag: tooling
  - title: "Tree quality is a fractalaw concern, not an evaluator concern"
    detail: >
      Initial benchmark trees returned false for all profiles due to And'ing
      AppliesTo and DisappliesTo mentions together. Two rounds of QA prompts
      to fractalaw were needed: (1) Or for applies, Not(Or) for disapplies,
      (2) drop provision-level disapplies that contradict applies codes.
      The evaluator was correct throughout — it faithfully evaluates whatever
      tree it receives.
    tag: data

artifacts:
  - backend/lib/sertantai_legal/fitness/applicability_evaluator.ex
  - backend/priv/repo/migrations/20260713120001_add_compiled_applicability.exs
  - backend/lib/sertantai_legal/legal/legal_register.ex
  - backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex

depends_on:
  - 2026-07-13-fitness-rules-engine.md
  - 2026-07-13-fitness-schema-migration.md

enables:
  - Customer screening using tree evaluation instead of entity overlap scoring
  - Per-provision expression trees (when fractalaw publishes them)
  - Additional hierarchy dimensions (SIC codes, HSE activities)
---

# Title: Phase 3 — Compiled applicability expression trees

**Started**: 2026-07-13

## Todo
- [x] Add compiled_applicability column to legal_register (migration + view/trigger rebuild)
- [x] Accept compiled_applicability in TaxaSubscriber Arrow IPC decoder (put_json_field)
- [x] Build recursive tree evaluator (Match, And, Or, Not, Conditional, TimeWindow)
- [x] Test evaluator against 4 benchmark laws from fractalaw — trees evaluate correctly
- [x] Fix put_json_field to accept maps (not just lists) — compiled_applicability is a JSON object
- [x] Identified tree quality issue: DisappliesTo mentions too broad (fractalaw fix needed)
- [x] Territorial hierarchy expansion (scotland → great_britain → united_kingdom)

## Notes
- Fractalaw publishes compiled_applicability as Utf8 (JSON string) in taxa enrichment Arrow IPC
- 701 laws have trees, tree size 200B–5KB JSON
- Node spec in docs/zenoh/ZENOH-SPEC.md v2.3
- Evaluator reference in docs/controls/FITNESS-APPLICABILITY.md
- TimeWindow node has no inner field in ZENOH-SPEC v2.3 (just from/to) — differs from FITNESS-APPLICABILITY.md
