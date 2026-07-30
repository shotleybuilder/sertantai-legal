---
plan: "Graph Architecture for UK Legislation Relationships"
status: active
created: 2026-04-25

summary: >
  Options for materialising UK legislation relationships into a queryable graph for family QA, impact analysis, and analytics.
---
# Graph Architecture for UK Legislation Relationships

## Current State

### Relationship data already exists

The uk_lrt table stores 6 relationship arrays per law — 3 outbound, 3 inbound:

| Outbound | Inbound | Edge Type |
|----------|---------|-----------|
| `amending[]` | `amended_by[]` | Amendment |
| `rescinding[]` | `rescinded_by[]` | Revocation/Repeal |
| `enacting[]` | `enacted_by[]` | Enactment (parent→child) |

Plus `linked_*` variants that only contain verified names (laws present in the DB).

The `function` JSONB field adds semantic edge labels: Making, Amending, Amending Maker, Revoking, Revoking Maker, Enacting, Enacting Maker, Commencing.

Amendment annotations link laws at the provision level: "S.3 amended by SI 2024/100, reg.5".

### What's missing

1. **No graph index** — relationships are stored as flat arrays on each law. Traversing "all laws enacted under the Climate Change Act" requires scanning every law's `enacted_by` array.
2. **No family inference** — when a new SI is scraped, its family is assigned by SI code mapping only. The enacting Act's family isn't consulted.
3. **No transitive discovery** — "what laws does this law's network touch?" requires recursive queries that don't exist.
4. **No visualisation** — users can't see the relationship web around a law.

---

## Use Cases for a Graph

### 1. Family QA / Auto-classification (immediate value)

**Problem**: A new SI enacted under the Climate Change Act 2008 might get classified as "ENERGY" from its SI code, when "CLIMATE CHANGE" would be more accurate.

**Graph solution**: When assigning family to a new law:
1. Look up `enacted_by` → get parent Act(s)
2. Check parent Act's family
3. If SI code family differs from parent family, flag for review or use parent family as primary

This could also propagate: if a law amends 5 laws all in "FIRE", it's very likely also "FIRE" even if its SI code says otherwise.

**Confidence scoring**:
- enacted_by family match: 90% confidence
- amending family consensus (>80% same family): 85% confidence  
- SI code mapping: 70% confidence (current, sole method)

### 2. Impact analysis (user-facing)

**"What does this law affect?"** → follow all `amending[]` + `rescinding[]` edges outbound, show affected laws with their families and live status.

**"What changed this law?"** → follow all `amended_by[]` + `rescinded_by[]` edges inbound, show modifying legislation with dates.

**"Show me the legislative chain"** → enacted_by traversal: SI → parent Act → grandparent Act (if any). Useful for understanding why a regulation exists.

### 3. Cluster discovery (analytical)

Laws cluster by family, but also by **legislative programme** — a single Act often spawns 10-50 SIs over years. Graph clustering reveals:
- Which Acts are the most prolific enablers (hub nodes)
- Which SIs are isolated vs. deeply connected
- Cross-family connections (a Health Act amending an Environment regulation)

### 4. Temporal graph (future)

Adding time to edges (amendment dates, commencement dates) enables:
- "Show me all changes to this law since 2020"
- "What was the state of this law on date X?" (point-in-time reconstruction)
- Regulatory change velocity metrics per family

---

## Technology Options

### Option A: PostgreSQL Recursive CTEs (no new infrastructure)

**Approach**: Use `WITH RECURSIVE` queries against the existing `linked_*` arrays.

```sql
WITH RECURSIVE chain AS (
  SELECT name, enacted_by, family, 0 AS depth
  FROM uk_lrt WHERE name = 'UK_uksi_2024_123'
  
  UNION ALL
  
  SELECT u.name, u.enacted_by, u.family, c.depth + 1
  FROM uk_lrt u
  JOIN chain c ON u.name = ANY(c.enacted_by)
  WHERE c.depth < 5
)
SELECT * FROM chain;
```

**Pros**: No new infrastructure, works today, familiar SQL.
**Cons**: Performance degrades on deep traversals, no native graph algorithms (PageRank, community detection), arrays aren't indexed for reverse lookups.

**Recommendation**: Good for immediate family QA checks (depth 1-2). Not suitable for full graph analytics.

### Option B: Materialised edge table + PostgreSQL

**Approach**: Extract arrays into a proper edges table:

