# Issue #79: Enacted By tab QA — continuation

**Started**: 2026-05-04
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/79
**Prior session**: 2026-04-25-issue-79.md

## Context
Continuing #79 focused on the Enacted By tab of /admin/graph.
linked_* columns removed in #82 — law_edges now reads source columns (168,616 edges, +45,921).
Tab has 5 QA filter buttons, si_code_families derived table, enacted-by-qa skill ready.

## Todo

### Enacted By tab improvements
- [ ] Run enacted-by-qa skill against outlier population to validate parser accuracy
- [ ] Use findings to improve enacted_by.ex pattern matching
- [ ] Reverse-fill: infer missing SI codes from family (1,239 laws, mostly pre-2000)

## Notes
- 10,357 enacted_by edges (up from 8,441 after linked_* removal)
- 570 parents with enacted_families, 768 with enacted_si_codes
- SI mismatch currently 0 (mapping reflects data — will surface after corrections)
- Outlier <5%: ~952, SI enacts SI: ~351, No enacted fams: ~411
