# Title: Phase 2.7 — Frontend AU Integration & Verification

**Started**: 2026-05-20
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Architecture Analysis

### Current State
- Electric syncs `legal_register_uk` partition → PGlite `uk_lrt` table (19,492 records, ~157MB)
- AU data in `legal_register_au` partition (887 records, ~2.5MB) — not synced
- Entitlement model exists: `org_entitlements` (families, data_tier, field_tier)
- Sync profiles exist: user-curated filter sets (families, geo_regions, function_filter)
- Entitlements don't yet include `country` — only families/geo/tiers

### Key Questions
1. **Who gets what?** Users shouldn't receive countries they don't need
2. **PGlite scale** — 20K UK rows is fine. 5 countries × 20K = 100K — still OK? 10 countries?
3. **Shape strategy** — one shape per country? One shape with country filter? One big shape?
4. **Frontend pages** — same components, different data based on country context

### Option A: One Shape Per Country (current pattern, extend it)
- Separate Electric shapes: `legal_register_uk`, `legal_register_au`, `legal_register_nz`
- PGlite: single `laws` table, multiple shapes write to it (country column distinguishes)
- Frontend: country selector filters the local PGlite queries
- Entitlement: add `countries` array to org_entitlements, only subscribe to entitled shapes
- **Pros**: clean partition isolation, subscribe only to what's needed, shape per partition
- **Cons**: N shape subscriptions to manage, slightly more complex sync lifecycle

### Option B: Single Shape on Parent Table with WHERE
- One Electric shape on `legal_register` with `WHERE country IN ('uk','au')`
- WHERE clause driven by entitlement (proxy injects it like org_id scoping)
- PGlite: single table, all subscribed countries arrive together
- **Pros**: one subscription, simpler lifecycle
- **Cons**: Electric must support WHERE on partitioned tables; changing entitlement = new shape

### Option C: Shape Per Sync Profile (most granular)
- Each sync profile defines a shape: country + families + geo + function filters
- Only matching laws sync to client
- PGlite: could be very small (hundreds, not thousands)
- **Pros**: minimal data transfer, fastest local queries, perfect for mobile/low-bandwidth
- **Cons**: complex shape management, shape changes on profile edit, Electric may struggle with complex WHERE

### Key Learning: PGlite Constraint

**PGlite's `syncShapeToTable` allows only ONE shape per local table.**
Multiple shapes targeting the same table causes "Already syncing shape" error.
This rules out Option A as originally conceived (separate shapes per country → same table).

Option A would require separate local tables per country (`laws_uk`, `laws_au`) plus
a UNION view — unnecessary complexity for the admin use case.

### Revised Architecture: Single Shape, WHERE for Scoping

**One shape on `legal_register` (parent partitioned table).** PostgreSQL transparently
queries all partitions. Electric syncs all countries into a single local `laws` table.

Evolution path — same pattern, different WHERE clause:

| Stage | Shape | WHO | Use Case |
|---|---|---|---|
| Now | `legal_register` (no WHERE) | Admin | Full dataset, local country filter |
| Future | `legal_register WHERE country IN ('uk')` | Customer | Country-scoped by entitlement |
| Future+ | `legal_register WHERE country IN ('uk') AND family IN (...)` | Customer | Profile-scoped |

Electric supports `WHERE` on shapes. The progression is additive — same single-shape
pattern, just narrowing the WHERE clause as customer features are built.

### What Other Apps Do
- **Linear**: syncs full workspace to local IndexedDB, filters client-side
- **Notion**: selective sync — you choose which databases to sync offline
- **Electric examples**: typically one shape per logical data set with WHERE for tenancy

## Multi-Country Patterns by Service

### sertantai-legal (this service — admin/data engine)

**Role**: Build and maintain the legal register. Curate data. Publish to fractalaw via Zenoh.

**Electric sync**: Single shape on parent `legal_register` table (all countries).
Admins see everything — country selector is a local UI filter, not access control.