```sql
CREATE TABLE law_edges (
  source_law TEXT NOT NULL,
  target_law TEXT NOT NULL,
  edge_type TEXT NOT NULL,  -- 'amends', 'enacted_by', 'rescinds'
  source_family TEXT,
  target_family TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (source_law, target_law, edge_type)
);

CREATE INDEX idx_law_edges_target ON law_edges(target_law, edge_type);
CREATE INDEX idx_law_edges_family ON law_edges(target_family);
```

Populated by a Mix task or trigger from the existing arrays. Enables:
- Fast reverse lookups: "all laws that amend X"
- JOIN-based traversals without array unnesting
- Family consensus queries: "what family do most of X's amendees belong to?"

**Pros**: Simple, no new tech, fast for 1-2 hop queries, easy to maintain.
**Cons**: Still SQL for graph traversals, no native algorithms.

**Recommendation**: Best pragmatic option. Solves family QA and impact analysis without new infrastructure.

### Option C: Apache AGE (PostgreSQL graph extension)

**Approach**: Add the AGE extension to PostgreSQL, create a graph schema alongside the relational tables.

```sql
SELECT * FROM cypher('legislation', $$
  MATCH (a:Law)-[:ENACTED_BY]->(b:Law)
  WHERE a.name = 'UK_uksi_2024_123'
  RETURN b.name, b.family
$$) AS (name agtype, family agtype);
```

**Pros**: Native graph queries (Cypher), runs in existing PostgreSQL, no separate database.
**Cons**: AGE extension availability (not in all managed PG providers), learning curve, dual-model maintenance.

**Recommendation**: Consider if graph queries become complex (3+ hops, pattern matching). Overkill for family QA.

### Option D: Dedicated graph database (Neo4j / Memgraph)

**Approach**: Sync law data to a graph database, run graph algorithms there.

**Pros**: Native graph algorithms (PageRank, community detection, shortest path), visualisation tools (Neo4j Bloom), mature ecosystem.
**Cons**: New infrastructure, data sync complexity, operational overhead, cost.

**Recommendation**: Only if graph becomes a core product feature (user-facing law explorer). Too heavy for internal QA.

---

## Recommendation

### Phase 1: Materialised edge table + family QA (now)

1. **Create `law_edges` table** — extract from existing arrays via Mix task
2. **Family inference check** — during parse, query edges to validate family assignment
3. **Add to audit dashboard** — "Family mismatch" check in Diagnostics module

Implementation: ~1-2 sessions. No new infrastructure.

### Phase 2: Impact analysis UI (next)

1. **API endpoint**: `GET /api/laws/:name/graph` — returns nodes + edges for 1-2 hop neighbourhood
2. **Frontend component**: Simple force-directed graph or tree view showing a law's connections
3. **Add to /admin/lat detail**: "Related Laws" panel

Implementation: ~2-3 sessions. D3.js or similar for visualisation.

### Phase 3: Graph analytics (later, if needed)

1. **Hub detection**: Which Acts have the most SIs? (simple SQL on edge table)
2. **Cross-family bridges**: Laws that connect otherwise separate family clusters
3. **Temporal analysis**: Change velocity per family over time

Consider AGE or dedicated graph DB only if Phase 2 reveals complex query patterns.

---

## Family QA Implementation Detail

The most immediately valuable use case. During law parsing:

```elixir
def infer_family(law) do
  # 1. SI code family (current method)
  si_family = Models.ehs_si_code_family(law.si_code)
  
  # 2. Parent family (from enacted_by)
  parent_families = 
    law.enacted_by
    |> Enum.flat_map(&lookup_family/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
  
  # 3. Amending target families (consensus)
  target_families =
    law.amending
    |> Enum.flat_map(&lookup_family/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
  
  # 4. Score and decide
  cond do
    si_family && parent_match?(si_family, parent_families) ->
      # SI code and parent agree — high confidence
      {si_family, :confirmed}
    
    parent_families != [] ->
      # Parent family exists, SI code disagrees or missing — flag for review
      {hd(parent_families) |> elem(0), :parent_inferred, si_family}
    
    target_families != [] && consensus?(target_families) ->
      # Strong consensus from amendment targets
      {hd(target_families) |> elem(0), :target_inferred}
    
    true ->
      # SI code only — current behaviour
      {si_family, :si_code_only}
  end
end
```

This would surface in the audit dashboard as a new check: "Family assignment confidence" showing laws where SI code and graph relationships disagree.

---

## Data Volume Context

- ~19,000 UK LRT records
- ~97,000 LAT rows across 628 laws with parsed text
- Estimated edges: ~50,000-100,000 (amending + enacted_by + rescinding)
- Graph fits comfortably in PostgreSQL — no scalability concerns at this size
