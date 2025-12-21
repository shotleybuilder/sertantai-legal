# Sertantai to Sertantai-Legal Migration Plan

**Migration Type**: New Project Build + Selective Library Port  
**Source Project**: `/home/jason/Desktop/sertantai`  
**Target Project**: `/home/jason/Desktop/sertantai-legal` (this project)  
**Estimated Timeline**: 17-24 weeks (4-6 months)  
**MVP Timeline**: 8-10 weeks

## Executive Summary

This migration creates a **new UK legal/regulatory compliance platform** using modern offline-first architecture (ElectricSQL + Svelte) while preserving the core domain logic and data from the existing Sertantai Phoenix LiveView application.

**Key Decision**: Building fresh rather than migrating in-place due to fundamental architectural differences between LiveView (server-rendered) and ElectricSQL+Svelte (offline-first, client-side reactive).

## Source Project Analysis

### Current Architecture (Sertantai)
- **Framework**: Elixir/Phoenix 1.7+ with Ash Framework 3.0+
- **Frontend**: Phoenix LiveView (server-rendered reactive UI)
- **Database**: PostgreSQL (Docker local + Supabase production)
- **Auth**: Ash Authentication with 5-tier role system (admin, support, professional, member, guest)
- **AI**: OpenAI + LangChain integration for compliance screening
- **Billing**: Stripity Stripe integration
- **Size**: 48 Elixir source files, 19K+ UK LRT records

### Domain Contexts (8 total)
1. **UK LRT** - 19,000+ UK legal/regulatory transport records with JSONB fields
2. **Organizations** - Multi-location organization management
3. **Accounts** - User authentication and authorization
4. **AI** - Conversation sessions, question generation, applicability analysis
5. **Billing** - Stripe customers, subscriptions, role-based access
6. **Sync** - Data synchronization configuration
7. **Query** - Progressive query builders, result streaming
8. **Cache** - Applicability caching

### Target Architecture (Sertantai-Legal)
- **Framework**: Elixir/Phoenix 1.7+ with Ash Framework 3.0+
- **Frontend**: SvelteKit + TailwindCSS v4
- **Real-time Sync**: ElectricSQL v1.0 (HTTP Shape API)
- **Client Storage**: TanStack DB (differential dataflow, reactive queries)
- **Offline-First**: Full local data persistence with bidirectional sync
- **Multi-Tenant**: Organization-scoped data isolation

## Migration Phases

### Phase 0: Project Setup (Week 1)
**Status**: ✅ COMPLETED

- [x] Clone starter framework to `sertantai-legal`
- [x] Initialize new git repository
- [x] Create migration plan documentation

**Next Steps**:
- [ ] Rename project from `StarterApp` to `SertantaiLegal`
- [ ] Configure development environment
- [ ] Set up database connections

### Phase 1: Foundation & Rename (Weeks 1-2)

#### 1.1 Project Renaming
**Files to Update**:
- `backend/mix.exs` - Change `:starter_app` → `:sertantai_legal`
- `backend/lib/starter_app/` → `backend/lib/sertantai_legal/`
- `backend/lib/starter_app_web/` → `backend/lib/sertantai_legal_web/`
- `backend/config/*.exs` - Update module names and database names
- `frontend/package.json` - Update package name
- `docker-compose.dev.yml` - Update database names and container names

**Module Renames**:
```elixir
StarterApp → SertantaiLegal
StarterAppWeb → SertantaiLegalWeb
StarterApp.Api → SertantaiLegal.Api
StarterApp.Repo → SertantaiLegal.Repo
```

**Database Names**:
```
starter_app_dev → sertantai_legal_dev
starter_app_test → sertantai_legal_test
starter_app_prod → sertantai_legal_prod
```

#### 1.2 Environment Setup
- [ ] Create `.env` files for backend and frontend
- [ ] Configure Supabase connection for data import
- [ ] Set up local PostgreSQL with logical replication
- [ ] Configure ElectricSQL service
- [ ] Verify health checks work

