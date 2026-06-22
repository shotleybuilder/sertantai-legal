# Fractalaw Actors Struct — Final Design

## Summary

Fractalaw publishes a structured `actors` column per provision via the zenoh taxa payload. This replaces the flat `governed_actors` and `government_actors` string lists with a per-actor data model grounded in [Hohfeldian legal relations](https://legaldesire.com/legal-rights-and-duties-hohfeldian-analysis/) (1913). The flat columns have been removed from the zenoh provision payload.

## Theoretical foundation

Each provision carries a DRRP classification (Duty, Right, Responsibility, Power). The actors struct classifies each actor's **position** relative to that DRRP type — whether they are the active party (bearing/exercising it) or the counterparty (on the receiving end), based on Hohfeld's four correlative pairs:

| Active party holds | Counterparty holds |
|---|---|
| **Duty** | **Claim** (can demand performance) |
| **Right/Privilege** | **No-right** (cannot prevent exercise) |
| **Power** | **Liability** (subject to the power) |
| **Immunity** | **Disability** (cannot alter the relation) |

**Note on Responsibility vs Duty:** In the DRRP taxonomy, "Responsibility" is functionally a duty — it distinguishes government obligations (responsibilities) from governed-entity obligations (duties). Both map to the same Hohfeldian duty/claim pair.

## Actors struct schema

Each provision carries an `actors` array where each entry is:

```
{
  label: String,         -- e.g. "Org: Employer", "Ind: Employee", "Gvt: Agency: HSE"
  position: String,      -- "active" | "counterparty" | "beneficiary" | "mentioned"
  relates_to: String?,   -- linked actor label for pairwise relations (null when provision-wide)
  label_source: String,  -- "canonical" | "invented"
  reason: String?        -- LLM reasoning (null for regex/inherited actors)
}
```

### Field definitions

**`label`** — the actor identity from the fractalaw actor dictionary. Prefixed by category: `Org:`, `Ind:`, `Gvt:`, `Spc:`, `SC:`, `EU:`, etc.

**`position`** — the actor's Hohfeldian position relative to the provision's DRRP type:

| Position | Meaning | Example |
|---|---|---|
| `active` | Bears or exercises the DRRP type (the doer) | Employer bears the **duty** to ensure safety |
| `counterparty` | The other side of the legal relation | Employee holds the **claim** against that duty |
| `beneficiary` | Benefits from the provision without a direct legal relation | Public benefits from workplace safety standards |
| `mentioned` | Referenced in the text but no active legal role | Actor named in a definition or cross-reference |

Reading `position` together with the provision's `drrp_types`:

| Provision DRRP type | `active` means | `counterparty` means |
|---|---|---|
| Duty | Duty-holder (must act) | Claim-holder (can demand performance) |
| Right | Right/privilege-holder | No-right holder (cannot prevent) |
| Responsibility | Responsibility-holder (government duty) | Claim-holder (can demand performance) |
| Power | Power-holder (can alter legal relations) | Liable party (subject to the power) |

**`relates_to`** — when an active actor's obligation relates specifically to one counterparty rather than all counterparties in the provision, this field names the linked actor. Null for most provisions where the relation is provision-wide. Example: CDM 2015 where a Client has a duty specifically to the Principal Designer — `relates_to: "SC: C: Principal Designer"`.

**`label_source`** — provenance of the label:
- `canonical` — label exists in the fractalaw actor dictionary
- `invented` — label was created by the Tier 3 LLM and does not match any dictionary entry. The position classification is still valid signal, but the label may need mapping. Sertantai should filter `invented` labels from user-facing single-selects.

**`reason`** — the LLM's reasoning for this classification. Only populated for Tier 3 (agentic) provisions. Null for regex and inherited actors. Useful for QA review and improving the classification pipeline.

### What this replaces

The old model had two flat columns:
- `governed_actors` — businesses, individuals (`Org:`, `Ind:`, `SC:`, `Spc:` prefixes)
- `government_actors` — authorities, agencies (`Gvt:`, `EU:` prefixes)

Both listed actors as undifferentiated "holders" regardless of whether they bore a duty, exercised a power, or held a right. The governed/government split was a proxy for the Hohfeldian active/counterparty distinction but failed for dual-role actors (e.g., Crown as both sovereign authority and duty-bearing employer) and lost the DRRP alignment entirely.

The label prefixes (`Org:`, `Gvt:`, etc.) remain available for display grouping but are no longer the primary classification axis — `position` is.

### `extraction_method` values

Per-provision (not per-actor), indicates how actors were determined:
- `regex` — actors found directly in the provision text by pattern matching
- `inherited` — actors propagated from a parent clause (Tier 1 deterministic)
- `classifier` — trained logistic regression model (86.4% accuracy, embedding + modal features). This is the production classifier that replaced LLM calls for bulk processing.
- `local` — local Gemma 4B model via Ollama (CPU inference, development/testing)
- `agentic` — Gemini 2.5 Flash classified positions, all labels canonical. Highest quality — development/QA workflow.
- `agentic_unvalidated` — Gemini/Gemma classified positions but one or more labels are `invented`. Filter `label_source: invented` actors from user-facing selects.

### Actor Dictionary — Single Source of Truth

The canonical actor labels and their trigger phrases are defined in a shared YAML file:

**`fractalaw/docs/actor-dictionary.yaml`** (tracked in git)

Sertantai should use this file as its actor label reference. The YAML provides:

```yaml
- canonical: "Org: Employer"
  category: Org
  triggers: [employer, employers, the employer]
```

- `canonical` — the label that appears in the actors struct
- `category` — the prefix group (Org, Gvt, Ind, SC, etc.) for display grouping
- `triggers` — natural language names that map to this label (lowercase)

**How to use:**
- Load the YAML on startup or deployment
- Use `canonical` for data storage and filtering
- Use `category` for UI grouping (governed vs government)
- Use `triggers` if sertantai needs to do its own actor name matching
- The YAML is version-controlled — changes are tracked via git

**Label format:** Colon-space prefixed (e.g., `Org: Employer`, `Gvt: Agency: HSE`). Sertantai can display these as-is or map to a different format for its UI.

**Discoveries:** The LLM may name actors not in the dictionary. These get `label_source: invented` in the actors struct. Sertantai should filter invented labels from user-facing single-selects. Discoveries are reviewed and added to the YAML periodically — sertantai picks them up on next refresh.

### Schedule provisions

Fractalaw's LanceDB may contain schedule-level provisions that sertantai's LAT parser doesn't produce. These are expected orphans — sertantai correctly skips them during ingest ("N skipped — not in LAT"). Schedule provisions don't create new DRRP — they amplify the main body regulations.

## Examples

### Duty provision — employer safety obligation

```json
{
  "section_id": "UK_ukpga_1974_37:s.2(1)",
  "drrp_types": ["DUTY"],
  "extraction_method": "regex",
  "actors": [
    {"label": "Org: Employer", "position": "active", "relates_to": null, "label_source": "canonical", "reason": null},
    {"label": "Ind: Employee", "position": "counterparty", "relates_to": null, "label_source": "canonical", "reason": null}
  ]
}
```
Employer bears the duty (active). Employee holds the claim against that duty (counterparty).

### Power provision — inspector enforcement

```json
{
  "section_id": "UK_ukpga_1974_37:s.21",
  "drrp_types": ["POWER"],
  "extraction_method": "agentic",
  "actors": [
    {"label": "Spc: Inspector", "position": "active", "relates_to": "Ind: Person", "label_source": "canonical", "reason": "inspector may serve an improvement notice"},
    {"label": "Ind: Person", "position": "counterparty", "relates_to": null, "label_source": "canonical", "reason": "person is subject to the improvement notice"}
  ]
}
```
Inspector exercises the power (active, specifically directed at Person via `relates_to`). Person is liable/subject to it (counterparty).

### Duty provision — information to employees

```json
{
  "section_id": "UK_ukpga_1974_37:s.28(8)(a)",
  "drrp_types": ["DUTY"],
  "extraction_method": "agentic",
  "actors": [
    {"label": "Spc: Inspector", "position": "active", "relates_to": null, "label_source": "canonical", "reason": "inspector shall give factual information"},
    {"label": "Ind: Person", "position": "counterparty", "relates_to": null, "label_source": "canonical", "reason": "persons employed can demand this information"},
    {"label": "Org: Employer", "position": "mentioned", "relates_to": null, "label_source": "canonical", "reason": "employer is referenced but does not act in this sub-clause"}
  ]
}
```

## Migration path

### Phase 1 (now): Read actors struct
- Parse the `actors` column from the zenoh provision taxa payload
- Use `position` + provision `drrp_types` to determine the actor's legal relation
- Filter on `label_source == "canonical"` for user-facing single-selects
- `relates_to` can be used for detailed actor-to-actor relationship display or ignored initially

### Phase 2: Drop flat columns entirely
- Stop reading `governed_actors` and `government_actors`
- Fractalaw has already removed these from the zenoh provision payload
- The governed/government label prefix (`Org:` vs `Gvt:`) remains on the label for display grouping

## Wire format

The actors struct is a native Arrow `List<Struct>` in the zenoh Arrow IPC payload — a proper Arrow nested type, not JSON. Sertantai's Arrow IPC decoder should handle it natively.

## References

- [Hohfeldian Legal Relations](https://legaldesire.com/legal-rights-and-duties-hohfeldian-analysis/) — theoretical foundation
- [LKIF-Core norm.owl](https://github.com/RinkeHoekstra/lkif-core) — legal ontology validation
- Gemini design review: `fractalaw/docs/reviews/gemini-actors-struct-review-20260607.md`
- Fractalaw design doc: `docs/GAP-C-AGENTIC-EXTRACTION-PLAN.md`
