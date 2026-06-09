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

**Used for**: profile matching, screening, change detection scoring, Baserow LRT sync. These are NOT changing.

**Note**: The vocabulary endpoint no longer queries these columns for actor labels. It reads from the ActorDictionary (Zenoh + YAML snapshot) instead.

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

## Actor Dictionary

Single source of truth for canonical actor labels. Loaded from fractalaw via Zenoh, falls back to YAML snapshot.

**Source**: `fractalaw/@{tenant}/dictionary/actors` (Zenoh queryable + subscriber)
**Snapshot**: `backend/priv/data/actor-dictionary.yaml`
**Module**: `SertantaiLegal.Legal.ActorDictionary`

| Function | Returns | Used by |
|----------|---------|---------|
| `canonical_labels/0` | All canonical labels | Baserow vocabulary validation |
| `governed_labels/0` | Non-government labels (Org, Ind, SC, etc.) | Vocabulary endpoint, profile tag picker |
| `government_labels/0` | Government labels (Gvt, EU) | Vocabulary endpoint, profile tag picker |
| `category/1` | Category for a label ("Org", "Gvt", etc.) | Display grouping |
| `valid?/1` | Is this label in the dictionary? | Filter invented labels |
| `government?/1` | Is this a government actor? | Governed/government split |

**Replaces**:
- Hardcoded `@holder_options` list in baserow.ex (was 156 entries, now dynamic)
- DB queries for actor labels in vocabulary endpoint (was querying `duty_holder->'values'`)

**Auto-updates**: Subscribes to Zenoh dictionary publishes. When fractalaw discovers new actors and updates the YAML, sertantai picks them up automatically.

## Label Source

| Value | Meaning | UI treatment |
|-------|---------|-------------|
| `canonical` | Label exists in fractalaw's actor dictionary | Show in single-selects, use for matching |
| `invented` | LLM-created label, not in dictionary | Filter from user-facing single-selects. Role classification still valid. |

## Extraction Method

| Value | Meaning | Finds positions | Confidence |
|-------|---------|----------------|-----------|
| `regex` | Pattern-matched in provision text. Used for sub-provision fragments (paragraphs, schedules, headings) | Active only | High |
| `classifier` | Trained logistic regression model (86.4% accuracy). Runs on regulation-level provisions (article, section) | Active + counterparty + mentioned | High |
| `inherited` | Propagated from parent clause (Tier 1 deterministic) | Active only | Medium-high |
| `agentic` | Gemini 2.5 Flash LLM, all labels canonical. Highest quality | All 4 positions | Medium |
| `agentic_unvalidated` | LLM classified, some labels invented | All 4 positions | Lower |
| `local` | Local Gemma 4B via Ollama (dev/testing) | Varies | Dev only |

**Note**: The classifier deliberately skips sub-provision fragments (paragraphs, sub_paragraphs, schedules, etc.) — these keep `extraction_method = "regex"` and inherit actors from their parent regulation. This is expected behaviour, not a gap.