#### 1.3 Authentication Customization
**Port from Sertantai**:
- 5-tier role system: `admin`, `support`, `professional`, `member`, `guest`
- OAuth support (if needed)
- Password reset flows
- Email verification

**Adapt to Starter**:
- Extend `SertantaiLegal.Auth.User` resource with role field
- Add role-based policies
- Configure JWT claims to include roles

### Phase 2: Core Domain Migration (Weeks 3-6)

#### 2.1 UK LRT Resource (Week 3)
**Priority**: HIGH - This is the foundation data

**Create New Resource**: `backend/lib/sertantai_legal/legal/uk_lrt.ex`

**Schema Fields** (from source `lib/sertantai/uk_lrt.ex`):
```elixir
# Core identification
- id (uuid)
- family (string)
- family_ii (string)
- name (string)
- title_en (string)
- year (integer)
- number (string)

# Classification
- type_desc (string)
- type_code (string)
- type_class (string)
- secondary_class (string)
- live (string)
- live_description (string)

# Geographic
- geo_extent (string)
- geo_region (string)

# Legal entities (JSONB)
- duty_holder (map)
- power_holder (map)
- rights_holder (map)
- purpose (map)
- function (map)

# Metadata
- md_description (string)
- acronym (string)
- old_style_number (string)
- role (array of strings)
- tags (array of strings)
- latest_amend_date (date)
- created_at (utc_datetime)
```

**Ash Actions to Implement**:
- `:read` - Basic read with pagination
- `:by_family` - Filter by family
- `:by_family_ii` - Filter by family_ii
- `:paginated` - Advanced filtering (family, year, type_code, status, search)
- `:for_applicability_screening` - Function-optimized screening (Making function only)
- `:count_for_screening` - Count applicable records

**ElectricSQL Configuration**:
```elixir
# In migration
execute "ALTER TABLE uk_lrt REPLICA IDENTITY FULL"
execute "ELECTRIC GRANT SELECT ON uk_lrt TO AUTHENTICATED WHERE true"
# Note: Initially grant to all authenticated users, add RLS later
```

**Data Import Strategy**:
1. Export from Supabase production (19K+ records)
2. Create CSV/JSON export script
3. Import to new PostgreSQL instance
4. Verify data integrity (counts, JSONB fields)
5. Test ElectricSQL replication

**Tasks**:
- [ ] Create Ash resource definition
- [ ] Generate migration with `mix ash_postgres.generate_migrations --name add_uk_lrt`
- [ ] Add ElectricSQL grants to migration
- [ ] Run migration
- [ ] Create data export script from Supabase
- [ ] Import sample dataset (1000 records for testing)
- [ ] Verify ElectricSQL sync works
- [ ] Create Svelte type definitions
- [ ] Build basic Svelte table view

#### 2.2 Organizations Domain (Week 4)
**Priority**: HIGH - Multi-tenancy foundation

