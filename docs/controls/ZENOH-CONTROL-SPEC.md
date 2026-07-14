# Controls Publish Schema

Arrow IPC payload for publishing generated controls from fractalaw to sertantai.

## Key Expressions

| Key Expression | Direction | Payload |
|---------------|-----------|---------|
| `fractalaw/@{tenant}/controls/{law_name}` | fractalaw → sertantai | Arrow IPC — controls for a law (N rows) |
| `fractalaw/@{tenant}/controls/predicate/{law_name}` | fractalaw → sertantai | Arrow IPC — policy predicate (1 row) |

## Controls Record

N rows per law — one per generated control. Published from DuckDB `suggested_controls` table.

| Field | Arrow Type | Description | Source |
|-------|-----------|-------------|--------|
| `law_name` | `Utf8` | Parent law identifier | staging table |
| `control_id` | `Utf8` | UUID — stable identifier for three-way merge | staging table |
| `title` | `Utf8` | Indicative-mood control statement | LLM |
| `description` | `Utf8` | What reality the control stands for | LLM |
| `what_it_checks` | `Utf8` | The discriminating test (Type-B) | LLM |
| `control_type` | `Utf8` | `Preventive` / `Detective` / `Corrective` / `Directive` | LLM |
| `nature` | `Utf8` | `Manual` / `Automated` / `IT-dependent manual` | LLM |
| `domain` | `Utf8` | `Organisational` / `People` / `Physical` / `Technical` | LLM |
| `frequency` | `Utf8` | `Continuous` / `Daily` / `Weekly` / `Monthly` / `Quarterly` / `Annual` / `Ad-hoc` | LLM |
| `info_distance` | `Utf8` | `Direct` / `Adjacent` / `Mediated` / `Remote` (AI default) | LLM |
| `blast_radius` | `Utf8` | `Local` / `Area` / `Site` / `Enterprise` (AI default) | LLM |
| `expected_touch_frequency` | `Utf8` | How often the control is exercised under normal demand | LLM |
| `linked_provisions` | `List<Utf8>` | Full section_ids (e.g. `["UK_uksi_1997_1713:reg.3(1)"]`) or short refs (e.g. `["reg.3(1)"]`) | LLM |
| `mapping_strength` | `Utf8` | `Primary` / `Supporting` / `Ancillary` | LLM |
| `load_bearing_judgement` | `Utf8` | The irreducible judgement term, or null | LLM |
| `evidence_type_a` | `Utf8` | Activity evidence description (legible proxy) | LLM |
| `evidence_type_b` | `Utf8` | Outcome evidence description (discriminating test) | LLM |
| `honest_limit` | `Utf8` | What resists reduction to a checkable predicate, or null | LLM |
| `status` | `Utf8` | `Planned` — all AI-generated controls start as Planned | fixed |
| `tier` | `Utf8` | `Jurisdiction` — derived from law | fixed |
| `generation_model` | `Utf8` | Which model produced this control | pipeline |
| `base_hash` | `Utf8` | Deterministic hash for three-way merge on regeneration | pipeline |

### Notes

- `linked_provisions` may contain **full section_ids** (e.g. `UK_uksi_1997_1713:reg.3(1)`) or **short refs** (e.g. `reg.3(1)`). Sertantai detects the format and handles both — if the value starts with `{law_name}:`, it's used as-is; otherwise the `law_name` is prepended. The section prefix must match the law's type_code: `reg.` for uksi/ssi, `s.` for ukpga, `art.Article\u00a0` (with NBSP) for eudr.
- `info_distance` and `blast_radius` are AI-estimated defaults. Sertantai should display them as "AI-suggested — override with your operational context."
- `evidence_type_a` and `evidence_type_b` are flattened from the JSON `evidence_hint` object for Arrow compatibility.
- Customer-set fields (`Owner`, `Org_Unit`, `Location`, `External_Ref`, `Demand_Mode`, `Design_Effectiveness`, `Operating_Effectiveness`, `Last_Verified`) are NOT published. They are created empty on the sertantai side for the customer to fill.

## Policy Predicate Record

1 row per law — the law's "big idea" as a checkable proposition.

| Field | Arrow Type | Description | Source |
|-------|-----------|-------------|--------|
| `law_name` | `Utf8` | Parent law identifier | staging table |
| `predicate_id` | `Utf8` | UUID | staging table |
| `title` | `Utf8` | The policy predicate — one indicative sentence | LLM |
| `description` | `Utf8` | What the predicate stands for | LLM |
| `what_it_checks` | `Utf8` | How you'd know it's true or has drifted | LLM |
| `honest_limit` | `Utf8` | The irreducible judgement, or null | LLM |
| `generation_model` | `Utf8` | Which model produced this | pipeline |
| `base_hash` | `Utf8` | For three-way merge | pipeline |

## Sertantai Handling

On receipt, sertantai should:

1. **Controls**: Upsert into a `controls` Postgres table keyed on `(law_name, control_id)`. Create corresponding Control Mapping rows linking each control to its `linked_provisions` section_ids.
2. **Predicates**: Upsert into the same or a separate table keyed on `(law_name, predicate_id)`. The predicate maps at law level with Primary strength.
3. **Baserow sync**: Populate the Controls and Control Mappings Baserow templates from the Postgres tables.
4. **Customer scoping**: When delivering to a customer, filter the controls table to laws in their Legal Register.

## Trigger: Control Generation Request

Sertantai triggers control generation by publishing to:

| Key Expression | Direction | Payload |
|---------------|-----------|---------|
| `fractalaw/@{tenant}/events/controls` | sertantai → fractalaw | JSON — control generation request |

```json
{
  "action": "generate",
  "laws": ["UK_uksi_1997_1713", "UK_uksi_1999_3242"],
  "force": false
}
```

| Field | Type | Description |
|-------|------|-------------|
| `action` | `string` | `generate` (run pipeline) or `publish` (re-publish existing) |
| `laws` | `string[]` | Law names to process. Empty = all applicable. |
| `force` | `boolean` | If true, regenerate even if controls exist |

Fractalaw's sync watch handler receives this event, runs `generate_controls.py` for the requested laws, and publishes the results back on the controls key expressions.
