# Title: Phase 2b — HSG Profile Fix + JSP Corpus Parsing

**Started**: 2026-07-16
**Parent**: second-tier-duties/meta.md
**Plan**: `.claude/plans/second-tier-duties.md`

## Todo
- [x] Build :hse_guidance profile for prose body text (HSG65 had 0 paragraphs)
- [x] Re-parse HSG65 with new profile — 0→191 paragraphs, 412 provisions total
- [x] Identify all relevant JSPs from gov.uk collections
- [x] Parser regression tests — 23 unit + 3 integration, 0 failures
- [ ] Download and parse JSP corpus:
  - [x] JSP 816 (Defence Environmental Mgmt System) — 13 PDFs, 1,221 provisions
  - [x] JSP 375 remaining chapters — 29 PDFs, 2,280 provisions total (30 chapters)
  - [x] JSP 376 (Defence Acquisition Safety Policy) — 1 PDF, 367 provisions
  - [x] JSP 815 remaining elements — 17 PDFs, 1,011 provisions total (12 elements + 5 annexes)
  - [x] JSP 418 remaining leaflets — 9 PDFs, 857 provisions total (Part 1 + 8 leaflets)
  - [x] JSP 392 (Radiation Protection) — 40 PDFs, 2,263 provisions
  - [x] JSP 520 (Ordnance, Munitions & Explosives) — 15 PDFs, 1,420 provisions (volumes withdrawn)
  - [ ] JSP 319 (Storage & Handling of Gases) — PARKED: ODT-only, no PDF published
  - [x] JSP 425 (Radiation Detection Equipment Testing) — 1 PDF, 85 provisions
  - [x] JSP 975 (MoD Lifting Policy) — 2 PDFs, 1,490 provisions
  - [x] JSP 403 (Defence Ranges Safety) — 33 PDFs, 1,588 provisions (QQ operates ranges)
- [x] Register all parsed JSPs as secondary sources with law links

## Notes
- HSG65 issue: prose without numbered paragraphs, body text dropped → fixed with :hse_guidance profile
- :hse_guidance uses :prose_body role + auto-incrementing counter per section
- JSP 317 (Fuels) URL returns 404 — may be restricted
- JSP 816 mirrors JSP 815 structure (12 elements) — should work with :mod_jsp profile
- JSPs tested so far: JSP-375 Ch8, JSP-815 El3, JSP-418 Lf5
- Using /secondary-source-parsing skill workflow
