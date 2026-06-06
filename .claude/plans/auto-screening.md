# Auto Applicability Screening — Draft Plan

**Status**: DRAFT v2 — incorporating feedback
**Issue**: #102
**Meta-plan**: Phase 8

## Problem

Customers face ~1,800 Making laws and need to decide which apply to their organisation. Manual screening is slow. SertantAI has fitness data (person, place, plant, process, sector) on ~50% of laws that can automate initial recommendations.

## Core Concept

A customer describes their organisation via a simple profile (what they do, where, with what). SertantAI matches this profile **deterministically** against law annotations to seed an initial register. This is not AI — it's set intersection on structured data. The customer then refines manually.

## Org Profile — What We Know About a Customer

Model the profile as **tag selections** across dimensions. Tags come directly from the actual vocabulary in the data:

### Profile dimensions

| Dimension | Example tags | Primary source | Notes |
|-----------|-------------|---------------|-------|
| **Country/Region** | UK, England, Scotland, Wales | `geo_extent`, `geo_region` | Primary geographic filter — not fitness |
| **Activities** | employer, manufacturer, supplier, operator, importer | `fitness_person` | What roles the org plays |
| **Locations** | premises, offshore, ship, aircraft | `fitness_place` | Physical site types (not geography) |
| **Materials** | chemicals, explosives, asbestos, lead, dangerous goods | `fitness_plant` | What substances/equipment they work with |
| **Processes** | construction work, diving operations, gas work | `fitness_process` | What activities they perform |
| **Sector** | maritime, nuclear, water industry, offshore oil & gas | `fitness_sector` | Industry vertical |

**Key distinction**: Country/Region uses the dedicated `geo_extent`/`geo_region` columns (primary filter), not `fitness_place`. Fitness place covers physical site types (premises, offshore, ship). Don't conflate geographic applicability with fitness.

### Where the profile lives

**In sertantai-legal** — this is where the screener lives and Legal is the context for the extended org profile. The fitness vocabulary is here, the matching runs here.

- New table: `org_screening_profiles` with array columns per dimension
- Scoped by organization_id
- Managed via `/app/profile` page

## Matching Algorithm

### Two-stage filter: Geography first, then Fitness

**Stage 1: Geographic filter** (using `geo_extent`, `geo_region`)
```
law.geo_extent overlaps profile.country_region
```
This filters the ~1,800 Making laws down to the laws that apply to the customer's jurisdictions. A Scottish company doesn't need Welsh-only laws.

**Stage 2: Scored fitness matching** (on the geo-filtered set)

Simple OR across all dimensions produces too many false positives — a law matching
`employer` (thousands of laws) floods the register and buries the specific `asbestos`
laws the customer actually cares about. Instead, use a **match score**:

```sql
SELECT l.name,
       (CASE WHEN l.fitness_person  && $1 THEN 1 ELSE 0 END +
        CASE WHEN l.fitness_place   && $2 THEN 1 ELSE 0 END +
        CASE WHEN l.fitness_plant   && $3 THEN 1 ELSE 0 END +
        CASE WHEN l.fitness_process && $4 THEN 1 ELSE 0 END +
        CASE WHEN l.fitness_sector  && $5 THEN 1 ELSE 0 END) as match_score
FROM laws l
WHERE l.is_making = true
  AND match_score > 0
ORDER BY match_score DESC
```

Laws matching more dimensions score higher and sort first. The UI can then offer:
- **Default**: Match ANY (score > 0) — inclusive, shows everything that touches the profile
- **Strict**: Match 2+ dimensions — reduces noise, surfaces laws most relevant to the org
- User toggle between modes

### Tag hierarchy (future — address false negatives)

Flat exact matching creates false negatives when granularity differs between law
annotations and profile selections. E.g. law has `fitness_plant: [forklifts]` but
user selects `lifting equipment`. A basic parent-child hierarchy on tags would fix this
(Forklift → Material Handling → Vehicles). 

**For v1**: Accept this gap. The vocabulary is curated by fractalaw and profile tags
are drawn from the same vocabulary, so exact matches are the norm. Add hierarchy
when the data shows it's needed (track miss rate against Enhesa validation set).

### No universal laws — let the data speak

Don't assume "employer" or "HSWA" is universal. The screener uses the annotations
the law carries. If `fitness_person: [employer]` and profile includes `employer`,
it matches. If not, it doesn't. No special cases, no second-guessing.

### Laws without fitness data — "Requires Manual Review"

