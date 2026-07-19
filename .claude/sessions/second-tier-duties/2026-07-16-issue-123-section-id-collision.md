---
session: "Issue #123: Multi-PDF section_id collision fix"
project: sertantai-legal
status: closed
opened: 2026-07-16
closed: 2026-07-16
outcome: success
commits: [beebe4a]

summary: >
  Fixed section_id collision where multi-PDF JSPs silently overwrote chapters'
  provisions on upsert. Implemented per-chapter source registration (Option A)
  with parent_source_id grouping. Re-parsed 158 PDFs, recovering ~700 hidden
  paragraphs. Added --tree view to mix secondary.list.

decisions:
  - what: Option A — per-chapter SecondarySource registration
    why: Gemini review agreed. Chapters are independently versioned documents with their own law links. Other options (filename prefix, document-derived prefix) kept one-source-per-JSP but couldn't guarantee namespace stability across editions.
    result: 10 parent + 158 chapter records. JSP-375-CH08 restored from 0 to 123 paragraphs.
  - what: parent_source_id aggregation model (bottom-up), not cascade (top-down)
    why: Chapters own the law links (CH10 → Manual Handling Regs). The parent JSP inherits as union of chapters' links. User correction — cascade was backwards.
    result: Applicability can be at JSP or chapter level. Parent is grouping only.

metrics:
  provisions_restored: 700
  provisions_total: 13854
  source_records: { parents: 10, chapters: 158, standalone: 33, total: 201 }
  corrupted_rows_deleted: 10640
  pdfs_reparsed: 158

lessons:
  - title: Upsert on slugified headings is silently destructive across multi-PDF sources
    detail: "Generic headings ('Part 2: Guidance', 'Introduction') produce identical section_id slugs. The upsert identity means the last PDF parsed wins — no error, no warning. 10 JSP-375 chapters lost all paragraphs. The fix is namespace isolation via source_id, not trying to make slugs unique."
    tag: schema
  - title: The integration tests didn't catch the collision because they test one PDF at a time
    detail: "The regression tests validated each profile's classification correctly but never tested two PDFs writing to the same source_id. The collision is a system-level bug, not a parser bug. Added a dedicated collision test."
    tag: tooling
  - title: Elixir if/else doesn't short-circuit — return_ok() in an if block doesn't stop execution
    detail: "The dry-run guard used `if dry_run? do ... return_ok() end` but Elixir doesn't have early returns. The function continued past the if block and created records. Fix: use if/else to wrap the entire remaining logic."
    tag: tooling
  - title: Gemini truncates at MAX_TOKENS silently — always include word limits in prompts
    detail: "First Gemini review was truncated mid-sentence. Retrying with higher maxOutputTokens burns credits. Better: tell Gemini 'under 1200 words' in the prompt. Updated the gemini-review skill with this pattern."
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/legal/secondary_source.ex
  - backend/lib/mix/tasks/secondary.register_chapters.ex
  - backend/lib/mix/tasks/secondary.list.ex
  - backend/lib/sertantai_legal/sync/org_secondary_applicability.ex
  - backend/test/sertantai_legal/legal/secondary_source/pdf_parser_test.exs
  - .claude/plans/issue-123-namespace-options.md
  - .claude/skills/gemini-review/SKILL.md

depends_on:
  - second-tier-duties/phase-2b-hsg-and-jsp-corpus.md

enables:
  - Per-chapter law linking (JSP-375-CH23 → Electricity at Work Regs)
  - Chapter-level Baserow sync
  - Fractalaw enrichment of chapter provisions
---

# Issue #123: Multi-PDF sources collide on section_id upsert

**Started**: 2026-07-16
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/123
**Parent**: second-tier-duties/meta.md

## Todo

### Schema
- [x] Decide fix approach — **Option A: per-chapter source registration**
- [x] Add `parent_source_id` (FK → secondary_sources) to SecondarySource + migration
- [x] Add `has_many :chapters` / `belongs_to :parent` relationships (self-referential)
- [x] Add `by_parent` / `top_level` read actions

### Data cleanup
- [x] Delete corrupted secondary_source_provisions (10,640 rows)
- [x] Delete multi-PDF secondary_sources (7 records)
- [x] Kept single-PDF sources (JSP-376/425/975, L8, HSG65, 29 ACoPs)

### Registration tooling
- [x] Build `mix secondary.register_chapters` — derives chapter IDs from filenames
- [x] Register all multi-PDF JSPs: 10 parents + 158 chapters

### Parser update
- [x] Confirmed: no parser changes needed — source_id drives section_id prefix

### Re-parse
- [x] Re-parsed 158 PDFs with per-chapter source_ids — 13,854 provisions
- [x] Verified: JSP-375-CH08 = 123 paragraphs, JSP-375-CH23 = 117 paragraphs

### Tests
- [x] Added collision prevention test (issue #123)
- [x] Updated integration test source_id to JSP-375-CH08

### Applicability
- [x] Update `OrgSecondaryApplicability` docs — parent/chapter granularity
- [x] `mix secondary.list --tree` flag — parent/child grouping with provision counts

## Decision: Option A (per-chapter registration)
- Gemini review agreed — picked A over D (document-derived prefix)
- Each chapter/element/leaflet gets its own SecondarySource record
- source_id format: `JSP-375-CH23`, `JSP-815-EL4`, `JSP-418-LF6`
- section_id prefix: `JSP_mod_2026_JSP375CH23:para.1`
- Chapter discriminator goes BEFORE the colon (part of identity, not path)
- Annexes same treatment: `JSP-815-ANNEXA`
- Chapter renumbering: use `supersedes_id` — old source marked superseded
- ~170 source records instead of ~12 — acceptable, Baserow is the tooling
- `parent_source_id` groups chapters under their JSP (aggregation, not cascade)
- Chapters own the law links (CH10 → Manual Handling Regs, CH23 → Electricity at Work)
- Parent JSP inherits law links as union of its chapters' links + its own overarching links
- Customer applicability: marking JSP-375 = all chapters are candidates, but customer
  may only need specific chapters (their relevant topics)

## Notes
- 10 JSP-375 chapters have 0 paragraphs due to upsert collision
- 7 multi-PDF sources affected (JSP-375/392/403/815/816/418/520)
- Single-PDF sources (JSP-376/425/975, L8, HSG65) are fine
- Gemini review: `.claude/plans/issue-123-namespace-options.md`
- Gemini skill updated to avoid truncation (word limits in prompts)
