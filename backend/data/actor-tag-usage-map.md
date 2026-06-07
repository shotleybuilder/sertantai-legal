# Actor Tag Usage Map

How actor data flows through sertantai-legal. Two distinct levels that must not be conflated.

## Two Levels of Actor Data

### Law-level holders (uk_lrt / legal_register)

JSONB columns on the law record. Aggregated across all provisions by fractalaw's TaxaSubscriber.

| Column | Format | What it represents |
|--------|--------|-------------------|
| `duty_holder` | `{"values": ["Org: Employer", ...]}` | Who bears duties under this law |
| `rights_holder` | `{"values": ["Ind: Employee", ...]}` | Who has rights granted by this law |
| `responsibility_holder` | `{"values": ["Gvt: Authority", ...]}` | Government actors with responsibilities |
| `power_holder` | `{"values": ["Gvt: Minister", ...]}` | Government actors with powers |

**Used for**: profile matching, screening, change detection scoring, Baserow LRT sync, vocabulary endpoint. These are NOT changing.

### Provision-level actors (legal_articles)

Per-provision actor classification from fractalaw's ProvisionSubscriber. Grounded in Hohfeldian legal relations.

| Column | Format | What it represents |
|--------|--------|-------------------|
| `actors` | `[{label, position, relates_to, label_source, reason}]` | Structured actor data with Hohfeldian position |
| `extraction_method` | `"regex" \| "inherited" \| "agentic" \| "agentic_unvalidated"` | How actors were determined |
| `governed_actors` | `["Org: Employer", ...]` | **DEPRECATED** — flat list, no longer sent by fractalaw |
| `government_actors` | `["Gvt: Authority", ...]` | **DEPRECATED** — flat list, no longer sent by fractalaw |

**Used for**: Baserow LAT sync ("Regulated Actors" field), profile_query LAT aggregation.

## The Governed / Government Split

This is the user-facing mental model for Baserow:

- **Governed actors** = commercial entities the law regulates (Org:, Ind:, SC:, etc.)
- **Government actors** = regulators and authorities (Gvt:, EU:, Crown, HM Forces)

### How position + drrp_types maps to the user model

The `position` field tells you an actor's Hohfeldian relation to the provision's DRRP type:

| Provision DRRP type | `active` means | `counterparty` means |
|---|---|---|
| Duty | Duty-holder (must act) | Claim-holder (can demand performance) |
| Right | Right/privilege-holder | No-right holder |
| Responsibility | Responsibility-holder (government duty) | Claim-holder |
| Power | Power-holder (can alter legal relations) | Liable party |

For "Regulated Actors" in Baserow: **actors where `position = 'active'`** — these are the duty/responsibility/power holders. The label prefix (`Org:` vs `Gvt:`) is available for display grouping but `position` is the primary classification axis.

## Actor Positions (from fractalaw — Hohfeldian)

| Position | Meaning | Example |
|----------|---------|---------|
| `active` | Bears or exercises the DRRP type (the doer) | Employer bears the **duty** to ensure safety |
| `counterparty` | The other side of the legal relation | Employee holds the **claim** against that duty |
| `beneficiary` | Benefits without a direct legal relation | Public benefits from workplace safety standards |
| `mentioned` | Referenced but no active legal role | Actor named in a definition or cross-reference |

**`relates_to`** — when an active actor's obligation relates specifically to one counterparty, this names the linked actor. Null for most provisions where the relation is provision-wide.

**`reason`** — LLM reasoning for the classification. Populated for Tier 3 (agentic) provisions only.

**`label_source`** — `canonical` (in fractalaw dictionary) or `invented` (LLM-created, filter from user-facing selects).

## Where Actor Data Is Read

### Law-level holders — NO MIGRATION NEEDED

| File | What it reads | Purpose |
|------|--------------|---------|
| `screening_controller.ex:433-470` | `duty_holder->'values'`, `rights_holder->'values'` etc. on uk_lrt | Vocabulary endpoint for profile tag picker |
| `change_detector.ex:226-237` | `duty_holder->'values'`, `responsibility_holder->'values'` on uk_lrt | Match score calculation for new law detection |
| `baserow.ex:848-850` | `duty_holder`, `power_holder`, `rights_holder` on uk_lrt | Baserow LRT sync multi-select fields |
| `screening/+page.svelte:392-393` | Profile `governed_actors`, `government_actors` | Client-side seed matching |
| `profile/+page.svelte` | Profile `governed_actors`, `government_actors` | Tag picker UI |
| `org_screening_profile.ex` | `governed_actors`, `government_actors` arrays | Profile storage |

### Provision-level actors — MIGRATED

| File | Was | Now | Purpose |
|------|-----|-----|---------|
| `baserow.ex` | `lat.governed_actors` (flat) | `actors` where `position = 'active'` via `extract_active_actors/1` | Baserow LAT "Regulated Actors" field |
| `profile_query.ex` | `unnest(governed_actors)` | `jsonb_array_elements(actors)` where `position = 'active'` | LAT aggregation for export |
| `provision_subscriber.ex` | `governed_actors`, `government_actors` in @field_atoms | Removed — no longer sent by fractalaw | Zenoh payload parsing |

## Label Source

| Value | Meaning | UI treatment |
|-------|---------|-------------|
| `canonical` | Label exists in fractalaw's actor dictionary | Show in single-selects, use for matching |
| `invented` | LLM-created label, not in dictionary | Filter from user-facing single-selects. Role classification still valid. |

## Extraction Method

| Value | Meaning | Confidence |
|-------|---------|-----------|
| `regex` | Pattern-matched directly in provision text | High |
| `inherited` | Propagated from parent clause (Tier 1) | Medium-high |
| `agentic` | LLM classified, all labels canonical | Medium |
| `agentic_unvalidated` | LLM classified, some labels invented | Lower |
