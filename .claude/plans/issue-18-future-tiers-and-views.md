# Plan: Issue #18 — Future Tiers, View Sidebar, and Auth

Extracted from the Blanket Bog session (2026-02-05 to 2026-02-09) to separate completed browse-page work from planned future features.

---

## 1. View Sidebar (Phase 2 of Browse Page)

### Problem

The current `ViewSelector` dropdown becomes unusable at scale. With 20+ views planned (time-based, amendments, rescissions, classifications), a hierarchical sidebar is needed.

### Research Summary

| Tool | Pattern | Grouping | Drag-Drop |
|------|---------|----------|-----------|
| **Airtable** | Collapsible sidebar | Custom sections | Within/between groups |
| **Notion** | Horizontal tabs + sidebar | Nested in sidebar | Tabs only |
| **Linear** | Saved filters in sidebar | Workspace vs team | Favorites pin |
| **AG Grid** | Side bar tool panels | Column groups | State persistence |

### Architecture Decision: Two Libraries

Create `svelte-table-views-sidebar` as a new library consuming `svelte-table-views-tanstack` as a peer dependency.

```
┌───────────────────────────┐
│ Consumer App              │
│ (sertantai-legal)         │
└───────────┬───────────────┘
            │
            ▼
┌───────────────────────────┐
│ svelte-table-views-sidebar│ ← NEW: Grouped sidebar UI
│ ~/Desktop/svelte-table-   │
│   views-sidebar           │
└───────────┬───────────────┘
            │ peer dep
            ▼
┌───────────────────────────┐
│ svelte-table-views-       │ ← EXISTS: Stores + persistence
│ tanstack                  │
└───────────────────────────┘
```

**Status**: Library created, basic ViewSidebar component integrated into browse page. Still needed:

- [ ] Search/filter box for filtering views by name
- [ ] Pinned/favorites section (max 5, always visible)
- [ ] Hover actions (pin/unpin, duplicate, edit)
- [ ] Drag-drop reorder within/between groups
- [ ] Keyboard navigation (Tab, Enter, Arrow keys, ARIA labels)
- [ ] Mobile responsive: sidebar → grouped dropdown at < 1024px

### Planned View Groups (20+)

#### Group: Recent Laws (by `md_date`)

| View | Filter | Sort | Grouping |
|------|--------|------|----------|
| Last Month | `md_date >= now - 1 month` | `md_date desc` | year, month |
| Last Quarter | `md_date >= now - 3 months` | `md_date desc` | year, month |
| This Year | `md_date >= Jan 1 current year` | `md_date desc` | year, month |
| Last 12 Months | `md_date >= now - 12 months` | `md_date desc` | year, month |

#### Group: Latest Amendments (by `latest_amend_date`)

| View | Filter | Sort | Grouping |
|------|--------|------|----------|
| Last Month | `latest_amend_date >= now - 1 month` | desc | year, month |
| Last Quarter | `latest_amend_date >= now - 3 months` | desc | year, month |
| This Year | `latest_amend_date >= Jan 1 current year` | desc | year, month |
| Last 12 Months | `latest_amend_date >= now - 12 months` | desc | year, month |

#### Group: Latest Rescissions (by `latest_rescind_date`)

Same pattern as amendments.

#### Group: By Classification

| View | Grouping |
|------|----------|
| By Family | `family` |
| By Type | `type_code` |
| By Status | `live` |
| By Geographic | `geo_extent` |

### Required Column Additions for Sync

To support amendment/rescission views, add to `UK_LRT_COLUMNS`:
- `latest_amend_date_year`
- `latest_amend_date_month`
- `latest_rescind_date_year`
- `latest_rescind_date_month`

### Implementation Phases

- **Phase 2a**: Add missing date columns to Electric sync
- **Phase 2b**: Build out ViewSidebar features (search, pin, a11y)
- **Phase 2c**: Define and seed all 20+ views
- **Phase 2d**: Responsive layout (sidebar → dropdown on mobile)

### Desktop Layout Mockup

```
┌─────────────┬───────────────────────────────────────────────────────┐
│ VIEWS       │                                                       │
│ [Filter]    │  UK Legal Register                                    │
│             │  Records: 1,234 | Sync: Connected                     │
│ Pinned      │                                                       │
│  └─ Custom  │  ┌─────────────────────────────────────────────────┐  │
│             │  │  [Table Content]                                │  │
│ Recent ▼    │  │                                                 │  │
│  ├─ Month   │  │                                                 │  │
│  ├─ Quarter │  │                                                 │  │
│  └─ Year    │  │                                                 │  │
│             │  └─────────────────────────────────────────────────┘  │
│ Amend ▶     │                                                       │
│ Rescind ▶   │  [Filter ▼] [Sort ▼] [Group ▼] [Columns ▼]           │
│ Class ▼     │                                                       │
│  ├─ Family  │                                                       │
│  └─ Type    │                                                       │
│             │                                                       │
│ [+ New View]│                                                       │
└─────────────┴───────────────────────────────────────────────────────┘
```

