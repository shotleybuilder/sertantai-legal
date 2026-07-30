---
session: Customer Onboarding — Baserow LAT Re-sync + Enhesa QA Report
status: closed
opened: 2026-06-03
closed: 2026-06-03
---
# Title: Customer Onboarding — Baserow LAT Re-sync + Enhesa QA Report

**Started**: 2026-06-03 17:00

## Todo
- [x] Simplify LAT queue page — selection-based Parse replaces Reparse View
- [x] Parse 68 domestic L3 yes-laws via new queue — 20,960 LAT rows, 19,236 enriched
- [ ] Rethink LAT schema for Baserow — customer needs duties, not a copy of the law
- [ ] Filter LAT sync using taxa enrichment (only provisions with DRRP content)
- [ ] Update Baserow LAT field specs with taxa/fitness columns
- [ ] Re-sync LRT + LAT to Baserow
- [ ] Enhesa data quality report — law by law, enrichment coverage, applicability sense-check

## LAT Queue Page Refactor

The current Reparse View button infers sessions from grid filters — fragile, causes
"Column not found" errors when filter state drifts. Replace with selection-based approach.

**Remove:**
- Reparse View button + dialog (filter-based session creation)
- Per-row LRT/LAT inline parse buttons (superseded by session workflow)
- Parse Family button (replaced by: filter to family → select all → create session)

**Keep:**
- Session picker dropdown (scrape sessions + L3 applicability)
- Grid with filters, sorting, grouping, saved views
- Stats bar (view total, missing LAT, stale LAT)

**Add:**
- Row selection checkboxes (select/deselect individual laws)
- Select All / Deselect All buttons
- "Create Parse Session from Selection" button → takes selected law names → creates session → navigates to session page

**UX flow:**
1. Select L3 Applicable from dropdown → see 204 laws
2. Filter (e.g. exclude EU, exclude revoked, show only missing LAT)
3. Select All (or pick specific laws)
4. Click "Create Parse Session" → session created from selection → navigate

This matches how /admin/lat/sessions already works — just adds the selection
step to the queue page instead of inferring from filters.

## Notes
- Current LAT sync: 623 rows (section+article for OH&S), no taxa columns
- New enrichment: 672 provisions enriched, 235 with DRRP types
- Customer perspective: "what are my duties?" not "show me the full law text"
- Filter idea: only sync provisions where drrp_types contains Duty or Responsibility
- Baserow free tier: 5K row limit, currently 729 rows (106 LRT + 623 LAT)
- 27 domestic Making yes-laws still need LAT parsing
- Factories Act (revoked) in Enhesa yes-set is an error

**Ended**: 2026-06-04 01:00
**Commits**: `a52eb26`, `1cd377a`, `40843ef`, `052a241`, `a07223e`, `ab3060d`, `b99624b`, `e3d4bdf`
- Parse QA PASS: 0 sort_key dupes, 0 NULL types, 92% taxa enriched, 3,330 with DRRP
- Issues raised: #91 (cascade delete), #92 (page state persistence), #93 (annotation reparse), #94 (section_id mismatch)
