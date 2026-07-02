# Significance-Based Legal Register Guide

**Purpose**: How to surface fractalaw's significance signals in a customer's Baserow legal register so they can filter, sort, and prioritise their compliance obligations.

**Audience**: SertantAI operators building customer compliance registers.

**Principle**: The customer's Legal Register contains ALL their applicable laws — we don't exclude laws. Significance signals help the customer focus their effort, not reduce their scope.

---

## How It Works

The customer identifies their applicable laws (from legacy vendor import or manual selection). We sync those laws to Baserow with enrichment data from fractalaw. Significance signals tell the customer *where to focus first* — which laws have the most critical obligations, and within a law, which provisions demand the most attention.

```
Customer's applicable laws (274)
  → Legal Register table (all 274, with significance rating + score)
  → Duties table (governed obligations, with per-provision significance)
  → Actor Tuples table (who bears each duty)
```

The customer uses Baserow's built-in filter/sort/group to:
- Sort their register by significance score (most critical laws first)
- Group by significance rating (HIGH / MEDIUM / LOW)
- Filter duties to HIGH-only when starting a compliance review
- Drill into dimension detail when assessing a specific provision

---

## Data Available

### Law-Level (synced to Legal Register table)

| Field | Type | Baserow Column | Use |
|-------|------|----------------|-----|
| `significance_rating` | HIGH/MEDIUM/LOW | Single select | Group, filter, colour-code |
| `significance_score` | Float | Number | Sort (highest = most critical) |
| `significance_high_count` | Integer | Number | "This law has N high-priority duties" |
| `significance_medium_count` | Integer | Number | Distribution shape |
| `significance_low_count` | Integer | Number | Distribution shape |
| `significance_total_obligations` | Integer | Number | Total duty count |
| `significance_parts` | JSON array | Long text | Part breakdown for large Acts |

### Provision-Level (synced to Duties table)

| Field | Type | Baserow Column | Use |
|-------|------|----------------|-----|
| `significance_overall` | HIGH/MEDIUM/LOW | Single select | Primary filter/sort for duties |
| `significance_gravity` | HIGH/MEDIUM/LOW | Single select | What's at stake |
| `significance_scope_duty_bearer` | HIGH/MEDIUM/LOW | Single select | How broadly it applies |
| `significance_strength` | HIGH/MEDIUM/LOW | Single select | Absolute vs qualified |
| `significance_confidence` | Float 0-1 | Number | Rating certainty |

### Formulas

**Provision overall** (weighted aggregate of 5 dimensions):
```
score = 0.35 × gravity + 0.20 × scope_duty_bearer + 0.20 × scope_protected_class
      + 0.15 × strength + 0.10 × hierarchy

HIGH=3, MEDIUM=2, LOW=1. Thresholds: ≥2.5 → HIGH, ≥1.75 → MEDIUM, else LOW.
```

**Law-level score** (volume-adjusted average):
```
score = avg_provision_significance × log2(total_obligations + 1)
avg   = (3 × high + 2 × medium + 1 × low) / total

Rating: percentile rank — top 20% → HIGH, bottom 33% → LOW, else MEDIUM.
```

---

## What Goes Into Each Baserow Table

### Legal Register (LRT) — ALL applicable laws

Every law the customer marks as applicable, regardless of significance. This is their register — they own it.

**Includes**:
- Revoked laws (customer may be managing legacy compliance)
- Laws with no obligations (empowering/housekeeping)
- Laws awaiting fractalaw processing (significance = null)

**Significance columns enable**: sorting by criticality, grouping by rating, identifying which laws to review first.

**Row count**: Typically 200-400 per customer. Always well within Baserow limits.

### Duties (LAT) — Governed obligations from in-force laws

Aggregated provisions (Goldilocks model) filtered to:
1. **Obligation** DRRP type only
2. **Governed** active actors only (Org:, Ind:, SC:, Spc: — not Gvt:, EU:)
3. **In-force** laws only (exclude fully revoked)

**Significance columns enable**: filtering to HIGH duties for initial compliance review, sorting by gravity to prioritise health/safety over administrative duties.

**Row count**: Typically 1,000-2,500. The significance_overall column lets customers filter to HIGH-only (~10-15% of duties) when they need to focus.

### Actor Tuples — Who bears each duty