### Responsive Breakpoints

| Width | Sidebar | Table |
|-------|---------|-------|
| >= 1280px | 240px fixed | Remaining space |
| 1024-1279px | 200px collapsible | Remaining space |
| 768-1023px | Hidden, toggle button | Full width |
| < 768px | Dropdown only | Card view |

### Open Questions

1. User-created views: Allow in Blanket Bog tier or Flower Meadow only?
2. View sharing: URL encoding for shareable view links?
3. View persistence: LocalStorage vs server-side for authenticated users?

---

## 2. Three-Tier Architecture

### Tier Definitions

| Tier | Name | Access | Purpose |
|------|------|--------|---------|
| Free | **Blanket Bog** | Registration required | Read-only tabular views of UK LRT data |
| Paid | **Flower Meadow** | Subscription via hub | Custom legal registers, compliance screening |
| Top | **Atlantic Rainforest** | Subscription via hub | Full API access for external systems |

### Service Orchestration

**sertantai-hub** (skeleton, future):
- Service catalog, subscription plans, org→service mapping
- JWT enrichment: tells sertantai-auth which tier to embed per service
- Billing/payment (Stripe), usage metering

**sertantai-auth** (exists):
- Issues JWTs with `sub`, `org_id`, `role`
- Will be extended with service tier info from hub:
  ```json
  {
    "sub": "user-uuid",
    "org_id": "org-uuid",
    "role": "member",
    "services": {
      "legal": { "tier": "flower_meadow", "features": ["screening", "registers"] }
    }
  }
  ```

**sertantai-legal** implements:
- JWT validation, extract `org_id` and `services.legal.tier`
- Tier-gated routing (frontend route groups)
- Tier-specific UI
- RLS scoping by `org_id`
- API layer (Atlantic Rainforest)

### Proposed Route Architecture

```
/                           # Landing page (public)
/login                      # Redirect to sertantai-auth
/callback                   # OAuth callback

# Blanket Bog (free) ← CURRENT WORK
/browse                     # UK LRT data browser (read-only)
/browse/[family]            # Browse by family
/browse/[family]/[name]     # Single law detail

# Flower Meadow (paid)
/registers                  # Custom legal registers dashboard
/registers/[id]             # Single register view
/screening                  # Location screening workflow
/screening/new              # New screening
/screening/[id]             # Screening results
/locations                  # Organization locations
/locations/[id]             # Location detail

# Atlantic Rainforest (top)
/api-keys                   # API key management
/api-docs                   # Interactive API documentation
/usage                      # API usage dashboard

# Admin (internal, existing)
/admin/lrt                  # LRT data management
/admin/scrape               # Scraping tools
```

### Tier Gating: Layout-Based (Recommended)

```
routes/
├── (public)/               # No auth required
│   ├── +layout.svelte
│   ├── +page.svelte        # Landing page
│   └── login/
├── (authenticated)/        # Any tier (logged in)
│   ├── +layout.svelte      # Auth guard + tier detection
│   ├── (bog)/              # Blanket Bog minimum
│   │   └── browse/
│   ├── (meadow)/           # Flower Meadow minimum
│   │   ├── +layout.svelte  # Tier guard: >= flower_meadow
│   │   ├── registers/
│   │   ├── screening/
│   │   └── locations/
│   └── (rainforest)/       # Atlantic Rainforest
│       ├── +layout.svelte  # Tier guard: == atlantic_rainforest
│       ├── api-keys/
│       └── usage/
└── admin/                  # Internal admin routes
```

### Auth Store Design

```typescript
// $lib/stores/auth.ts
interface AuthState {
  token: string | null;
  user: { id: string; orgId: string; role: string } | null;
  legalTier: 'blanket_bog' | 'flower_meadow' | 'atlantic_rainforest' | null;
  isAuthenticated: boolean;
}
```

### Navigation Per Tier

| Tier | Nav Items |
|------|-----------|
| Blanket Bog | Browse Laws |
| Flower Meadow | Browse Laws, My Registers, Screening, Locations |
| Atlantic Rainforest | Browse Laws, My Registers, Screening, Locations, API Keys, Usage |
| Admin (internal) | LRT Data, Scrape, Sessions, Cascade |

---

## 3. Future Work Checklist

- [ ] Design Flower Meadow register builder concept
- [ ] Design Atlantic Rainforest API layer concept
- [ ] Implement auth store + JWT handling
- [ ] Create route group structure with tier layouts
- [ ] Build landing page
- [ ] View sidebar enhancements (Phase 2a-2d above)