~50% of Making laws have no fitness data. Don't call this "lower confidence" —
un-annotated data isn't less likely to apply, it's just unknown. Frame as:

**"Uncategorized — Requires Manual Review"**

Present as a separate tier so the customer doesn't ignore critical un-annotated laws
thinking they're low priority. Fractalaw is actively closing this gap.

**Sub-group by family**: A UK company may see hundreds of Uncategorized laws. Don't dump
them in a flat list — group by legal family in UI accordions. Users can scan "40 OH&S laws"
or "12 Waste laws" much faster than an alphabetical list of 400 items.

### Tiers

| Tier | Meaning | UI treatment |
|------|---------|-------------|
| **Strong match** | 2+ fitness dimensions match | Green badge, high confidence |
| **Single match** | 1 fitness dimension matches | Blue badge, matches profile |
| **Uncategorized** | No fitness data, in subscribed family + geo | Amber, "requires review" |
| **No match** | Nothing matches | Available pool (left panel) |

## Seeding Workflow

### "Seed My Register" button on screening page

1. Customer sets up profile (tag selection UI at `/app/profile`)
2. Presses "Seed My Register" on screening page
3. Algorithm runs **locally in PGLite** (instant) — scored matching query
4. **Sync check**: If PGLite is mid-sync or dirty, show spinner — don't run on stale data
5. Results shown as preview with tier breakdown:
   - "SertantAI found 312 laws matching your profile"
   - "187 strong matches (2+ dimensions), 125 single matches"
6. Customer confirms → bulk upsert with `source: 'screener'`

### Additive seeding + deprecation preview

**Seeding is additive** — pressing "Seed" only adds NEW recommendations (delta).

**Deprecation preview based on current state** (not profile diff):

Don't track what changed in the profile. Instead, on every seed, run a global
state evaluation: find register laws where `source = 'screener'` AND `match_score = 0`
against the current profile AND current law metadata.

This catches two cases:
1. Customer removed a tag from their profile → some laws no longer match
2. Fractalaw updated a law's annotations → law no longer matches the profile

Both produce the same UI:
> "14 laws in your register no longer match your profile. Archive them?"

The customer explicitly chooses to remove. SertantAI never auto-removes.

Laws confirmed by the user (`source: 'manual'`) are never flagged for deprecation —
only `source: 'screener'` laws are candidates.

### Visual distinction + audit trail

In the screening UI right panel (My Register):
- Laws with `source: 'screener'` show a SertantAI badge — `reviewed_by: 'sertantai'`
- Laws with `source: 'manual'` show the user's name — `reviewed_by: user.email`
- Laws with `source: 'enhesa_import'` show an import badge

