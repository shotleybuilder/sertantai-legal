---
session: AI-Generated BMS Instruction — Experimental
project: sertantai-legal
status: closed
opened: 2026-07-16
closed: 2026-07-16
outcome: success
commits: []

summary: >
  Proved that AI can produce a populated BMS Instruction document from programmatically assembled legal context.
  Built generate_instruction.py which queries Controls, Evidence Patterns, Artefact Templates, and secondary source
  provisions from Postgres, assembles a ~47k token prompt, and dispatches to Gemini Flash. First output (EWR 1989)
  produced a 249-line, 4,304-word instruction with all template sections populated and specific secondary source citations.

decisions:
  - what: Single Python script in backend/scripts/ rather than subdirectory
    why: Matches existing gemini_sync_review.py pattern; avoid premature structure for experimental work
    result: generate_instruction.py — 280 lines, fully self-contained
  - what: Two-tier secondary source discovery (source_links + chapter heading match)
    why: source_links only catches directly linked sources (e.g. HSG85→EWR); chapter heading match catches sources with relevant chapters (e.g. HSG76 warehousing has an electrical chapter)
    result: 9 sources, 683 paragraphs discovered vs 2 sources from source_links alone
  - what: Gemini context caching for iterative generation
    why: 47k tokens of context is expensive to re-upload; cache (30 min TTL) lets you iterate on the generation prompt cheaply
    result: Single cache creation, reusable for multiple generation calls
  - what: v0.1 good enough — defer improvements
    why: Experimental proof achieved; improvements (customer context, sector filtering, LAT provisions) are nice-to-haves for when a second topic is requested
    result: 6 improvement items captured in session doc and skill for future reference

metrics:
  prompt_tokens: { context: 38404, total_chars: 186965 }
  output: { lines: 249, words: 4304 }
  controls: { count: 3, artefacts: 13 }
  secondary_sources: { sources: 9, paragraphs: 683 }
  template_sections_populated: { definitions: 14, roles: 8, checklist_items: 19, competence_roles: 5, records: 13 }

lessons:
  - title: Chapter heading search dramatically expands secondary source discovery
    detail: >
      Searching only by source title found 2 electrical sources. Adding chapter heading LIKE '%electri%'
      found 9 — including HSR25 (747 provisions of reg-by-reg EWR guidance) which was the single most
      valuable source. source_links alone is insufficient for topic-based discovery.
    tag: data
  - title: source_links FK is secondary_source_id (UUID) not source_id (text slug)
    detail: >
      The source_links table references secondary_sources.id (UUID PK), not source_id (text slug like "HSG85").
      secondary_source_provisions also uses secondary_source_id (UUID FK). All joins must go through the UUID,
      not the human-readable slug. First query attempt failed on this.
    tag: schema
  - title: Template placeholder text leaks into generated output
    detail: >
      The blank template contained "QinetiQ" as placeholder company name. Gemini preserved it in the output
      (Appendix A competence matrix). Either sanitise the template before feeding it, or add an explicit
      instruction to replace company placeholders.
    tag: tooling
  - title: Gemini Flash handles ~47k context + structured generation well at temp 0.3
    detail: >
      With 8k thinking budget, Flash produced a well-structured 4k-word document that correctly cross-referenced
      HSR25 paragraph numbers, HSG76 Table 6 intervals, and mapped all 13 artefacts to records/checklist tables.
      No truncation at 32k max output. Good cost/quality tradeoff for first drafts.
    tag: tooling

artifacts:
  - backend/scripts/generate_instruction.py
  - backend/data/instructions/UK_uksi_1989_635.md
  - .claude/skills/bms-instruction-generation/SKILL.md

depends_on: []

enables:
  - AI-generated instructions for other laws/topics (reuse script with different law_name)
  - Customer-facing BMS document generation feature (add customer profile input)
---

# AI-Generated BMS Instruction — Experimental

**Started**: 2026-07-16
**Scope**: Can AI produce a populated BMS Instruction document from legal context?

## Test Case
- **Topic**: Electrical Safety
- **Template**: `docs/qq/Blank Instruction Template.md`
- **Context inputs**: Controls (Electricity at Work Regs), Evidence Patterns, secondary sources (electrical safety JSP, ACoP)

## Todo
- [x] Audit available data: Controls, Evidence, secondary sources for electrical safety
- [x] Design prompt structure (template + context assembly)
- [x] Build programmatic prompt builder — `backend/scripts/generate_instruction.py`
- [x] Test dispatch to Gemini Flash — v0.1 output at `backend/data/instructions/UK_uksi_1989_635.md`
- [x] Evaluate v0.1 output quality, identify v2 improvements
- [~] v2 improvements deferred — v0.1 good enough for experimental proof

