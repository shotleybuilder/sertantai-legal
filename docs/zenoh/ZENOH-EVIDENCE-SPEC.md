# Evidence Publish Schema

Arrow IPC payload for publishing generated evidence patterns from fractalaw to sertantai.

## Key Expressions

| Key Expression | Direction | Payload |
|---------------|-----------|---------|
| `fractalaw/@{tenant}/evidence/{law_name}` | fractalaw → sertantai | Arrow IPC — evidence patterns for a law (N rows, one per control) |

## Evidence Pattern Record

N rows per law — one per control's evidence pattern. Published from DuckDB `suggested_evidence` table.

| Field | Arrow Type | Description | Source |
|-------|-----------|-------------|--------|
| `law_name` | `Utf8` | Parent law identifier | staging table |
| `control_id` | `Utf8` | FK to the control this evidence pattern serves | staging table |
| `control_title` | `Utf8` | Denormalised control title for readability | staging table |
| `artefacts_json` | `Utf8` | JSON array of artefact patterns (see below) | LLM |
| `needs_judgement` | `Boolean` | Whether artefacts alone are insufficient | LLM (deterministic default) |
| `judgement_rationale` | `Utf8` | Why judgement is or isn't needed — always populated | LLM |
| `recommended_method` | `Utf8` | `Visual Inspection` / `Functional Test` / `Simulation` / `Interview` / `Observation` / `Exercise` / `Document Review` — null when needs_judgement=false | LLM |
| `basis_guidance` | `Utf8` | What the assessor should look at — null when needs_judgement=false | LLM |
| `discriminating_question` | `Utf8` | The question the judge answers — null when needs_judgement=false | LLM |
| `drift_signal` | `Utf8` | How the measurement method can decouple from reality — null when needs_judgement=false | LLM |
| `drift_conditions` | `Utf8` | When the control itself has drifted (bridges to Gaps entity) — always populated | LLM |
| `voi_quadrant` | `Utf8` | `Table Stakes` / `No-Brainer` / `Judgement` / `Waste` | LLM |
| `voi_rationale` | `Utf8` | Why this VoI classification — references control properties | LLM |
| `evidence_standard` | `Utf8` | `Basic` / `Focused` / `Comprehensive` (from blast_radius) | LLM (deterministic default) |
| `recommended_interval` | `Utf8` | How often evidence should be refreshed | LLM |
| `sample_size_guidance` | `Utf8` | For manual controls: how many instances to evidence per period | LLM |
| `staleness_tolerance` | `Utf8` | `Low` / `Medium` / `High` | LLM (deterministic default) |
| `nature_strategy` | `Utf8` | Evidence strategy from the control's Nature (Automated/Manual/hybrid) | LLM |
| `generation_model` | `Utf8` | Which model produced this pattern (e.g. `gemini-2.5-flash`) | pipeline |
| `base_hash` | `Utf8` | Deterministic hash for three-way merge on regeneration | pipeline |

### Artefact JSON Structure

The `artefacts_json` field contains a JSON array. Each element:

```json
{
  "title": "Domain-specific artefact description",
  "artefact_type": "Policy | Procedure | Certificate | Training Record | Report | Risk Assessment | Permit | Licence | Test Result | Sensor Reading | Other",
  "artefact_class": "Activity | Outcome",
  "what_it_proves": "What belief this changes — discriminating test for Outcome, activity record for Activity",
  "source": "Upload | System Generated | Sensor | External | Linked System",
  "likelihood_ratio": "Low | Medium | High",
  "recommended_frequency": "How often a new instance should be registered",
  "evidence_by_design": true
}
```

Each control has 1-3 artefacts. At least one has `artefact_class: "Outcome"` (Type-B — discriminating evidence).

### Notes

- `artefacts_json` is a JSON array string, not a nested Arrow struct. Sertantai unpacks it into individual artefact records.
- `needs_judgement` is a Boolean, derived deterministically from control properties but overridable by the LLM.
- `drift_conditions` and `judgement_rationale` are always populated, even when `needs_judgement=false`.
- Fields marked "null when needs_judgement=false" (`recommended_method`, `basis_guidance`, `discriminating_question`, `drift_signal`) will be null/empty strings for controls where artefacts alone suffice.
- `evidence_standard` maps from the control's `blast_radius`: Enterprise→Comprehensive, Site/Area→Focused, Local→Basic. The LLM can override with domain rationale.
- `staleness_tolerance` maps from `info_distance × blast_radius`: Remote+Enterprise→Low, Direct+Local→High, else Medium.
- `voi_quadrant` classifies the control on the Value of Information 2×2 (Expected Loss vs Measurement Cost). Drives where the customer should invest evidence effort.
- Customer-set fields (actual artefact instances, judge identity, assessment dates, calibration_mode) are NOT published. They are created empty on the sertantai side.

## Sertantai Handling

On receipt, sertantai should:

1. **Evidence patterns**: Upsert into an `evidence_patterns` Postgres table keyed on `(law_name, control_id)`. One row per control.
2. **Artefact templates**: Unpack `artefacts_json` into an `artefact_templates` table linked to the evidence pattern. These are templates, not operational artefacts — the customer creates actual artefact records from them.
3. **Baserow sync**: Populate the Evidence Vault Baserow template with artefact templates and judgement guidance. The VoI quadrant drives the "Evidence Priority" view.
4. **Customer scoping**: When delivering to a customer, filter to laws in their Legal Register (same as controls).
5. **Three-way merge**: On re-publish, compare `base_hash` to detect regeneration. Apply the same merge logic as controls — preserve customer edits, flag conflicts.

## Relationship to Controls

Evidence patterns are generated from controls. Each evidence pattern's `control_id` is an FK to the controls table. The publish order is:

```
1. publish-controls  →  sertantai stores controls
2. publish-evidence  →  sertantai stores evidence patterns, links to controls via control_id
```

If a control doesn't exist in sertantai when evidence arrives, sertantai should queue the evidence pattern and resolve the FK when the control is published.