**Confirmation workflow**: Seeded laws (`source: 'screener'`) can be explicitly confirmed by the customer. Confirming changes `source` to `'manual'` and `reviewed_by` to the user — transferring ownership. This ties into the audit trail (#99): the history shows "seeded by SertantAI at T1, confirmed by jane.doe@qq.com at T2".

This is **deterministic** screening, not AI. The term "AI-seeded" in #102 is misleading — it's structured data matching. The UI should reflect this: "Seeded by SertantAI based on your profile" not "AI recommends".

## Implementation Phases

## PGLite Performance + Data Integrity

- **Sync gate**: Seed execution must check `syncStatus.connected && !syncStatus.syncing` before
  running. If PGLite is mid-sync, show a loading state — don't match on stale data.
- **GIN indexes**: PGLite (WASM Postgres) may not support `USING GIN` — validate during Phase 8a.
  If GIN fails, fall back to btree or no index. With ~1,800 Making laws, an unindexed array scan
  in WASM memory takes <10ms — don't let an index syntax error stall the frontend build.
- **Profile state**: Profile must be synced to PGLite before matching (or read from backend on
  seed). Don't match a saved server-side profile against a stale local PGLite.

## Implementation Phases

### Phase 8a: Org screening profile
- `org_screening_profiles` table: organization_id + array columns per dimension
- Backend CRUD endpoints
- `/app/profile` page with multi-select tag pickers
- Tags auto-populated from actual fitness vocabulary in PGLite

### Phase 8b: Geographic filter + fitness matching
- Two-stage PGLite query: geo_extent/geo_region filter → fitness intersection
- Preview: "SertantAI found N laws matching your profile" with tier breakdown
- Dry-run mode (show without committing)

### Phase 8c: Seed execution + source badges
- Bulk upsert with `source: 'screener'`, `reviewed_by: 'sertantai'`
- Badge rendering in screening page right panel (SertantAI / user / import)
- Delta logic for re-seeding (additive only)
- Confirmation flow: click to transfer ownership from SertantAI to user

### Phase 8d: Family-only fallback tier
- Laws with no fitness data but in subscribed families + geo match
- Amber "may apply" tier in UI
- Separate from fitness-matched (green) tier

## Resolved Questions

1. **Profile lives in sertantai-legal** — this is where the screener and fitness vocabulary live.

2. **Geography uses dedicated columns** (`geo_extent`/`geo_region`), not fitness_place. Fitness place = physical site types (premises, offshore). Geography = country/state jurisdiction.

3. **No universal laws** — don't second-guess the annotations. If a law says `fitness_person: [employer]` and the customer says they're an employer, it matches. If not, it doesn't. Let the screener work with the data.

4. **Deterministic, not AI** — this is structured data matching. Seeded laws use `source: 'screener'`, `reviewed_by: 'sertantai'`. Customer can confirm (transfers ownership to their user). Ties into audit trail (#99).

5. **Fractalaw closing the fitness gap** — coverage improving rapidly (21% → 44% EU in one session). Family-only tier handles the remainder with lower confidence indicator.

## Resolved (v2)

6. **Tag vocabulary**: Auto-populated from actual fitness values in PGLite. The vocabulary is already curated by fractalaw's dictionaries — no need to maintain a separate fixed list. Updates automatically as fractalaw adds new terms.

7. **Geo filter**: Use `geo_region` (individual tags per state) for matching, not `geo_extent` (composite string for Baserow). Customer profile selects countries/states ("England", "Scotland"), matched against `geo_region` array overlap.

## Incorporated from external review (Gemini)

8. **OR explosion → scored matching**: Simple OR across dimensions floods register. Replaced with match_score (count of matching dimensions) + user toggle for strict (2+) vs inclusive (1+).

9. **Tag hierarchy for false negatives**: Flat exact matching misses granularity mismatches (law says "forklifts", user says "lifting equipment"). Deferred to v2 — fractalaw vocabulary is shared so exact matches are the norm for now. Track miss rate.

10. **Deprecation preview on profile change**: Additive-only seeding means profile changes don't clean up stale laws. Added deprecation preview: "14 laws no longer match — archive them?" Only for `source: 'screener'` laws, never user-confirmed ones.

11. **PGLite sync safety**: Must gate seed execution on sync status. Added GIN indexes for array overlap performance.

12. **"Uncategorized" not "low confidence"**: Un-annotated laws aren't less likely to apply — they're unknown. Reframed as "Requires Manual Review" to prevent customers ignoring critical legislation.

## Incorporated from external review (Gemini v2)

13. **GIN index reality check**: PGLite WASM may not support GIN indexes. Validate in Phase 8a. With ~1,800 laws, unindexed scan is <10ms — don't block on this.

14. **Zombie laws from annotation changes**: Deprecation preview must be global state evaluation (`source='screener' AND match_score=0`), not profile-diff based. Catches both profile changes and law metadata updates by fractalaw.

15. **Uncategorized UI avalanche**: Sub-group Amber tier by legal family in accordions. Hundreds of unreviewed laws in a flat list causes decision fatigue.

16. **`NOT LIKE '%Revoked%'` is brittle**: Text-matching on `live` status breaks when new variants appear ("Partially Revoked", "Superceded"). Should be an enum or boolean on the data pipeline side. For now, the emoji-prefixed values (`❌ Revoked...`, `⭕ Part...`, `✔ In force`) are consistent — but flag as tech debt for a clean `is_active` boolean column.

## Governance + Product Design (from ChatGPT review)

These don't change the architecture but must be captured for customer documentation,
product positioning, and measurement.

### G1. Optimise for recall, not precision

In compliance screening, missing a law is worse than recommending an extra one.
Customers tolerate noise but not gaps. The screener should err on the side of
inclusion. **Recall is the primary optimisation target.**

Validation target: >90% recall even if precision drops to 70%.

### G2. Dimension weights (future)

Not all dimensions are equally informative. `plant: asbestos` is far more specific
than `person: employer`. Future enhancement: weighted scoring.

| Dimension | Weight | Rationale |
|-----------|--------|-----------|
| Person | 1 | Broad (employer matches thousands) |
| Place | 2 | Moderate specificity |
| Sector | 2 | Industry vertical |
| Plant | 3 | Substance/equipment — highly specific |
| Process | 3 | Activity — highly specific |

Capture for v2. Not needed for v1 where match_score count is sufficient.

### G3. Fitness annotations are indicators, not logical tests

Laws may require `employer AND diving operations` but we match `employer OR diving`.
Document clearly for customers:

> "Fitness annotations represent indicators of applicability, not complete
> logical applicability tests. The screener surfaces likely-applicable laws
> for your review — it does not replace professional compliance judgement."

This is the core positioning statement for customer guides.

### G4. Foundational laws governance decision

"No universal laws" is technically correct but operationally risky. Some laws
(HSWA, MHSWR, RIDDOR) have such broad applicability that omission cost is enormous.

Don't hardcode them. Instead, track a **"Foundational" tier** — laws with
historically high applicability rates across organisations. This is a governance
decision (which laws qualify) not a technical one.

Consider a 5th tier:

| Tier | Meaning |
|------|---------|
| **Foundational** | Historically near-universal applicability |
| Strong match | 2+ fitness dimensions match |
| Single match | 1 fitness dimension matches |
| Uncategorized | No fitness data, requires review |
| No match | Available pool |

### G5. Explainability — "why this law matched"

Store match provenance with each seeded law:

```json
{
  "score": 3,
  "matched_tags": {
    "person": ["employer"],
    "plant": ["asbestos"],
    "sector": ["construction"]
  }
}
```

Display in the register: "Recommended because you selected: Employer, Asbestos,
Construction". Dramatically improves trust and auditability.

**This is near-essential** — store in `org_applicabilities.notes` or a new
`match_reason` JSONB column.

### G6. "SertantAI recommends; the duty holder decides"

The `screener → manual` confirmation flow is the primary defensibility argument.
Elevate this in customer documentation — it's not just a UI feature, it's the
audit pattern regulators expect.

### G7. Coverage KPI

Track and surface to customers:

```
Coverage = fitness-screened laws / total in-scope laws
```

E.g. "37.5% of your law universe is currently fitness-classified". This becomes
a measurable product KPI that improves as fractalaw expands coverage.

### G8. Profile quality feedback loop

Customers may not accurately describe themselves. Consider:
- **Profile completeness score** ("52% complete")
- **Suggested tags** from laws already manually added: "You have 18 asbestos laws.
  Consider adding 'asbestos' to your profile."

### G9. Per-tag quality metrics

Track TP/FP/FN per fitness tag against validation data. Discover which tags are
predictive vs noisy. Feeds into dimension weighting (G2) and vocabulary refinement.

### G10. Success metric

The real question isn't "did the algorithm find laws?" but:

> "Did it reduce the time for a competent compliance practitioner to create
> a defensible register?"

Measure:
- Time to first register
- % of seeded laws retained after review
- % of manually-added laws that should have been seeded

## Pre-implementation Checklist

- [ ] Validate `USING GIN` in PGLite WASM — fall back gracefully if unsupported
- [ ] Group Uncategorized tier by family in UI accordions
- [ ] Deprecation preview uses global match_score=0 query, not profile diff
- [ ] Track `NOT LIKE '%Revoked%'` brittleness as tech debt — consider `is_active` boolean
- [ ] Add `match_reason` JSONB column to org_applicabilities (G5)
- [ ] Document G3 positioning statement for customer guides
- [ ] Decide on Foundational tier governance (G4) — which laws qualify?
- [ ] Surface coverage KPI in stats dashboard (G7)

## Validation

Test against QQ's Enhesa data:
- Run seeding with QQ's profile tags → compare recommended set to Enhesa Yes set
- Measure: how many of the 208 TP laws does the seeder find?
- Measure: how many false recommendations (laws not in the Enhesa set)?
- Target: >80% recall on the TP set with <20% false recommendations

## Key Files

| Purpose | Path |
|---------|------|
| OrgApplicability resource | `backend/lib/sertantai_legal/sync/org_applicability.ex` |
| ApplicabilitySource enum | `backend/lib/sertantai_legal/sync/applicability_source.ex` |
| Screening page | `frontend/src/routes/app/screening/+page.svelte` |
| PGLite schema | `frontend/src/lib/pglite/schema.sql.ts` |
| Fitness data (law level) | `uk_lrt.fitness_person/place/plant/process/sector` |
| ScreeningController | `backend/lib/sertantai_legal_web/controllers/screening_controller.ex` |
