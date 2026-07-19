---
session: Phase 2 — Second-Tier Provision Parsing
project: sertantai-legal
status: closed
opened: 2026-07-15
closed: 2026-07-15
outcome: success
commits: [422d45c, f46063d, 0002f05]

summary: >
  Built profile-based PDF parser for secondary source provisions. Tested on 5
  documents across 2 publishers (3 MoD JSPs, 1 HSE ACoP, 1 HSE guidance).
  887 provisions persisted. Parser auto-detects publisher profile via font
  analysis and pattern matching.

decisions:
  - what: Profile-based parser dispatch via Elixir pattern matching
    why: One-size-fits-all rules broke across publishers — loosening ACoP regex broke JSP paragraph counts
    result: :mod_jsp and :hse_acop profiles isolated, zero cross-contamination
  - what: pdf_elixide over ex_pdfium for PDF extraction
    why: ex_pdfium rustler ~> 0.38 conflicts with zenohex; pdf_elixide uses rustler_precompiled
    result: Word-level extraction with font_size, bold, italic, bounding boxes
  - what: Bumped ecto 3.14 + explorer 0.12 + ash 3.29 to unblock PDF deps
    why: explorer 0.12 moved to rustler ~> 0.38 + decimal ~> 3.0, ecto 3.14 moved to decimal ~> 3.0
    result: Full dep chain resolved, extractous_ex + pdf_elixide both available

metrics:
  provisions_total: 887
  documents_parsed: { JSP-375: 186, JSP-815: 71, JSP-418: 241, L8: 168, HSG65: 221 }
  profiles: { mod_jsp: 3, hse_acop: 2 }
  tune_cycles: 6
  dep_upgrades: { ecto: "3.13→3.14", explorer: "0.11→0.12", ash: "3.23→3.29", decimal: "2.4→3.1" }

lessons:
  - title: Rustler version pinning is the Elixir NIF ecosystem's worst pain point
    detail: "zenohex pins rustler 0.37.1 (exact), explorer 0.11 pins ~> 0.36, explorer 0.12 needs ~> 0.38. All use precompiled NIFs so rustler is never actually compiled. Fixed with {:rustler, \"~> 0.38\", optional: true, override: true}."
    tag: infrastructure
  - title: Profile-based parser dispatch is the right pattern for multi-publisher PDF parsing
    detail: "First attempt used adaptive thresholds (body size × multiplier). Worked for one publisher but cross-publisher tuning was impossible — fixing ACoP numbering regex broke JSP counts. Pattern matching on {profile_name, line, fonts} isolates each publisher completely."
    tag: tooling
  - title: HSE guidance (HSG series) is prose, not numbered provisions
    detail: "L8 ACoP has numbered paragraphs (99 captured). HSG65 is flowing prose with bullet points — 0 paragraphs captured. Structural skeleton (headings, sections) is correct. Prose body capture needs a dedicated :hse_guidance profile."
    tag: data
  - title: pdf_elixide Word struct uses bbox not rect, bold? not bold, font not font_name
    detail: "The field names in PdfElixide.Document.Word don't match the research notes. Always check the actual struct definition in deps/pdf_elixide/lib/pdf_elixide/document/word.ex."
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/legal/secondary_source/pdf_parser.ex
  - backend/lib/sertantai_legal/legal/secondary_source/parser_profile.ex
  - backend/lib/sertantai_legal/legal/secondary_source_provision.ex
  - backend/lib/mix/tasks/secondary.parse.ex
  - .claude/skills/secondary-source-parsing/SKILL.md

depends_on:
  - second-tier-duties/phase-1-data-model.md

enables:
  - Phase 3 enrichment (fractalaw taxa classification of secondary provisions)
  - Phase 4 sync (SecondaryProvisionsTemplate for Baserow)
  - :hse_guidance profile for prose body text capture
  - mix secondary.qa tooling
---

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
- [x] Parse JSP 375 validation — resolved after Baserow WIP landed
- [ ] QA tooling: `mix secondary.qa` (deferred)

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

### Tune cycle 5: L8 ACoP (28 pages)
- Profile auto-detected as :hse_acop (10pt body)
- 168 provisions (99 paragraphs, 56 headings, 12 sections, 1 chapter)
- ACoP "N Text" numbering (no dot) handled by acop_numbered?/1

### Tune cycle 6: HSG65 guidance (62 pages)
- Profile auto-detected as :hse_acop (10pt body, same publisher)
- 221 provisions but **0 paragraphs** — prose guidance, no numbered paragraphs
- Structural skeleton captured (196 headings, 18 chapters, 3 sections, 4 parts)
- **Known gap**: prose body text not captured as provisions. Needs future
  :hse_guidance profile that treats unnumbered body blocks as paragraph provisions.
- Bullet points at 8pt ("■ items") classified as minor_text, lost

## Notes
- Bumped ecto 3.14, explorer 0.12, ash 3.29 — unlocked extractous_ex + pdf_elixide
- rustler ~> 0.38 override needed (zenohex pins 0.37.x, all use precompiled)
- extractous_ex: Tika plain text, good fallback
- pdf_elixide: word-level with font metadata — primary strategy for hierarchy classification
- JSP 375 Ch 8 font pattern: 24pt bold=chapter, 14pt bold=section, 12pt bold=sub, 12pt=body
- Has structure tree (Tagged PDF) — future enhancement opportunity
- JSP-375 registered as secondary source (4f1f2e54...)
