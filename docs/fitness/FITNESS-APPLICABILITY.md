# Fitness Applicability: Sertantai Implementation Guide

**Date**: 2026-07-13
**Source**: fractalaw `.claude/plans/fitness/FITNESS-RULES-ENGINE.md`

## What This Is

Fitness answers: **"does this law apply to this customer?"** Fractalaw extracts applicability data from provision text and publishes it to sertantai. Sertantai evaluates it against customer profiles at query time.

## What Fractalaw Publishes

### New fields in the LRT payload (Zenoh Arrow IPC)

These are published alongside existing DRRP fields. See `ZENOH-SPEC.md` v2.2.

| Field | Type | Description |
|-------|------|-------------|
| `fitness_entities` | `List<Utf8>` | Canonical applicability entity names for this law. Union of all entities extracted from the law's provisions. Examples: `["employer", "England", "construction work", "marine conservation zone"]` |
| `fitness_scope_dimensions` | `List<Utf8>` | Which scope dimensions are present: `personal`, `material`, `territorial`, `temporal`, `conditional` |
| `fitness_mention_count` | `Int32` | Total fitness mentions extracted |
| `fitness_applies_count` | `Int32` | AppliesTo polarity count |
| `fitness_disapplies_count` | `Int32` | DisappliesTo polarity count |

### Coverage

- 654 laws currently have fitness data (of ~19K total)
- These 654 laws cover the QQ customer register (428 laws) plus broader corpus
- Coverage will grow as more laws are processed

### Legacy fields (REMOVED)

`fitness_person`, `fitness_process`, `fitness_place`, `fitness_plant`, `fitness_property`, `fitness_sector`, `fitness` — the old P-dimension model. **Removed from both fractalaw publishing and sertantai schema** (2026-07-13). All code now uses `fitness_entities` + `fitness_scope_dimensions` + `compiled_applicability`.

## What Sertantai Needs To Build

### Phase 1: Store and Display (immediate)

1. **Accept the new columns** in the Arrow IPC decoder for `fractalaw/@dev/taxa/enrichment/{law_name}`
2. **Store on the law record** — five new fields
3. **Display in the law detail view** — show fitness entities and scope dimensions as tags/chips
4. **Filter/search** — allow filtering the law register by fitness entity ("show me all laws that mention marine conservation zone")

### Phase 2: Customer Matching (rules engine)

The rules engine evaluates compiled expression trees against customer profiles. The architecture:

#### Stage 1: Coarse Filter (entity index)

Build an inverted index: for each fitness entity, which laws mention it.

```elixir
# Postgres or ETS — entity → law_names
# Built from published fitness_entities on each law
entity_index = %{
  "employer" => ["UK_uksi_1999_3242", "UK_uksi_2005_1093", ...],
  "marine_conservation_zone" => ["UK_ukpga_2009_23", ...],
  "England" => ["UK_ukpga_1981_69", "UK_ukpga_2006_16", ...],
}
```

At query time, expand the customer profile using hierarchies, then union the index lookups:

```elixir
# Customer: quarry operator in England
customer_entities = expand_hierarchies(["quarry", "england", "employer"])
# expand_hierarchies("quarry") → ["quarry", "mining_and_quarrying", "extraction"]

candidate_laws = customer_entities
  |> Enum.flat_map(&Map.get(entity_index, &1, []))
  |> Enum.uniq()
# → ~400 candidate laws (from 19K)
```

#### Stage 2: Expression Tree Evaluation (per candidate law)

Each law's applicability is a compiled boolean expression tree (JSON). Fractalaw compiles this from extracted mentions and publishes it. Sertantai evaluates it.

**Node types:**

```elixir
# ApplicabilityNode — recursive tree
defmodule ApplicabilityNode do
  # Leaf: does customer match these codes?
  defstruct [:op, :dimension, :codes, :match_op, :children, :child,
             :condition, :then, :from, :to, :inner, :confidence]
end

# op values:
# "Match"       — leaf node, check customer.dimension against codes
# "And"         — all children must match
# "Or"          — any child must match
# "Not"         — child must NOT match
# "Conditional" — evaluate condition, if true evaluate then
# "TimeWindow"  — check from <= today <= to, then evaluate inner
```

