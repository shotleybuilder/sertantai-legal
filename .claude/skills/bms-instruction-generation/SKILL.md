---
name: BMS Instruction Generation
description: Generate a populated Business Management System (BMS) Instruction document from Controls, Evidence Patterns, Artefact Templates, and secondary source provisions via Gemini. Covers the programmatic prompt builder, data requirements, and output evaluation.
---

# BMS Instruction Generation

## When to use

- Customer asks "can AI produce an Instruction for [topic]?"
- Generating a draft BMS Instruction for a specific law/regulation
- Testing instruction generation quality for a new domain

## Prerequisites

- **Controls** must exist for the target law in the `controls` table (non-predicate, with `control_type`, `nature`, `domain` populated)
- **Evidence Patterns** must exist (joined via `law_name + control_id`) with artefact templates
- **Secondary sources** should be parsed — at minimum the directly-linked sources via `source_links`
- `GEMINI_API_KEY` set in environment (`source ~/.bashrc`)

## The Script

```
backend/scripts/generate_instruction.py
```

### Usage

```bash
# Dry-run — inspect assembled prompt without calling Gemini:
/usr/bin/python3 backend/scripts/generate_instruction.py UK_uksi_1989_635 --dry-run

# Generate:
source ~/.bashrc
/usr/bin/python3 backend/scripts/generate_instruction.py UK_uksi_1989_635

# Custom output path:
/usr/bin/python3 backend/scripts/generate_instruction.py UK_uksi_1989_635 -o path/to/output.md

# Different model (e.g. Pro for higher quality):
/usr/bin/python3 backend/scripts/generate_instruction.py UK_uksi_1989_635 --model gemini-2.5-pro
```

Output defaults to `backend/data/instructions/{law_name}.md`.

## How It Works

### Data Assembly

The script queries PostgreSQL (port 5436) and assembles context from three sources:

1. **Controls + Evidence Patterns + Artefact Templates** — from `controls` / `evidence_patterns` / `artefact_templates` tables, joined on `(law_name, control_id)`
2. **Secondary source provisions** — discovered two ways:
   - **Directly linked**: `source_links` table → full document paragraphs
   - **Chapter-match**: sources with chapter headings matching the topic keyword → only matching chapter paragraphs
3. **Template**: `docs/qq/Blank Instruction Template.md` — the blank BMS Instruction structure

### Prompt Architecture

```
┌─────────────────────────────────────┐
│ SYSTEM INSTRUCTION                  │
│  - Role: senior H&S professional    │
│  - Law identity + year              │
│  - 10 rules for template population │
│  - The blank template (verbatim)    │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ USER PROMPT (cached)                │
│  - Controls block:                  │
│    - title, description, type,      │
│      nature, domain, frequency      │
│    - what_it_checks, honest_limit,  │
│      load_bearing_judgement          │
│    - Evidence pattern: VoI, method, │
│      interval, drift_conditions,    │
│      discriminating_question        │
│    - Artefacts: type, class, source,│
│      likelihood_ratio, what_it_proves│
│  - Secondary sources block:         │
│    - Grouped by source_id           │
│    - Paragraph text with headings   │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ GENERATION CALL (against cache)     │
│  "Generate the complete BMS         │
│   Instruction now."                 │
└─────────────────────────────────────┘
```

Uses Gemini context caching (30 min TTL) so you can iterate on the generation call without re-uploading ~47k tokens of context.

### Template Section → Data Source Mapping

| Template Section | Data Source |
|---|---|
| What is covered | Control predicate description + secondary source intro |
| Definitions table | Terms from secondary source provisions + control fields |
| Who is Responsible | Control `domain` (People/Physical/Organisational) → role assignments |
| Arrangements (PDCA) | Controls + `recommended_frequency` + `recommended_method` + secondary source practical detail |
| Records table | All artefact templates with `source`, `recommended_frequency` |
| Appendix A (Competence) | Artefacts of type Training Record / Certificate |
| Appendix B (Compliance Checklist) | Artefacts with `what_it_proves` as suggested evidence |

## Checking Data Readiness for a New Law

Before running the script on a new law, verify data exists:

```sql
-- Controls exist?
SELECT count(*) FROM controls
WHERE law_name = 'UK_uksi_YYYY_NNN' AND is_predicate = false;

-- Evidence patterns + artefacts exist?
SELECT c.title, count(at.id) as artefacts
FROM controls c
LEFT JOIN evidence_patterns ep ON ep.law_name = c.law_name AND ep.control_id = c.control_id
LEFT JOIN artefact_templates at ON at.evidence_pattern_id = ep.id
WHERE c.law_name = 'UK_uksi_YYYY_NNN' AND c.is_predicate = false
GROUP BY c.id;

-- Secondary sources available?
SELECT ss.source_id, ss.title, count(p.id) as provisions
FROM source_links sl
JOIN secondary_sources ss ON ss.id = sl.secondary_source_id
LEFT JOIN secondary_source_provisions p ON p.secondary_source_id = ss.id
  AND p.section_type = 'paragraph'
WHERE sl.law_name = 'UK_uksi_YYYY_NNN'
GROUP BY ss.source_id, ss.title;
```

If controls exist but no evidence patterns, the output will still work but Appendices A and B will be thin.
If no secondary sources are linked, the Arrangements section loses practical detail (inspection intervals, voltage thresholds, etc.).

## Model Selection

| Model | Cost | Quality | When to use |
|---|---|---|---|
| `gemini-2.5-flash` (default) | Low | Good — grounded, all sections populated | First draft, iteration, testing |
| `gemini-2.5-pro` | Higher | Better reasoning on ambiguous mappings | Final version for customer delivery |

Current settings: temperature 0.3, thinking budget 8192, max output 32768 tokens.

## Known Limitations (v0.1)

These are documented improvement opportunities, not blockers:

1. **No customer personalisation** — output is generic (no company name, sector, site types). Feed a customer profile to personalise.
2. **Noisy secondary sources** — chapter-match discovery can pull sector-irrelevant content (warehousing paragraphs in an office instruction). Filter by customer sector.
3. **No LAT provisions in context** — actual regulation text not fed in, only control descriptions. Adding linked LAT provisions would improve grounding.
4. **Appendix B doesn't weight evidence** — `likelihood_ratio` and `artefact_class` (Activity vs Outcome) could distinguish documentary checks from discriminating observations.
5. **Template placeholders leak** — company names in the blank template (e.g. "QinetiQ") can appear in output. Sanitise template or instruct model to replace.
6. **No generation metadata** — output has no frontmatter recording date, model, law_name, sources used.

## Reference

- **Script**: `backend/scripts/generate_instruction.py`
- **Template**: `docs/qq/Blank Instruction Template.md`
- **Output dir**: `backend/data/instructions/`
- **First successful run**: 2026-07-16, EWR 1989, Gemini 2.5 Flash, 249 lines / 4,304 words
- **Session**: `.claude/sessions/2026-07-16-ai-instruction-generation.md`
