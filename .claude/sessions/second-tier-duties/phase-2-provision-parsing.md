# Title: Phase 2 — Second-Tier Provision Parsing (JSP focus)

**Started**: 2026-07-15
**Parent**: second-tier-duties/meta.md
**Plan**: `.claude/plans/second-tier-duties.md` (Phase 2 section)

## Todo
- [x] Create `SecondarySourceProvision` Ash resource + migration
- [x] Add PDF extraction deps to mix.exs
- [x] Download JSP 375 Vol 1 Ch 8 PDF to data/secondary-sources/jsp/
- [x] Test extractous_ex — works, clean plain text 98K chars
- [x] Test pdf_elixide — works, word-level with font_size/bold/italic/font
- [x] Build hierarchy classifier (PdfParser module)
- [x] Section_id generator (TYPE_issuer_year_id:locator)
- [x] Mix task: `mix secondary.parse`
- [ ] **BLOCKED**: Parse JSP 375 validation — engine.ex compile error from other Claude's Baserow WIP
- [ ] QA tooling: `mix secondary.qa`

## Tuning pattern
Parse → persist → inspect in SQL → fix classifier → re-parse with `--clear`.
Same lifecycle as LAT parser. Section_ids are unstable until classifier stabilises
across 3-4 document types. Don't reference from source_links/control_mappings until then.

### Tune cycle 1: JSP 375 Ch 8 (32 pages)
- **Before**: 210 provisions (4 chapter, 61 heading, 123 paragraph, 20 section, 2 part)
- **Fixes**: multi-line heading merge, bold continuation detection, year fallback chain
- **After**: 186 provisions (3 chapter, 38 heading, 123 paragraph, 20 section, 2 part)
- 24 fewer provisions = cleaner hierarchy, no false headings

### Tune cycle 2: JSP 815 Element 3 (16 pages)
- Large non-bold fonts (36pt) now classified as chapter titles
- Duplicate section_ids deduped with -N suffix
- 71 provisions, no regression on JSP 375

### Tune cycle 3: JSP 418 Leaflet 5 (38 pages)
- No parser changes needed — passed first time
- 241 provisions. Parser stable across 3 MoD JSPs

### Pivot: profile-based parser (tune cycle 4)
- L8 ACoP uses 10pt body (not 12pt), "N text" numbering (not "N. text")
- Loosening regex to fit ACoPs broke JSP paragraph counts (123→144)
- **Decision**: stop tweaking one-size-fits-all rules. Refactor to named
  profiles dispatched via Elixir pattern matching.
- Profiles: `:mod_jsp` (12pt body, N. numbering) + `:hse_acop` (10pt body,
  N numbering, ACOP/Guidance/Regulation labels)
- Auto-detect profile from font analysis + publisher heuristics on first page
- Same pattern as LAT parser's jurisdiction dispatch (UK/AU/EU)

### Next documents to test
- [ ] L8 ACoP with :hse_acop profile
- [ ] HSG guidance (HSG65 — may need :hse_hsg profile or share :hse_acop)

## Notes
- Bumped ecto 3.14, explorer 0.12, ash 3.29 — unlocked extractous_ex + pdf_elixide
- rustler ~> 0.38 override needed (zenohex pins 0.37.x, all use precompiled)
- extractous_ex: Tika plain text, good fallback
- pdf_elixide: word-level with font metadata — primary strategy for hierarchy classification
- JSP 375 Ch 8 font pattern: 24pt bold=chapter, 14pt bold=section, 12pt bold=sub, 12pt=body
- Has structure tree (Tagged PDF) — future enhancement opportunity
- JSP-375 registered as secondary source (4f1f2e54...)