Normalised (actor, position, DRRP type) tuples linked to Duties via many-to-many. No significance columns — significance lives on the duty, not the actor.

---

## Customer Use Cases in Baserow

### 1. "Show me the most critical laws first"

Sort Legal Register by `Significance Score` descending. The highest-scoring laws have the most HIGH-rated obligations and the greatest volume of duties.

### 2. "Which laws need my immediate attention?"

Filter Legal Register: `Significance Rating = HIGH`. These are the top 20% of laws by obligation severity. Typically 40-60 laws for a large customer.

### 3. "I'm reviewing HSWA — which provisions matter most?"

Filter Duties by `Law Name = UK_ukpga_1974_37`, sort by `Significance Overall` (HIGH first). The compliance officer sees the most critical duties at the top.

### 4. "Why is this provision rated HIGH?"

Look at the dimension columns:

| Dimension | Rating | Meaning |
|-----------|--------|---------|
| Gravity | HIGH | Health & safety at stake |
| Scope (duty bearer) | HIGH | Applies to all employers |
| Strength | MEDIUM | SFARP-qualified obligation |
| **Overall** | **HIGH** | Weighted aggregate |
| Confidence | 0.94 | High certainty |

### 5. "Show me just the health/safety duties"

Filter Duties: `Significance Gravity = HIGH`. This isolates provisions where health, safety, or life is at stake — distinct from property damage (MEDIUM) or administrative non-compliance (LOW).

### 6. "Which Parts of this large Act are relevant?"

The Legal Register row for a large Act has `Significance Parts` showing the per-Part breakdown:
```
Part I:   31 HIGH, 35 MEDIUM, 69 LOW  (core duties)
Part III:  0 HIGH,  3 MEDIUM, 10 LOW  (minor)
Part IV:   0 HIGH, 10 MEDIUM, 14 LOW  (admin)
```
The customer can see that Part I is where the critical duties are.

### 7. "How much compliance work do we have?"

Group Legal Register by `Significance Rating`:
- HIGH: 62 laws → priority compliance programme
- MEDIUM: 113 laws → standard monitoring
- LOW: 46 laws → periodic review

---

## Governed-Only: Why It Matters

Significance is rated on ALL Obligation provisions, including government responsibilities. The Duties table only contains **governed** obligations — where the active actor is a business entity, not a government body.

This means:
- A law rated HIGH overall may have few or zero rows in the Duties table (if most obligations fall on government)
- The Legal Register still shows the law as HIGH — it's important legislation even if the customer's direct duties are limited
- The mismatch is informative, not a bug: "this law matters, but your obligations under it are few"

Example: HSWA 1974 is rated HIGH (significance_score 12.19) but has limited governed duties because most provisions impose obligations on inspectors and the HSE, not employers. The employer duties (s.2, s.3, s.7) that do exist are individually HIGH-significance.

---

## Curating the Duties Table for Baserow

### The Row Budget Problem

Baserow's free tier limits tables to 3,000 rows. A full governed-obligation sync produces far more:

| Filter | Aggregated Provisions (QQ) |
|--------|---------------------------|
| All governed obligations (in-force) | ~5,375 |
| + provision significance HIGH or MEDIUM | ~2,285 |
| + provision significance HIGH only | ~895 |
| Governed obligations with no significance yet | ~559 |

Without curation, the Duties table exceeds 3K. Significance signals provide the mechanism to curate intelligently.

### Curation Strategies

#### Strategy A: Law-level gate + all provisions (recommended)

Only sync duties from **HIGH and MEDIUM significance laws**. Include all governed provisions from those laws regardless of provision-level rating.

| Law Rating | Governed Duties | Action |
|------------|----------------|--------|
| HIGH | ~1,879 | Include all provisions |
| MEDIUM | ~1,415 | Include all provisions |
| LOW | ~93 | Exclude from Duties table |
| No rating | variable | Include (pending classification) |
| **Total** | **~3,294** | Near budget — may need to exclude unrated |

**Why this works**: LOW-rated laws have very few governed duties (93 total). Excluding them barely reduces the customer's compliance coverage while keeping the table under 3K. The customer still sees these laws in the Legal Register — they just don't get per-provision detail in the Duties table.

#### Strategy B: Provision-level filter

Sync all laws but only HIGH + MEDIUM provisions:

