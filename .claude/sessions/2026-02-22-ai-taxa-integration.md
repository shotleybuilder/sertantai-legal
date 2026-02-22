# AI Taxa (DRRP) Integration

**Started**: 2026-02-22
**Ended**: 2026-02-22
**Related**: 2026-02-02-taxa-parser-responsibilities.md, 2026-02-03-ai-responsibility-parsing.md
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/17

## Context

Regex pipeline (V2 patterns + ClauseRefiner) handles ~90% of DRRP extraction. AI service on LAN picks up the remaining edge cases. Async pull model — no external services.

**Architecture:**
```
sertantai-legal (this project)           AI service (LAN machine)
┌──────────────────────────────┐         ┌────────────────────┐
│ GET /api/ai/drrp/clause/queue│ ◄─pull──│ Fetches work items │
│ (low-confidence entries)     │         │ Runs LLM extraction│
│                              │         │                    │
│ Result puller (GenServer)    │──pull──► │ GET /results       │
│ (fetches completed clauses)  │         │ (completed clauses) │
└──────────────────────────────┘         └────────────────────┘
```

- AI service pulls work from our queue endpoint
- We pull completed results from the AI service
- Completely async — no blocking, no timeouts on LLM processing

## Todo

- [x] Design queue/results schema — no new tables, queue is a query over existing DRRP entries
- [x] Define payload format (what goes to AI, what comes back)
- [x] Create `GET /api/ai/drrp/clause/queue` endpoint (serializer over existing DRRP entries) — `be25674`
- [x] Auth for AI service endpoints — API key via `X-API-Key` header (`AiApiKeyPlug`) — `be25674`
- [x] Add `regex_clause_confidence` scoring to regex DRRP pipeline — `f052d31`
- [ ] Create result puller — fetch completed clauses from AI service and write back to DRRP entries (Phase 2)
- [ ] Integrate results back into taxa DRRP fields (Phase 2)

## DRRP JSONB Schema

Each of `duties`, `responsibilities`, `rights`, `powers` is a JSONB column on `uk_lrt` with identical structure:

```json
{
  "entries": [
    {
      "holder": "Gvt: Authority",
      "article": "regulation/7",
      "duty_type": "RESPONSIBILITY",
      "clause": "the authority must consult the relevant bodies..."
    }
  ],
  "holders": ["Gvt: Authority", "Gvt: Minister"],
  "articles": ["regulation/7", "regulation/15"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `entries[].holder` | string | Typed actor, e.g. `Gvt: Authority: Local`, `Ind: Person`, `Org: Owner` |
| `entries[].article` | string | Section/regulation ref, e.g. `regulation/14`, `section/3` |
| `entries[].duty_type` | string | `DUTY` / `RESPONSIBILITY` / `RIGHT` / `POWER` |
| `entries[].clause` | string | Regex-extracted clause text |
| `entries[].regex_clause_confidence` | float | `0.0`–`1.0` regex extraction confidence — low values queue for AI |
| `entries[].ai_clause` | string/null | AI-refined clause text (null until AI processes) |
| `holders` | string[] | Deduplicated list of all holders |
| `articles` | string[] | Deduplicated list of all articles |

**Coverage:** ~2,500-2,600 records have at least one DRRP field populated (of 19,318 total).

Legacy flat fields also exist (`duty_holder`, `power_holder`, `rights_holder`, `responsibility_holder`) as simpler maps — the consolidated `duties`/`responsibilities`/`rights`/`powers` are the canonical source.

## Payload Format

### Field Mapping (AI service ↔ our schema)

| AI service field | Our schema field | Notes |
|-----------------|-----------------|-------|
| `law_name` | `name` | e.g. `"UK_uksi_2024_702"` |
| `provision` | `entries[].article` | Ours: `"regulation/3"`, AI: `"s.3"` — needs converter |
| `drrp_type` | `entries[].duty_type` | Ours: `"DUTY"`, AI: `"duty"` — normalize case |
| `regex_clause` | `entries[].clause` | Regex-extracted clause text sent to AI for refinement |
| `confidence` | `entries[].regex_clause_confidence` | `0.0`–`1.0` float, regex extraction confidence |
| `scraped_at` | `updated_at` | No new field — map from existing timestamp |
| `source_text` | *(AI resolves itself)* | AI has full legislation, looks up by `law_name` + `provision` |

**Notes on mapping:**
- `provision` notation: our `article` uses slash form (`"regulation/3"`, `"section/2"`), AI uses compact form (`"s.3"`, `"s.2(1)"`) — needs bidirectional converter
- `drrp_type` casing: uppercase in our DRRP entries, lowercase in AI payload — normalize at the boundary
- `source_text`: not stored in our DB — the AI service has its own copy of full legislation text and resolves it from `law_name` + `provision`

### New fields on DRRP entries

**`regex_clause_confidence`** (float, 0.0–1.0): How confident the regex pipeline was in its extraction. Low values queue the entry for AI review.

**`ai_clause`** (string, null): The AI-refined clause text. `null` means the AI hasn't processed this entry yet. The queue endpoint filters on `regex_clause_confidence < threshold AND ai_clause IS NULL`. Receiving an AI result populates `ai_clause`.

No new tables — the queue is a query, the endpoint is a serializer. Presence of `ai_clause` is the "processed" flag — no separate boolean needed.



### Queue item (GET /api/ai/drrp/clause/queue) — what AI service pulls

Primary format: **JSON** (guaranteed).
Stretch goal: **Apache Arrow IPC** for columnar efficiency (batch of laws in one payload).

```json
{
  "items": [
    {
      "id": "uuid",
      "law_name": "UK_uksi_2024_702",
      "title_en": "The Glue Traps (Offences) ...",
      "drrp_type": "duty",
      "holder": "Ind: Applicant",
      "provision": "s.3",
      "regex_clause": "applicant for a glue trap licence... must",
      "confidence": 0.45,
      "scraped_at": "2026-02-20T14:30:00Z"
    }
  ]
}
```

The AI needs: law identity, which DRRP type, which provision, the current (incomplete) clause, and the regex confidence so it can prioritise. The AI resolves the full provision text from its own legislation corpus using `law_name` + `provision`.

### Result item — what we pull from the AI service

```json
{
  "results": [
    {
      "id": "uuid",
      "law_name": "UK_uksi_2024_702",
      "drrp_type": "duty",
      "provision": "s.3",
      "holder": "Ind: Applicant",
      "clause": "The applicant for a glue trap licence must satisfy the competency requirements set out in Schedule 1.",
      "confidence": 0.92
    }
  ]
}
```

AI returns its refined clause (→ `ai_clause`) and its own confidence. The original `clause` and `regex_clause_confidence` are preserved — both versions coexist on the entry.

### Arrow IPC (stretch)

For batch pulls, Arrow columnar format would give:
- Smaller payloads (columnar compression on repeated holder/article strings)
- Zero-copy reads on AI service side (Python/PyArrow native)
- Schema enforcement at the transport level

Schema (Arrow):
```
id: utf8, law_name: utf8, drrp_type: utf8, provision: utf8,
regex_clause: utf8, confidence: float64
```

Elixir options: `explorer` (Polars-backed DataFrames) or raw `adbc`/`arrow` NIF.

## Notes

- DRRP = Duties, Responsibilities, Rights, Powers
- Current pipeline: Regex Detection → V2 Capture Groups → ClauseRefiner → Dedup
- AI handles: ambiguous clauses, complex cross-references, missed modals
- AI service is local LAN only — no cloud dependency
- Pull model chosen for simplicity — AI service controls its own pace
- ~2,500 records already have DRRP data; AI refines clauses that are truncated/incomplete

## Phase 1 Implementation (be25674)

**Commit**: `be25674` — `feat: add GET /api/ai/drrp/clause/queue endpoint for AI service`

**Files created:**
- `backend/lib/sertantai_legal_web/plugs/ai_api_key_plug.ex` — `X-API-Key` header validation against `AI_SERVICE_API_KEY` env var
- `backend/lib/sertantai_legal_web/controllers/ai_drrp_controller.ex` — queue endpoint, raw SQL CTE + UNION ALL across 4 DRRP JSONB columns
- `backend/test/sertantai_legal_web/plugs/ai_api_key_plug_test.exs` — 4 tests
- `backend/test/sertantai_legal_web/controllers/ai_drrp_controller_test.exs` — 11 tests

**Files modified:**
- `backend/lib/sertantai_legal_web/router.ex` — `:api_ai` pipeline + `/api/ai/drrp/clause/queue` route
- `backend/.env.example` — `AI_SERVICE_API_KEY` section

**Key decisions:**
- Raw SQL (not Ash) — query unnests JSONB arrays from 4 columns into one row per entry, Ash doesn't model this
- API key auth (not JWT) — machine-to-machine LAN endpoint, JWT claims (org_id, role) don't apply
- NULL confidence = queued — all ~110K existing entries appear in queue until `regex_clause_confidence` is set
- No migration — `regex_clause_confidence` and `ai_clause` are JSONB keys added at write-back time

## Phase 1b Implementation (f052d31)

**Commit**: `f052d31` — `feat: add regex_clause_confidence scoring to DRRP pipeline`

**Files created:**
- `backend/lib/sertantai_legal/legal/taxa/regex_clause_confidence.ex` — scoring module, 4 signals weighted 0.0–0.85 (article bonus added downstream)
- `backend/test/sertantai_legal/legal/taxa/regex_clause_confidence_test.exs` — 9 tests

**Files modified:**
- `backend/lib/sertantai_legal/legal/taxa/duty_type_lib.ex` — both `run_role_regex` and `run_modal_windowed_search` now compute `regex_clause_confidence` on each entry
- `backend/lib/sertantai_legal/legal/taxa/taxa_formatter.ex` — `matches_to_jsonb/2` passes through `regex_clause_confidence` and adds +0.15 article context bonus (capped at 1.0)

**Confidence scoring signals (RegexClauseConfidence):**

| Signal | Weight | Description |
|--------|--------|-------------|
| V2 captured action | +0.25 | Regex capture group extracted an action verb |
| Clean ending | +0.25 | No trailing ellipsis or mid-word truncation |
| Adequate length | +0.20 | Clause ≥30 chars (meaningful content) |
| Strong modal | +0.15 | Contains `shall`, `must`, `may`, `entitled` |
| Article context | +0.15 | Added in TaxaFormatter when article is known |

**Score range:** 0.0 (nil/empty clause) to 1.0 (all signals present). Newly extracted entries get scored immediately; existing entries remain NULL until re-processed.

**Key decisions:**
- Score split across two modules — DutyTypeLib scores 0.0–0.85 (match-level signals), TaxaFormatter adds article bonus +0.15 (only known at formatting time)
- `ai_clause` not yet populated — that's Phase 2 (result puller writes it back)
- Existing DRRP entries in DB retain NULL confidence — queue endpoint treats NULL as "unscored = queued"