**Frontend changes needed**:
- Rename PGlite table `uk_lrt` → `laws`
- Single shape subscription on `legal_register` (parent table, all partitions)
- Country selector store → drives `WHERE country = $1` on all PGlite queries
- Same browse/admin/LAT pages, adapted by country context
- `source_url` drives external links (already per-country)
- Type code labels from `Countries.{Uk,Au}` module

**Backend changes needed**:
- Electric proxy: add `legal_register_au` to allowed/public tables
- No entitlement changes — admins get all

### sertantai-hub (orchestration — sync curation)

**Role**: Manages org subscriptions, configures what data flows to customers.

**Country dimension needed in**:
- `org_entitlements.countries` — array of country codes the org can access
- `sync_profiles.countries` — which countries this profile covers (subset of entitlement)
- Hub UI: country picker when creating/editing sync profiles

**Contract with -legal**:
- Hub calls webhook to push entitlement changes (already exists)
- Entitlement payload needs `countries` field added
- Profile preview API needs country filter

### sertantai-compliance (SaaS customer app)

**Role**: Compliance officers browse/screen their subscribed legal data.

**Sync strategy**: Single shape on `legal_register` with profile-driven `WHERE` clause.
Electric WHERE scopes by country + family + other profile criteria.
Minimises data on customer devices without needing multiple shapes.

**Data flow**:
- Org's entitlement (from hub) defines ceiling (countries, families, tiers)
- Compliance app gets a single Electric shape with WHERE from entitlement/profile
- Or: -legal pushes to Baserow/external target per sync configuration (current pattern)

**Country dimension needed in**:
- Profile-scoped queries: `ProfileQuery` switches from `uk_lrt` view to `legal_register` with `WHERE country IN (...)`
- Electric shape WHERE clause built from profile (country + family filters)

### Current Sync Contract (ProfileQuery → Engine → Provider)

```
Entitlement (from hub)     → families, data_tier, field_tier [NEEDS: countries]
    ↓
Profile (user-curated)     → families, geo_regions, function, fitness [NEEDS: countries]
    ↓
ProfileQuery               → SQL against uk_lrt view [NEEDS: query legal_register + country filter]
    ↓
Engine                     → orchestrates sync job [no change needed]
    ↓
Provider (Baserow etc)     → pushes rows to target [country column passes through]
```

### What Blocks What

| Change | Needed by | Blocks |
|---|---|---|
| Single shape on `legal_register` + country filter | -legal frontend | Nothing — done |
| `countries` in entitlement | -hub | Customer sync |
| `countries` in sync profile | -hub + -legal | Profile-scoped sync |
| ProfileQuery → `legal_register` with country filter | -legal backend | Customer sync, Baserow multi-country |
| WHERE clause on Electric shape from profile | -compliance | Customer scoped sync |

**Conclusion**: -legal admin frontend uses single unscoped shape (all countries).
Customer scoping is done later by adding WHERE to the same shape pattern.
No architectural change needed — just narrowing the WHERE clause.

## Todo (this session — -legal admin frontend only)
- [x] Rename PGlite table `uk_lrt` → `laws` (schema v16)
- [x] Multi-shape subscription: one per country in COUNTRIES array
- [x] Electric proxy: added `legal_register_au`, `legal_articles_au` to allowed/public
- [x] Country selector store (`$lib/stores/country.ts`)
- [x] Updated all PGlite SQL queries: `FROM uk_lrt` → `FROM laws` (admin/lrt, browse, analytics, LAT queue)
- [x] All tests pass (131 FE, 1227 BE)
- [x] Country selector UI in admin nav bar
- [x] Wired country filter into LRT, browse, analytics, LAT queue queries
- [x] Collection recreates on country switch (LRT page)
- [x] Verified: 887 AU records visible when Australia selected

## Observations / Follow-up Items
1. **AU data quality**: wrong family allocations and missing Type content visible in grid — needs QA pass (Phase 2.6 taxa work)
2. **View doesn't auto-refresh on country switch**: have to click a View to reload — the active view's query doesn't re-fire when the collection changes
3. **Page title still says "UK LRT Data"**: should adapt to selected country
4. **Browse page**: not yet tested with country switching (same collection pattern needed)

**Ended**: 2026-05-21
**Commits**: `a110673`, `d815d83`, `eb2381b`