## v0.1 Result — 2026-07-16

- **Output**: `backend/data/instructions/UK_uksi_1989_635.md` (249 lines, 4,304 words)
- **Model**: Gemini 2.5 Flash, 8k thinking, 32k output, temp 0.3
- **Context**: ~47k tokens (3 controls, 13 artefacts, 683 secondary source paragraphs from 9 sources)
- **Cost**: cached context (38k tokens), single generation call
- **Verdict**: All template sections populated. Good secondary source cross-referencing (HSR25 para refs, HSG76 Table 6 intervals, HSG150 voltage thresholds). Definitions, competence matrix, compliance checklist all derived from data.

## Secondary Sources — Electrical Safety

Query: title LIKE `%electri%` OR chapter heading LIKE `%electri%`

| Source | Type | Paragraphs | Role in prompt |
|---|---|---|---|
| **HSR25** | Guidance | 549 | Reg-by-reg EWR guidance — primary reference |
| **HSG85** | Guidance | 246 | Safe working practices — primary reference |
| **HSG141** | Guidance | 157 | Construction electrical — include if site-relevant |
| **JSP-375-CH23** | JSP | 117 | MOD electrical safety — include if MOD customer |
| HSG150 | Guidance | 1,469 | Construction general (electrical chapter only) |
| HSG76 | Guidance | 1,629 | Warehousing (electrical chapter only) |
| HSG270 | Guidance | 215 | Farmwise (electrical chapter only) |
| L44 | ACoP | 0 | Unparsed — gap |

**Core set**: HSR25 + HSG85 = ~795 paragraphs of directly relevant content.
**Chapter-only sources** (HSG150/76/270): extract electrical chapter provisions only, not full doc.

## Controls + Evidence — EWR 1989 (`UK_uksi_1989_635`)

3 non-predicate controls, all Manual / Judgement / needs_judgement=true.

| Control | VoI | Evidence Std | Method | Artefacts |
|---|---|---|---|---|
| Competent persons (reg.16) | Judgement | Comprehensive | Observation | 5 (3A, 2O) |
| Protective equipment (reg.4(4)) | Judgement | Focused | Visual Inspection | 4 (2A, 2O) |
| Live working avoidance (reg.14) | Judgement | Comprehensive | Observation | 4 (2A, 2O) |

### Artefact Detail (13 total)

**Competent persons** — 5 artefacts:
- Activity: Competence Assessment Record, Training Certs/Quals, Work Allocation Record
- Outcome: Observation Report (competence & supervision) [High LR], Supervisor Log [Medium LR]

**Protective equipment** — 4 artefacts:
- Activity: Equipment Inspection/Test Log, Worker Training Record (PPE use)
- Outcome: Observation Report (PPE use) [High LR], Pre-use Check Record [Medium LR]

**Live working** — 4 artefacts:
- Activity: Justification for Live Working, Live Work Permit + Risk Assessment
- Outcome: Incident/Near Miss Report [Medium LR], Site Observation Report [High LR]

### Key patterns for prompt design
- Every control has Activity (Type-A, low LR) + Outcome (Type-B, medium/high LR) artefacts
- `what_it_proves` text explains discriminating power — useful for Appendix B checklist generation
- `recommended_frequency` maps to Arrangements section (lifecycle/PDCA)
- All evidence_by_design = false — none are natural by-products, all require deliberate collection

## Future Improvements (if asked for another topic)

1. **Customer context input** — take company name, sector, site types, workforce size to personalise the output (v0.1 reads generic)
2. **Sector-filtered secondary sources** — v0.1 pulls all electrical chapter matches including warehousing/farming; filter to source_links-linked + customer-sector sources only
3. **Include LAT provisions** — feed actual regulation text for linked provisions (reg.16, reg.4(4), reg.14) not just control descriptions
4. **Richer Appendix B** — use `likelihood_ratio` and `artefact_class` to distinguish documentary checks from discriminating observations
5. **Strip template placeholders** — "QinetiQ" leaked from template into output; sanitise template or instruct model to replace
6. **Generation metadata header** — add frontmatter with date, model, law_name, sources used for traceability

## Notes
- Challenge is *programmatic* prompt construction, not hand-crafting
- Need to map template sections to data sources (who → duty holders, arrangements → controls, appendix B → evidence)
- `source_links` table ties HSG85 → `UK_uksi_1989_635` (EWR 1989) — use this to auto-discover relevant sources per law