| Provision Rating | Governed Duties |
|-----------------|----------------|
| HIGH | ~895 |
| MEDIUM | ~1,390 |
| **Total** | **~2,285** |

**Pro**: Well under 3K, maximum signal-to-noise ratio.
**Con**: Drops LOW provisions which may still be relevant (e.g., reporting/notification duties). Customers lose visibility of the full obligation landscape within a law.

#### Strategy C: Law-level gate + provision filter (most compact)

Only sync HIGH + MEDIUM provisions from HIGH + MEDIUM laws:

| | Governed Duties |
|--|----------------|
| HIGH law, HIGH+MEDIUM provisions | ~750 |
| MEDIUM law, HIGH+MEDIUM provisions | ~600 |
| **Total** | **~1,350** |

**Pro**: Leaves headroom for future tables (actions, evidence).
**Con**: Most aggressive filter — misses LOW provisions in important laws.

#### Strategy D: Gravity-focused

Sync all provisions where `significance_gravity = HIGH` (health/safety/life at stake), regardless of overall rating:

| | Governed Duties |
|--|----------------|
| Gravity = HIGH | ~800-1,200 |

**Pro**: Directly answers "what could hurt someone?". Compelling for EHS customers.
**Con**: Misses property/environmental/administrative duties.

### Recommendation

**Start with Strategy A** (law-level gate). It's the closest to "show everything that matters" while respecting the row budget. If the customer needs more granularity, drop to Strategy B. If they need headroom for additional tables, use Strategy C.

The `sync_configurations.target_config` can be extended with:
- `lat_min_law_significance`: "MEDIUM" — exclude LOW-rated laws from Duties
- `lat_min_provision_significance`: null — no provision-level filter (Strategy A)

Or for Strategy B:
- `lat_min_law_significance`: null — all laws
- `lat_min_provision_significance`: "MEDIUM" — exclude LOW provisions

---

## Sync Configuration

The sync engine reads these settings from `sync_configurations.target_config`:

```json
{
  "lat_drrp_types": ["Obligation"],
  "lat_aggregated": true,
  "lat_governed_only": true
}
```

- `lat_drrp_types: ["Obligation"]` — only sync Obligation provisions (duties/responsibilities in Hohfeldian terms)
- `lat_aggregated: true` — use Goldilocks model (group sub-provisions under parent)
- `lat_governed_only: true` — exclude provisions where all active actors are Gvt:/EU:

The sync profile's `live_filter` and `families` can be left empty — the LRT includes all applicable laws, the LAT filters are on the target_config.

---

## Edge Cases

### Laws with no significance data

Causes: LAT not yet parsed, fractalaw pipeline incomplete, EU instruments with no parseable text.

**Behaviour**: Law appears in Legal Register with null significance columns. Customer sees it but can't sort/filter by significance until data arrives.

**Tracking**: `mix customer.pipeline_status --flags` identifies these.

### Laws with significance but no governed duties

Law appears in Legal Register with a significance rating but zero rows in the Duties table.

**Behaviour**: The customer sees the law is important but has no specific duty rows. This is correct — the law's obligations may fall on government, or the actor classification may be incomplete.

### Low-confidence ratings

`significance_confidence < 0.9` means the SLM was uncertain. The rating may change after LLM review.

**Behaviour**: Show the confidence value alongside the rating so customers can weigh accordingly.

### Part-level data availability

`significance_parts` is only populated for Acts with ≥50 rated Obligation provisions and Part structural hierarchy. Most SIs and smaller Acts don't have Parts.

---

## Data Volumes (Full UK Corpus)

| Metric | Count |
|--------|-------|
| Rated Obligation provisions | 40,468 |
| Laws with significance | 553 |
| Laws rated HIGH | 109 (20%) |
| Laws rated MEDIUM | 246 (47%) |
| Laws rated LOW | 166 (33%) |
| Provisions rated HIGH | 5,359 (13%) |
| Provisions rated MEDIUM | 10,023 (25%) |
| Provisions rated LOW | 25,086 (62%) |

---

## Related Tools

- `mix customer.pipeline_status` — check data readiness before building a register
- `mix sync.run --clean --direct` — push register to Baserow
- `/api/zenoh/query` — query fractalaw pipeline status for specific laws
- `customer-pipeline-status` skill — comprehensive pipeline report
