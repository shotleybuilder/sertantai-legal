# Issue #123: Multi-PDF sources collide on section_id upsert

**Started**: 2026-07-16
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/123
**Parent**: second-tier-duties/meta.md

## Todo

### Schema
- [x] Decide fix approach — **Option A: per-chapter source registration**
- [ ] Add `parent_source_id` (FK → secondary_sources) to SecondarySource + migration
- [ ] Add `has_many :chapters` relationship on SecondarySource (self-referential)

### Data cleanup
- [ ] Delete all existing secondary_source_provisions (corrupted by collision)
- [ ] Delete existing multi-PDF secondary_sources (JSP-375/392/403/815/816/418/520)
- [ ] Keep single-PDF sources (JSP-376/425/975, L8, HSG65) — they're correct

### Registration tooling
- [ ] Build `mix secondary.register_chapters` — scan a JSP directory, derive chapter
      identifiers from filenames, register parent + chapter SecondarySource records
      with source_ids like JSP-375-CH23, copy law links from parent to chapters
- [ ] Register all multi-PDF JSPs: JSP-375 (30), JSP-392 (40), JSP-403 (33),
      JSP-815 (18), JSP-816 (13), JSP-418 (9), JSP-520 (15)

### Parser update
- [ ] Update PdfParser section_id prefix to use per-chapter source_id
      (already correct if source.source_id = "JSP-375-CH23")
- [ ] No parser logic changes needed — the fix is in the registration, not the parser

### Re-parse
- [ ] Re-parse all multi-PDF sources with per-chapter source_ids
- [ ] Verify: JSP-375 ch08 = ~123 paragraphs, ch23 = ~117 paragraphs

### Tests
- [ ] Add test: two chapters with same headings produce different section_ids
- [ ] Update integration test paths/source_ids if needed

### Applicability
- [ ] Update `OrgSecondaryApplicability` docs — applicability can be at JSP or chapter level
- [ ] `mix secondary.list` — show parent/child grouping with `--tree` flag

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