**Evaluator (~50 lines of Elixir):**

```elixir
def evaluate(%{"op" => "Match", "dimension" => dim, "codes" => codes, "match_op" => "AnyOf"}, profile) do
  customer_codes = Map.get(profile, dim, []) |> expand_hierarchies()
  Enum.any?(codes, &(&1 in customer_codes))
end

def evaluate(%{"op" => "And", "children" => children}, profile) do
  Enum.all?(children, &evaluate(&1, profile))
end

def evaluate(%{"op" => "Or", "children" => children}, profile) do
  Enum.any?(children, &evaluate(&1, profile))
end

def evaluate(%{"op" => "Not", "child" => child}, profile) do
  not evaluate(child, profile)
end

def evaluate(%{"op" => "Conditional", "condition" => cond, "then" => then_node}, profile) do
  if evaluate(cond, profile), do: evaluate(then_node, profile), else: false
end

def evaluate(%{"op" => "TimeWindow", "from" => from, "to" => to}, profile) do
  today = Date.utc_today()
  after_from = is_nil(from) or Date.compare(today, Date.from_iso8601!(from)) != :lt
  before_to = is_nil(to) or Date.compare(today, Date.from_iso8601!(to)) != :gt
  after_from and before_to
end
```

#### Customer Profile Schema

```elixir
%{
  "personal" => ["employer", "contractor"],        # actor types
  "material" => ["quarrying", "mineral_extraction"], # activities
  "territorial" => ["england"],                     # jurisdiction
  "sic_codes" => ["08.11"],                         # SIC classification
}
```

#### Hierarchy Expansion

Sertantai manages the hierarchy reference data:

| Hierarchy | Example | Source |
|-----------|---------|--------|
| SIC codes | 08.11 → 08.1 → 08 → B | ONS SIC 2007 |
| Jurisdiction | england → england_and_wales → great_britain → united_kingdom | Static |
| HSE activity | quarrying → mining_and_quarrying → extraction | HSE classification |

Pre-compute ancestor sets for each leaf code. These are static lookup tables.

#### Confidence and Review

- Each `Match` leaf carries extraction confidence (0.0–1.0)
- Tree confidence: `min()` for And nodes, `max()` for Or nodes
- High (>0.9): included in results
- Medium (0.5–0.9): flagged "needs review"
- Low (<0.5): excluded by default

UX: "428 laws apply to your profile. 35 need regulatory review."

### Phase 3: Compiled Expression Trees (LIVE)

Fractalaw compiles and publishes expression trees as JSON in the `compiled_applicability` field on the LRT payload. 701 laws currently have compiled trees. See `ZENOH-SPEC.md` v2.3 "Compiled Applicability Trees" section for the full schema.

Sertantai stores `compiled_applicability` as JSONB on the law record and evaluates it with `SertantaiLegal.Fitness.ApplicabilityEvaluator`. Territorial hierarchy expansion (scotland → great_britain → united_kingdom) is built in.

## Open Questions

- **"Any person"**: universal personal scope — matches all customers unless negated. Treat as wildcard on personal dimension.
- **Numeric thresholds**: "5 or more employees" — currently extracted as a text entity, not a numeric comparison. v2 will add numeric `Match` nodes.
- **Crown application**: government-facing provisions — should not match private employers. The entity "Crown application" signals this.

## References

- Full rules engine design: fractalaw `.claude/plans/fitness/FITNESS-RULES-ENGINE.md`
- Graph propagation design: fractalaw `.claude/plans/fitness/FITNESS-GRAPH.md`
- Strategy overview: fractalaw `.claude/plans/fitness/FITNESS-STRATEGY.md`
- Zenoh payload spec: `docs/zenoh/ZENOH-SPEC.md` v2.3