## Gemini AI Reflections

This is a classic architectural crossroads when building local-first applications with ElectricSQL. Balancing sync overhead, PGlite memory constraints, and tenant isolation is tricky.

Based on your architectural constraints, **Option A is the best foundation for your immediate needs, with an evolution path toward Option C for customers.**

Here is why, broken down by your key questions.

---

## 1. PGlite Scale & Data Volume

Let's look at the numbers first. PGlite handles 100K rows beautifully. In WASM/IndexedDB, 100K rows of text-heavy compliance data will likely sit around 20MB to 50MB of memory/storage.

* **5 countries (100K rows):** Totally fine for desktop and modern mobile browsers.
* **10 countries (200K rows):** Getting hefty for a mobile browser initialization sync, but perfectly acceptable for a desktop web app (like an admin panel).

Because of this scale, you don't *need* to hyper-optimize data transfer for admins, but you *do* want to protect customer devices from downloading data they don't have the rights to see.

---

## 2. Why Option A Wins Today (Admin + Customer Foundational)

Option A is the most pragmatic and stable choice for your current pattern.

* **Clean Entitlement Enforcement:** If an org gains access to Australia, you spin up the `legal_register_au` shape. If they lose it, you tear it down and purge the local rows where `country = 'au'`.
* **Admin Simplicity:** Your admins can simply subscribe to all country shapes (`uk`, `au`, `nz`, etc.) to get the global view they need for curation.
* **Electric Maturity:** Electric handles discrete, static shapes beautifully. It excels at "subscribe to this collection of things" much better than dynamically rewriting complex `WHERE` clauses on a single massive shape when user entitlements change mid-session (which is the headache with Option B).

---

## 3. The Hybrid Strategy: Admin vs. Customer Pages

You noted that Admins and Customers use the data differently. You shouldn't try to force them into the exact same sync strategy.

### The Admin Strategy (Keep Option A)

Admins use the **One Shape Per Country** pattern. They have beefy machines, stable internet, and need the full datasets to curate. They subscribe to all available country shapes.

### The Customer Strategy (Evolve to Option C)

Compliance officers don't want or need 100K rows of laws. They only care about the exact legal families, geometries, and functions that apply to their specific compliance profiles.

Instead of jumping straight to a hyper-complex Option C, you can implement a **Scoped Option A** for customers:

```javascript
// Customer Sync Strategy Example
const shapes = [
  // Only sync the countries they are actually entitled to
  ...entitledCountries.map(country => ({
    shape: `legal_register_${country}`,
    // If Electric supports basic WHERE, filter by high-level profile categories
    where: `status = 'active' AND core_family IN (${subscribedFamilies})` 
  }))
];

```

---

## 4. How to Handle Frontend Pages

To keep your frontend components identical across different country contexts, use a **Context Provider** to abstract the local PGlite queries.

Your UI components shouldn't care *how* the data got into PGlite; they should just query PGlite locally based on the active UI context.

```jsx
// 1. Establish the local query filter via Context
const CountryContext = createContext('uk');

// 2. Keep components entirely generic
function LegalRegisterList() {
  const country = useContext(CountryContext);
  
  // This hook queries the local PGlite instance
  const { data: laws } = useLiveQuery(
    `SELECT * FROM laws WHERE country = $1`, 
    [country]
  );

  return (
    <div>
      {laws.map(law => <LawRow key={law.id} law={law} />)}
    </div>
  );
}

```

By decoupling the **Sync Layer** (Option A fetching the rows) from the **View Layer** (PGlite filtering via SQL), your frontend remains perfectly modular. Admins can switch the context selector to see different countries instantly because all data is local. Customers only see the countries their shapes have pulled down.

---

## Summary of the Playbook

1. **Adopt Option A** immediately. Implement country-specific shapes (`legal_register_uk`, etc.).
2. **For Admins:** Subscribe them to all country shapes.
3. **For Customers:** Only subscribe them to the shapes matching their `org_entitlements.countries`.
4. **On the Frontend:** Use local `WHERE country = X` queries in your components, driven by a React/Vue context provider, keeping the UI entirely decoupled from the sync lifecycle.