**Resources to Port**:
1. `Organization` (extends starter's existing resource)
2. `OrganizationLocation` (new)
3. `OrganizationUser` (new)
4. `LocationScreening` (new)

**Organization Extensions**:
```elixir
# Add to existing Organization resource
attribute :profile_completed, :boolean, default: false
attribute :phase2_completeness, :decimal
attribute :primary_industry, :string
attribute :employee_count, :integer
attribute :annual_revenue, :decimal
attribute :compliance_status, :string
```

**OrganizationLocation Schema**:
```elixir
uuid_primary_key :id
attribute :name, :string
attribute :address_line1, :string
attribute :address_line2, :string
attribute :city, :string
attribute :postcode, :string
attribute :country, :string, default: "UK"
attribute :is_primary, :boolean, default: false
attribute :active, :boolean, default: true
belongs_to :organization, Organization
timestamps
```

**LocationScreening Schema**:
```elixir
uuid_primary_key :id
attribute :screening_type, :string  # "initial", "periodic", "change_driven"
attribute :status, :string  # "pending", "in_progress", "completed", "failed"
attribute :started_at, :utc_datetime
attribute :completed_at, :utc_datetime
attribute :applicable_laws_count, :integer
attribute :screening_data, :map  # JSONB for detailed results
belongs_to :organization_location, OrganizationLocation
belongs_to :organization, Organization
timestamps
```

**Tasks**:
- [ ] Extend Organization resource
- [ ] Create OrganizationLocation resource
- [ ] Create OrganizationUser resource
- [ ] Create LocationScreening resource
- [ ] Register all in domain: `backend/lib/sertantai_legal/api.ex`
- [ ] Generate migrations
- [ ] Add ElectricSQL grants
- [ ] Create Svelte components for organization management
- [ ] Test multi-location workflows

#### 2.3 Data Migration Scripts (Week 5-6)
**Priority**: MEDIUM - Needed before full import

**Scripts to Create**:

1. **Export from Supabase** (`scripts/export_from_supabase.exs`):
   - Connect to production Supabase
   - Export UK LRT data (all 19K records)
   - Export Organizations (if migrating existing customers)
   - Export Users (with hashed passwords)
   - Create JSON/CSV exports

2. **Import to New Database** (`scripts/import_to_sertantai_legal.exs`):
   - Batch insert UK LRT records (500 per batch)
   - Create test organizations
   - Create test users with proper roles
   - Verify foreign key relationships

3. **Data Validation** (`scripts/validate_data_import.exs`):
   - Count records in each table
   - Verify JSONB fields are valid
   - Check for missing required fields
   - Compare source vs. target counts

**Tasks**:
- [ ] Create export script
- [ ] Test export with 1000 records
- [ ] Create import script with batch processing
- [ ] Create validation script
- [ ] Run full export from Supabase
- [ ] Import to sertantai-legal dev database
- [ ] Validate data integrity
- [ ] Document export/import process

### Phase 3: Business Logic Migration (Weeks 7-12)

#### 3.1 Applicability Matching (Weeks 7-9)
**Priority**: HIGH - Core business value

**Logic to Port** (from `lib/sertantai/organizations/`):
- `applicability_matcher.ex` - Duty/rights/power matching algorithms
- `profile_analyzer.ex` - Organization profile analysis
- `progressive_query_builder.ex` - Dynamic query construction

**Adaptation Strategy**:
- **Backend**: Keep matching algorithms as Ash preparations/calculations
- **Frontend**: Use TanStack DB queries for client-side filtering
- **Hybrid**: Send organization profile to backend, get filtered UK LRT IDs, sync via ElectricSQL

**New Backend Module**: `backend/lib/sertantai_legal/matching/`
```elixir
defmodule SertantaiLegal.Matching.ApplicabilityMatcher do
  def match_applicable_laws(organization_location, filters \\ %{}) do
    # Port logic from Sertantai
    # Returns list of uk_lrt IDs that apply
  end
  
  def analyze_duty_holders(uk_lrt_record, organization_profile) do
    # Check if organization matches duty_holder criteria
  end
end
```

**Frontend Integration** (`frontend/src/lib/matching/`):
```typescript
// Client-side reactive matching
import { useQuery } from '@tanstack/query'
import { db } from '$lib/db'

export function useApplicableLaws(organizationId: string, locationId: string) {
  return useQuery({
    queryKey: ['applicable-laws', organizationId, locationId],
    queryFn: async () => {
      // Get organization profile
      const profile = await getOrganizationProfile(organizationId)
      
      // Call backend matching API
      const applicableIds = await api.post('/match-laws', { profile, locationId })
      
      // Query TanStack DB for full records
      return db.query((q) => 
        q.ukLrt.where((lrt) => applicableIds.includes(lrt.id))
      )
    }
  })
}
```

**Tasks**:
- [ ] Create `Matching` module in backend
- [ ] Port matching algorithms (duty/power/rights/purpose)
- [ ] Create backend API endpoint for matching
- [ ] Implement progressive query builder
- [ ] Create Svelte matching UI
- [ ] Test with sample organizations
- [ ] Optimize for performance (caching)

#### 3.2 AI Features (Weeks 10-11)
**Priority**: MEDIUM - Differentiating feature

**Decision**: Keep AI on backend, expose via API to Svelte frontend

**Backend AI Module** (`backend/lib/sertantai_legal/ai/`):
- Port conversation session management
- Port question generation logic
- Port response processing
- Create REST/GraphQL API endpoints

**AI Session Resource**:
```elixir
defmodule SertantaiLegal.AI.Session do
  attributes do
    uuid_primary_key :id
    attribute :session_type, :string  # "screening", "assessment"
    attribute :status, :string
    attribute :conversation_data, :map  # JSONB
    attribute :recommendations, :map
    belongs_to :organization, Organization
    belongs_to :location, OrganizationLocation
    timestamps
  end
end
```

**Frontend AI Integration**:
```typescript
// Svelte component for AI chat
import { useAiSession } from '$lib/ai/session'

const session = useAiSession(locationId)

function sendMessage(message: string) {
  session.sendMessage(message)  // Calls backend API
}

// Real-time updates via ElectricSQL if storing messages in DB
```

**Tasks**:
- [ ] Create AI domain in backend
- [ ] Port session management logic
- [ ] Create API endpoints for chat
- [ ] Build Svelte chat UI component
- [ ] Test AI conversation flows
- [ ] Add streaming responses (SSE/WebSocket)
- [ ] Integrate with applicability matching

#### 3.3 Billing & Subscriptions (Week 12)
**Priority**: MEDIUM - Revenue generation

**Port from Sertantai**:
- Stripe integration setup
- Customer, Subscription, Invoice resources
- Role-based access control
- Billing webhooks

**Backend Billing Module** (`backend/lib/sertantai_legal/billing/`):
```elixir
defmodule SertantaiLegal.Billing.Customer do
  attributes do
    uuid_primary_key :id
    attribute :stripe_customer_id, :string
    attribute :email, :string
    belongs_to :organization, Organization
    has_many :subscriptions, Subscription
  end
end

defmodule SertantaiLegal.Billing.Subscription do
  attributes do
    uuid_primary_key :id
    attribute :stripe_subscription_id, :string
    attribute :status, :string
    attribute :plan_id, :string
    attribute :current_period_end, :utc_datetime
    belongs_to :customer, Customer
  end
end
```

**Frontend Billing UI**:
- Subscription management page
- Payment method management
- Invoice history
- Upgrade/downgrade flows

**Tasks**:
- [ ] Create Billing domain resources
- [ ] Configure Stripe integration
- [ ] Create billing API endpoints
- [ ] Build Svelte billing UI
- [ ] Implement webhook handlers
- [ ] Test subscription flows
- [ ] Add role upgrades on payment

### Phase 4: Frontend Development (Weeks 13-18)

#### 4.1 Core UI Components (Weeks 13-14)
**Priority**: HIGH - User experience

**Components to Build** (`frontend/src/lib/components/`):
1. **Organization Dashboard**
   - Overview stats
   - Locations list
   - Recent screenings
   - Compliance status

2. **Location Management**
   - Add/edit locations
   - Location details
   - Screening history

3. **UK LRT Browser**
   - Searchable/filterable table
   - Law detail view
   - Applicability indicators

4. **Screening Interface**
   - Start screening wizard
   - Progress indicator
   - Results display
   - Export options

**Design System**:
- Use TailwindCSS v4
- Create reusable components
- Maintain consistent styling
- Responsive design (mobile-first)

**Tasks**:
- [ ] Set up component library structure
- [ ] Create base UI components (Button, Input, Card, etc.)
- [ ] Build dashboard layout
- [ ] Build organization management UI
- [ ] Build location management UI
- [ ] Build UK LRT browser
- [ ] Test responsive design

#### 4.2 Screening Workflow (Weeks 15-16)
**Priority**: HIGH - Core user journey

**Workflow Steps**:
1. Select organization location
2. Review/update organization profile
3. Initiate screening (triggers backend matching)
4. Display progress (loading states)
5. Show applicable laws (from TanStack DB)
6. Allow filtering/sorting results
7. Export/save screening results

**Svelte Stores** (`frontend/src/lib/stores/`):
```typescript
// Screening state management
export const screeningStore = writable({
  currentStep: 1,
  selectedLocation: null,
  profile: {},
  results: [],
  loading: false
})
```

**Tasks**:
- [ ] Design screening workflow UX
- [ ] Build multi-step wizard component
- [ ] Integrate with matching API
- [ ] Implement result display
- [ ] Add export functionality
- [ ] Test complete workflow
- [ ] Add error handling

#### 4.3 AI Chat Interface (Week 17)
**Priority**: MEDIUM - Enhanced UX

**Chat Component** (`frontend/src/lib/components/AiChat.svelte`):
- Message history display
- Input with send button
- Typing indicators
- Streaming responses
- Suggestion chips

**Integration**:
- Connect to backend AI API
- Store messages locally (TanStack DB)
- Real-time updates via ElectricSQL
- Offline support (queue messages)

**Tasks**:
- [ ] Build chat UI component
- [ ] Integrate with AI API
- [ ] Add streaming responses
- [ ] Test conversation flows
- [ ] Add message persistence
- [ ] Handle offline scenarios

#### 4.4 ElectricSQL Integration (Week 18)
**Priority**: HIGH - Core architecture

**Shapes to Configure**:
```typescript
// frontend/src/lib/electric/shapes.ts
export const shapes = {
  ukLrt: {
    table: 'uk_lrt',
    where: `true`, // All records (or filter by relevance)
  },
  organizations: {
    table: 'organizations',
    where: `id = '${currentOrgId}'`, // User's organization only
  },
  locations: {
    table: 'organization_locations',
    where: `organization_id = '${currentOrgId}'`,
  },
  screenings: {
    table: 'location_screenings',
    where: `organization_id = '${currentOrgId}'`,
  }
}
```

**Sync Strategy**:
- **UK LRT**: Sync relevant subset based on geo_extent (UK-wide initially)
- **Organizations**: Sync only user's organization data
- **Screenings**: Sync organization's screening history
- **Incremental loading**: Load more UK LRT records on demand

**Tasks**:
- [ ] Configure ElectricSQL shapes
- [ ] Implement shape streaming
- [ ] Set up TanStack DB schemas
- [ ] Test sync performance
- [ ] Add offline detection
- [ ] Handle sync conflicts
- [ ] Optimize data transfer size

### Phase 5: Testing & Migration (Weeks 19-21)

#### 5.1 Backend Testing (Week 19)
**Test Coverage Goals**: >80%

**Test Suites**:
- [ ] UK LRT resource tests (CRUD, queries, filtering)
- [ ] Organization domain tests (multi-location logic)
- [ ] Matching algorithm tests (duty/rights/power)
- [ ] AI session tests (conversation flows)
- [ ] Billing tests (subscription lifecycle)
- [ ] Authentication tests (roles, permissions)

**Tools**:
- ExUnit for unit tests
- Ash test helpers
- Factory patterns (ExMachina)

#### 5.2 Frontend Testing (Week 20)
**Test Coverage Goals**: >70%

**Test Suites**:
- [ ] Component unit tests (Vitest)
- [ ] Integration tests (screening workflow)
- [ ] E2E tests (Playwright)
- [ ] ElectricSQL sync tests
- [ ] Offline functionality tests

**Tools**:
- Vitest for unit tests
- Testing Library (Svelte)
- Playwright for E2E

#### 5.3 Data Migration (Week 21)
**Priority**: CRITICAL - Production cutover

**Pre-Migration Checklist**:
- [ ] Full backup of production Supabase
- [ ] Test import/export scripts on copy of production
- [ ] Verify all 19K+ UK LRT records transfer correctly
- [ ] Test ElectricSQL replication at scale
- [ ] Create rollback plan

**Migration Steps**:
1. **Export Phase** (During off-hours):
   - Export all UK LRT records
   - Export active organizations
   - Export users (anonymize if needed for testing)
   
2. **Import Phase**:
   - Import to staging environment
   - Validate data integrity
   - Test ElectricSQL sync
   - Performance test with real data volume
   
3. **Validation Phase**:
   - Compare record counts
   - Verify JSONB fields
   - Test critical workflows
   - User acceptance testing

4. **Cutover Plan**:
   - Deploy to production
   - Monitor for 48 hours
   - Keep old system running in parallel
   - Gradual user migration

### Phase 6: Polish & Launch (Weeks 22-24)

#### 6.1 Performance Optimization (Week 22)
- [ ] Database query optimization
- [ ] ElectricSQL shape optimization
- [ ] Frontend bundle size reduction
- [ ] Lazy loading for large datasets
- [ ] Caching strategies
- [ ] CDN configuration

#### 6.2 Documentation (Week 23)
- [ ] User guide
- [ ] Admin documentation
- [ ] API documentation
- [ ] Developer setup guide
- [ ] Deployment guide
- [ ] Troubleshooting guide

#### 6.3 Launch Preparation (Week 24)
- [ ] Security audit
- [ ] Load testing
- [ ] Backup/disaster recovery plan
- [ ] Monitoring setup (errors, performance)
- [ ] User training materials
- [ ] Marketing site updates
- [ ] Launch checklist

## Key Decisions & Trade-offs

### ✅ Decisions Made

1. **New Project vs. In-Place Migration**: New project
   - **Rationale**: Architecture too different (LiveView → ElectricSQL+Svelte)
   - **Benefit**: Clean foundation, no technical debt
   - **Cost**: More upfront work, but safer long-term

2. **Keep Elixir/Phoenix/Ash Backend**: Yes
   - **Rationale**: Core domain logic is solid, Ash is powerful
   - **Benefit**: Preserve business logic, maintain expertise
   - **Cost**: None - this is the right stack

3. **Rebuild Frontend in Svelte**: Yes
   - **Rationale**: LiveView → Svelte for offline-first capabilities
   - **Benefit**: Better mobile experience, offline support
   - **Cost**: Rebuild all UI components (~6-8 weeks)

4. **Use ElectricSQL for Sync**: Yes
   - **Rationale**: Best-in-class offline-first sync
   - **Benefit**: Real-time updates, conflict resolution
   - **Cost**: Learning curve, migration complexity

5. **Selective Library Port**: Yes
   - **Rationale**: Not all logic needs migration
   - **What to port**: Domain models, matching algorithms, billing
   - **What to rebuild**: UI, forms, real-time updates

### ⚠️ Open Questions

1. **AI Feature Scope**: Keep full AI capabilities or simplify?
   - **Option A**: Full port (conversation sessions, question gen)
   - **Option B**: Simplify to basic matching with AI explanations
   - **Recommendation**: Start with Option B for MVP, add Option A later

2. **Data Migration Strategy**: Big bang or gradual?
   - **Option A**: Full cutover (shut down old, launch new)
   - **Option B**: Parallel run (both systems active during transition)
   - **Recommendation**: Option B for 2-4 weeks to de-risk

3. **User Migration**: Automatic or opt-in?
   - **Option A**: Migrate all users automatically
   - **Option B**: Invite-only beta, then gradual rollout
   - **Recommendation**: Option B - beta with key customers first

## Risk Management

### High-Risk Areas

1. **Data Migration Integrity**
   - **Risk**: Lose data or corrupt JSONB fields during import
   - **Mitigation**: Multiple validation scripts, checksums, parallel run

2. **ElectricSQL Performance at Scale**
   - **Risk**: 19K+ records may be too much for initial sync
   - **Mitigation**: Implement shape filtering, lazy loading, pagination

3. **Frontend Rewrite Scope**
   - **Risk**: Underestimating UI complexity (LiveView → Svelte)
   - **Mitigation**: Build MVP features first, iterate on polish

4. **User Adoption**
   - **Risk**: Users resist new interface/workflow
   - **Mitigation**: Beta testing, training materials, gradual rollout

### Medium-Risk Areas

1. **Offline Sync Conflicts**
   - **Risk**: Data conflicts when users work offline
   - **Mitigation**: ElectricSQL's built-in conflict resolution, last-write-wins

2. **AI API Changes**
   - **Risk**: OpenAI API changes break functionality
   - **Mitigation**: Abstract AI provider, add fallbacks

3. **Billing Migration**
   - **Risk**: Stripe integration issues during migration
   - **Mitigation**: Test in Stripe test mode extensively, parallel billing

## Success Metrics

### Technical Metrics
- [ ] 100% data migration accuracy (19K+ UK LRT records)
- [ ] <3s initial page load
- [ ] <100ms ElectricSQL sync latency
- [ ] >80% backend test coverage
- [ ] >70% frontend test coverage
- [ ] Zero critical security vulnerabilities

### Business Metrics
- [ ] 100% of existing customers migrated
- [ ] <5% user churn during migration
- [ ] 90%+ user satisfaction with new interface
- [ ] Feature parity with old system within 6 months
- [ ] New feature velocity 2x faster (due to cleaner architecture)

### User Experience Metrics
- [ ] Offline functionality works for all core features
- [ ] Mobile-responsive design (works on phones/tablets)
- [ ] Accessibility compliance (WCAG 2.1 AA)
- [ ] Real-time updates <1s latency

## Resources Required

### Development Team
- **1x Backend Developer** (Elixir/Ash expert) - Full-time, 4-6 months
- **1x Frontend Developer** (Svelte/TypeScript expert) - Full-time, 4-6 months
- **0.5x DevOps** (Part-time for deployment/ElectricSQL setup)
- **0.5x QA** (Testing during final phases)

### Infrastructure
- **Staging Environment** - PostgreSQL + ElectricSQL + App hosting
- **Production Environment** - Scaled PostgreSQL, ElectricSQL, CDN
- **CI/CD Pipeline** - GitHub Actions or similar

### Tools & Services
- **Supabase** (existing) - Source data export
- **PostgreSQL 15+** - New production database
- **ElectricSQL Cloud** or self-hosted
- **Stripe** (existing) - Billing integration
- **OpenAI API** (existing) - AI features
- **Monitoring** - Error tracking (Sentry), performance (DataDog/New Relic)

## Next Steps

### Immediate (Week 1)
1. ✅ Create new project from starter
2. ✅ Create this migration plan
3. [ ] Rename project to SertantaiLegal
4. [ ] Set up development environment
5. [ ] Create first backend resource (UK LRT)

### This Week (Week 1-2)
1. [ ] Complete Phase 1 tasks (project setup & rename)
2. [ ] Start Phase 2.1 (UK LRT resource creation)
3. [ ] Export 1000 sample records from Supabase
4. [ ] Verify ElectricSQL sync works with sample data
5. [ ] Build basic Svelte table to display UK LRT records

### This Month (Weeks 1-4)
1. [ ] Complete Phase 1 & Phase 2.1 (UK LRT fully functional)
2. [ ] Start Phase 2.2 (Organizations domain)
3. [ ] Create data export/import scripts
4. [ ] Build organization management UI
5. [ ] Demo MVP to stakeholders

## Appendix

### A. Technology Stack Comparison

| Component | Old (Sertantai) | New (Sertantai-Legal) |
|-----------|----------------|----------------------|
| Backend Framework | Phoenix 1.7 + Ash 3.0 | Phoenix 1.7 + Ash 3.0 ✅ |
| Frontend | LiveView | SvelteKit 🔄 |
| Database | PostgreSQL | PostgreSQL ✅ |
| Real-time | LiveView Channels | ElectricSQL 🔄 |
| Auth | Ash Authentication | Ash Authentication ✅ |
| Styling | Tailwind CSS | Tailwind CSS v4 ✅ |
| AI | OpenAI + LangChain | OpenAI + LangChain ✅ |
| Billing | Stripity Stripe | Stripity Stripe ✅ |
| State Management | LiveView assigns | TanStack Query + Stores 🔄 |
| Client Storage | None | TanStack DB 🆕 |
| Offline Support | None | Full offline-first 🆕 |

✅ = Same technology  
🔄 = Different but similar  
🆕 = New capability

### B. Resource Mapping

| Sertantai Resource | Sertantai-Legal Resource | Notes |
|-------------------|-------------------------|-------|
| `Sertantai.Accounts.User` | `SertantaiLegal.Auth.User` | Extend starter's User |
| `Sertantai.Organizations.Organization` | `SertantaiLegal.Auth.Organization` | Extend starter's Org |
| `Sertantai.Organizations.OrganizationLocation` | `SertantaiLegal.Legal.OrganizationLocation` | Port directly |
| `Sertantai.Organizations.LocationScreening` | `SertantaiLegal.Legal.LocationScreening` | Port directly |
| `Sertantai.UkLrt` | `SertantaiLegal.Legal.UkLrt` | Port directly |
| `Sertantai.AI.*` | `SertantaiLegal.AI.*` | Port backend only |
| `Sertantai.Billing.*` | `SertantaiLegal.Billing.*` | Port directly |

### C. API Endpoints to Create

**Legal Domain**:
- `GET /api/uk-lrt` - List UK LRT records (paginated)
- `GET /api/uk-lrt/:id` - Get single record
- `POST /api/match-laws` - Match applicable laws for organization

**Organizations**:
- `GET /api/organizations/:id` - Get organization
- `PATCH /api/organizations/:id` - Update organization
- `GET /api/organizations/:id/locations` - List locations
- `POST /api/organizations/:id/locations` - Create location
- `POST /api/locations/:id/screen` - Start screening

**AI**:
- `POST /api/ai/sessions` - Create AI session
- `POST /api/ai/sessions/:id/messages` - Send message
- `GET /api/ai/sessions/:id` - Get session history

**Billing**:
- `GET /api/billing/subscription` - Get current subscription
- `POST /api/billing/checkout` - Create checkout session
- `POST /api/billing/portal` - Access billing portal

### D. Environment Variables

**Backend** (`.env`):
```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5435/sertantai_legal_dev
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret
PHX_HOST=localhost
PORT=4000
FRONTEND_URL=http://localhost:5173

# Supabase (for data export)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_key_here
SUPABASE_SERVICE_ROLE_KEY=your_key_here

# OpenAI
OPENAI_API_KEY=sk-your_key_here

# Stripe
STRIPE_API_KEY=sk_test_your_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_secret_here
```

**Frontend** (`.env`):
```bash
PUBLIC_API_URL=http://localhost:4000
PUBLIC_ELECTRIC_URL=http://localhost:3000
```

### E. Useful Commands

**Backend**:
```bash
cd backend

# Setup
mix deps.get
mix ash_postgres.create
mix ash_postgres.migrate
mix run priv/repo/seeds.exs

# Development
mix phx.server
iex -S mix phx.server

# Migrations
mix ash_postgres.generate_migrations --name description
mix ash_postgres.migrate

# Testing
mix test
mix credo
mix dialyzer

# Data operations
mix run scripts/export_from_supabase.exs
mix run scripts/import_to_sertantai_legal.exs
```

**Frontend**:
```bash
cd frontend

# Setup
npm install

# Development
npm run dev

# Building
npm run build
npm run preview

# Testing
npm test
npm run lint
npm run check
```

**Docker**:
```bash
# Start services
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop services
docker-compose -f docker-compose.dev.yml down
```

## Conclusion

This migration plan provides a comprehensive roadmap for building Sertantai-Legal as a modern, offline-first UK legal compliance platform. By leveraging the starter framework's solid foundation and selectively porting the proven domain logic from Sertantai, we can deliver a superior product while minimizing risk.

**Key success factors**:
1. **Incremental approach** - Build MVP first, iterate on features
2. **Thorough testing** - Don't compromise on test coverage
3. **Data integrity** - Multiple validation checkpoints for migration
4. **User feedback** - Beta testing with real users before full launch
5. **Parallel run** - Keep old system available during transition

**Estimated total effort**: 17-24 weeks (4-6 months) with a small dedicated team.

**MVP delivery**: 8-10 weeks with core screening functionality.

---

**Document Version**: 1.0  
**Created**: 2025-12-21  
**Author**: Migration Planning Team  
**Next Review**: After Phase 1 completion
