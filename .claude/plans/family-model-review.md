# Family / Family II Model Review

**Date**: 2026-05-05
**Context**: After QA of all 💚 and 💙 families (~320 reclassifications, FINANCE elimination)

## Current State

- **51 distinct families** across 3 domains (💙 Safety, 💚 Environment, 💜 HR)
- **12,741 laws** with family assigned (66% of 19,330 total)
- **1,552 laws** with family_ii (12.2% of those with family)
- Family_ii is underused — mostly populated during QA sessions, not by the parser

## Purpose Reminder

Family is a **rough-cut filter** for users to find laws relevant to their sector/operations.
Not as granular as SI codes (which are legislation.gov.uk's own taxonomy, ~300+ values).
Both can be used together: Family narrows the domain, SI codes refine within it.

---

## Recommendations

### 1. LARGE FAMILIES THAT COULD SPLIT

#### 💚 AGRICULTURE (1,017 laws) — consider split

The largest family. Contains distinct sub-domains:
- **Agricultural subsidies/payments** (CAP, arable area payments, rural development) — ~400 laws
- **Organic production** (organic labelling, certification) — ~30 laws
- **Agricultural trade** (import/export of animal products, bovine products) — ~50 laws
- **Agricultural land** (crofting, tenancy, small holdings) — ~60 laws
- **Horticulture** (SI code HORTICULTURE, 42 occurrences) — currently absorbed

**Recommendation**: Don't split yet. The sub-domains are too intertwined (a single SI often covers multiple). 💚 AGRICULTURE: Pesticides already exists as the one clear sub-family. If a split becomes useful for user filtering, **Organic** (labelling/certification) is the cleanest candidate — it's a distinct regulatory regime.

#### 💚 WILDLIFE & COUNTRYSIDE (864 laws) — split opportunity

Two distinct user audiences:
- **Wildlife protection** (species protection, CITES, habitats, bird directives) — ~400 laws
- **Countryside access & land management** (national parks, commons, rights of way, ESA schemes, countryside stewardship) — ~400 laws

The 209 laws with SI code AGRICULTURE are almost all **agri-environment schemes** (Environmentally Sensitive Areas, Countryside Stewardship). These serve farmers who manage land for biodiversity — a different user than someone checking species protection compliance.

**Recommendation**: Consider splitting into:
- `💚 WILDLIFE: Species & Habitats` (species protection, CITES, conservation of habitats)
- `💚 COUNTRYSIDE: Access & Land Management` (national parks, commons, rights of way, agri-environment)

This maps to a real user distinction: a developer checking for protected species vs a land manager checking countryside access obligations.

#### 💚 ENERGY (800 laws) — family_ii is the solution, not splitting

Contains electricity supply (276), gas supply (109), infrastructure DCOs (142), energy policy (126), fiscal (62). But these overlap heavily — an electricity generating station DCO touches infrastructure + electricity + planning.

**Recommendation**: Don't split. Instead, improve family_ii coverage:
- Infrastructure DCOs → family_ii: 💚 PLANNING & INFRASTRUCTURE (120 already done)
- Fiscal instruments → family_ii: 💚 FINANCE (62 already done)
- The electricity/gas/general split isn't useful for users — "energy" is the right level

#### 💚 ANIMALS & ANIMAL HEALTH (835 laws) — well-scoped

SI codes: ANIMALS (753), ANIMAL HEALTH (536), PREVENTION OF CRUELTY (36), VETERINARY SURGEONS (15). These are genuinely one domain — animal health, welfare, and disease control are inseparable in UK regulation.

**Recommendation**: Keep as-is. Family_ii already captures the agricultural crossover (27 laws with family_ii: 💚 AGRICULTURE).

#### 💚 FISHERIES & FISHING (655 laws) — could benefit from family_ii

Clear sub-domains visible in SI codes:
- Sea fisheries (412) — commercial fishing quotas, vessel licensing
- Conservation of sea fish (179) — stock management, minimum sizes
- Freshwater (54 — river + salmon) — salmon/trout fishing, river management
- Aquaculture (11) — fish farming

**Recommendation**: Don't split primary family. Use family_ii to distinguish:
- Freshwater fishing laws → family_ii: 💚 MARINE & RIVERINE (for river context)
- Aquaculture laws → already correctly here, but consider family_ii: 💚 ANIMALS & ANIMAL HEALTH for fish health regulations

### 2. SMALL FAMILIES TO CONSIDER MERGING

#### 💚 TRANSPORT (7 laws) — merge into sub-families

Only 7 laws (generic Transport Act commencements). Too small to be useful as a filter.

**Recommendation**: Redistribute into specific transport sub-families based on what each Act commences, or keep as catch-all for truly cross-modal transport legislation.

#### 💚 TRANSPORT: Aviation (12 laws) — very small

Only 12 laws after removing APD interest rate instruments. Consider whether this adds value as a separate family vs merging into 💙 TRANSPORT: Air Safety.

**Recommendation**: Keep separate — environmental (noise, emissions) vs safety is a real distinction. But monitor — if it stays this small, merge.

### 3. FAMILIES THAT NEED BETTER FAMILY_II COVERAGE

| Family | Laws | Has family_ii | % | Priority |
|--------|------|--------------|---|----------|
| 💚 AGRICULTURE | 1,017 | 16 | 1.6% | Low — fairly homogeneous |
| 💚 WILDLIFE & COUNTRYSIDE | 864 | 10 | 1.2% | **High** — split signal |
| 💚 ANIMALS & ANIMAL HEALTH | 835 | 33 | 4.0% | Medium |
| 💚 ENERGY | 800 | 195 | 24.4% | Done — good coverage |
| 💚 WASTE | 671 | 111 | 16.5% | Done — mostly FINANCE |
| 💚 FISHERIES & FISHING | 655 | 12 | 1.8% | Medium — freshwater/marine |
| 💚 PLANT HEALTH | 601 | 25 | 4.2% | Low — homogeneous |
| 💙 HEALTH: Coronavirus | 558 | 3 | 0.5% | Low — static (2020-2025) |

### 4. SI CODES WITHOUT FAMILY REPRESENTATION

These SI codes appear frequently but don't map to any family:

| SI Code | Occurrences | Suggested Family |
|---------|------------|-----------------|
| GOVERNMENT RESOURCES AND ACCOUNTS | 43 | Not EHS — exclude |
| PENSIONS | 38 | Not EHS — exclude |
| PROTECTION OF VULNERABLE ADULTS | 24 | 💙 HEALTH: Public (social care) |
| HEALTH AND PERSONAL SOCIAL SERVICES | 21 | 💙 HEALTH: Public |

**Recommendation**: PROTECTION OF VULNERABLE ADULTS and HEALTH AND PERSONAL SOCIAL SERVICES could be absorbed into 💙 HEALTH: Public if the laws are genuinely public health. Check first — they may be social care legislation outside EHS scope.

### 5. STRUCTURAL OBSERVATIONS

#### The 💙/💚/💜 prefix system works well
- 💙 Safety (direct harm to people) — well-defined, stable
- 💚 Environment (ecological/land/resource) — largest domain, mostly clean after QA
- 💜 HR (employment/workplace rights) — small, stable

#### FINANCE as family_ii-only is the right model
The FINANCE → domain reclassification was the biggest structural improvement. It demonstrates a principle: **mechanism families should be family_ii, domain families should be primary**. Future candidates for the same treatment: none currently — FINANCE was the only mechanism-as-primary.

#### The 6,589 unclassified laws (34%)
These are laws without any family. Many are:
- Very old legislation (pre-1900)
- Procedural SIs (commencement, transitional)
- Cross-cutting instruments that don't fit one family
- Genuinely outside EHS scope

This is not a problem — forcing classification on laws that don't fit would reduce family quality.

---

## Priority Actions

1. **Short term**: Populate family_ii for FISHERIES freshwater/marine distinction
2. **Medium term**: Evaluate WILDLIFE & COUNTRYSIDE split based on user feedback
3. **Parser**: Wire up family_ii auto-assignment (#83) for fiscal SI codes and documented keyword implications
4. **Monitoring**: After each scrape of new laws, run enacted-by-family-qa to catch misclassifications early

---

## Responses to Challenges (2026-05-05)

### WILDLIFE & COUNTRYSIDE split — AGREED, proceed

The two user groups are clearly distinguishable:
- **Species/habitat compliance officer**: "Do I need a protected species licence for this site?"
- **Land manager / access officer**: "What are the access rights and land management obligations?"

Proposed split:
- `💚 WILDLIFE: Species & Habitats` — species protection, CITES, habitats directives, bird directives, invasive species
- `💚 COUNTRYSIDE: Access & Land Management` — national parks, commons, rights of way, ESA/Countryside Stewardship, coastal access

The 209 laws with AGRICULTURE SI code (agri-environment schemes) would go to COUNTRYSIDE — they serve land managers, not species ecologists. SI codes WILDLIFE vs COUNTRYSIDE already distinguish most laws cleanly.

### FISHERIES & FISHING — SI codes ARE comprehensive, so DON'T split

The SI code coverage is strong:
- SEA FISHERIES alone tags 412/655 (63%)
- CONSERVATION OF SEA FISH adds another 179
- RIVER + SALMON covers the freshwater sub-set (32)
- FISH FARMING + AQUACULTURE covers aquaculture (11)
- Only 137 have the generic FISHERIES code, and most of these are resolvable by title (inshore districts, NI byelaws, aquaculture schemes)

**Verdict**: Users can already filter sea vs freshwater vs aquaculture using SI codes. A family split would duplicate what SI codes already provide. Family_ii (freshwater → MARINE & RIVERINE) is sufficient for the crossover cases.

### TRANSPORT + TRANSPORT: Aviation — under-trawled, not empty

The small populations are a trawl gap, not a domain size issue. Unclassified laws with transport SI codes:
- ROAD TRAFFIC: **717** unclassified
- CIVIL AVIATION: **165** unclassified
- MERCHANT SHIPPING: **84** unclassified
- RAILWAYS: **28** unclassified
- PUBLIC PASSENGER TRANSPORT: **34** unclassified

These are massive untapped populations. Once trawled, the transport families will be substantial. The current counts (TRANSPORT: 7, Aviation: 12) reflect incomplete scraping, not the true scope.

**Action**: Transport trawl is a separate work item — scrape/classify the ~1,000+ unclassified transport laws. This will naturally grow the transport families to meaningful sizes.

### AGRICULTURE — user group analysis

Title pattern analysis of 1,017 laws reveals these user groups:

| User Group | Pattern | Laws | Distinct Regime? | Split Candidate? |
|-----------|---------|------|-------------------|-----------------|
| Feed manufacturers | Animal Feed (composition, safety, hygiene, labelling) | 170 | **Yes** — EU Feed Law is a separate regulatory framework | **Yes** → `💚 AGRICULTURE: Animal Feed` |
| Farmers claiming payments | Subsidies, payments, CAP schemes, BPS | 256 | Partially — intertwined with commodity-specific rules | No — too cross-cutting |
| Organic producers | Organic production, labelling, certification | 45 | **Yes** — distinct EU organic certification regime | **Possible** → `💚 AGRICULTURE: Organic` |
| Traders/importers | Import/export, phytosanitary, trade controls | 69 | Partially — overlaps with animal health import controls | No — better as family_ii |
| Farm tenants/landlords | Agricultural holdings, tenancies, crofting | ~50 | Yes — Agricultural Holdings Acts | No — too small (50 laws) |
| Commodity-specific | Dairy (28), Beef (26), Pigs (13), Poultry (10), Cereals (1) | ~80 | No — each too small, and intertwined | No |
| General | Agricultural Holdings, intervention boards, misc | ~350 | No | No |

**Strongest split candidate: `💚 AGRICULTURE: Animal Feed` (170 laws)**

The feed manufacturer is a genuinely different user from the farmer or food producer:
- Feed mills need feed composition, additive, and hygiene regulations
- They don't need CAP payment rules or tenancy law
- The regulatory regime is distinct (Feed Law, derived from EU Regulation 183/2005)
- Titles are highly consistent ("Animal Feed...", "Feeding Stuffs...", "Feed...")
- SI codes are primarily AGRICULTURE but titles make classification trivial

**Secondary candidate: `💚 AGRICULTURE: Organic` (45 laws)**

Organic certification is a distinct regime (EU Regulation 834/2007 and successors). The user is the organic producer or certifier. However, at 45 laws it's a small family — similar to AGRICULTURE: Pesticides (40). This follows the established sub-family pattern.

**Recommendation**: Create `💚 AGRICULTURE: Animal Feed`. Defer Organic until user demand confirms it's useful for filtering.

---

## Updated Priority Actions

1. **Implement**: Split WILDLIFE & COUNTRYSIDE into Species/Habitats + Countryside/Access
2. **Implement**: Create `💚 AGRICULTURE: Animal Feed` sub-family (170 laws)
3. **Trawl**: Classify ~1,000 unclassified transport laws to grow transport families
4. **Parser**: Wire up family_ii auto-assignment (#83)
5. **Defer**: FISHERIES split (SI codes already sufficient), AGRICULTURE: Organic (wait for user demand)
