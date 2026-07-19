---
session: Phase 2b — HSG Profile Fix + JSP Corpus Parsing
project: sertantai-legal
status: closed
opened: 2026-07-16
closed: 2026-07-16
outcome: success
commits: [96237c0, 6b9fe83]

summary: >
  Built :hse_guidance profile for prose body text. Parsed full JSP corpus
  (10 JSPs, 167 PDFs, 13,143 provisions). Added parser regression tests
  (23 unit + 3 integration). Renamed NAS backup script to include project
  data sync. Analysed JSP actor vocabulary — DRRP doesn't fit, needs
  fractalaw SLM for responsibility assignment classification.

decisions:
  - what: Profile-based dispatch instead of one-size-fits-all regex tuning
    why: Loosening ACoP numbered paragraph regex broke JSP counts — profiles isolate publisher patterns
    result: 3 profiles stable across 12 sources, zero cross-contamination
  - what: JSP actor model is responsibility assignment, not Hohfeldian DRRP
    why: JSPs assign organisational roles (SRO/User/Contractor/AP) within existing legal framework, not legal rights and duties
    result: Fractalaw SLM needed for reliable classification — regex is coarse filter only. Phase 3 territory.
  - what: Renamed export-snapshot.sh → nas-backup.sh with full data/ sync
    why: PDF corpus (97MB, 167 files) is gitignored and was not backed up anywhere
    result: Single backup command covers both DB snapshots and project data

metrics:
  provisions_total: 13143
  sources: 12
  pdfs_parsed: 167
  profiles: { mod_jsp: 10, hse_acop: 1, hse_guidance: 1 }
  unit_tests: 23
  integration_tests: 3
  parse_errors: 0
  test_failures: 0
  nas_backup_size: "97MB (data) + DB snapshots"

lessons:
  - title: JSPs use responsibility assignment model, not Hohfeldian duty/right
    detail: "Top actors: SRO (142), User (57), Defence organisation (50), Accountable person (19), Contractor (15). These are organisational roles, not legal positions. DRRP extraction needs a different approach — fractalaw SLM, not regex."
    tag: data
  - title: Regression tests before corpus expansion prevents silent breakage
    detail: "Building 23 unit tests before parsing 167 PDFs meant every new JSP was validated by mix test. No manual grep needed. Test per profile pattern = isolated verification."
    tag: tooling
  - title: JSP 319 is ODT-only — no PDF published
    detail: "extractous_ex (Tika) extracts ODT text fine but pdf_elixide can't process it. Need either LibreOffice for ODT→PDF conversion or a text-based classifier. Parked."
    tag: data
  - title: Backup gitignored project data alongside DB snapshots
    detail: "167 PDFs (97MB) accumulated in data/secondary-sources/ with no backup. Combined NAS backup script prevents data loss without polluting git."
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_legal/legal/secondary_source/pdf_parser.ex
  - backend/lib/sertantai_legal/legal/secondary_source/parser_profile.ex
  - backend/test/sertantai_legal/legal/secondary_source/pdf_parser_test.exs
  - scripts/nas/nas-backup.sh

depends_on:
  - second-tier-duties/phase-2-provision-parsing.md

enables:
  - Phase 3 fractalaw integration (responsibility assignment classification for JSPs)
  - Baserow sync of secondary source provisions
  - Contractor-applicable provision filtering for QQ
---

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

## JSP Actor Model Analysis

JSP provisions use a **responsibility assignment model**, not Hohfeldian duty/right.
DRRP doesn't fit — JSPs don't create legal obligations, they assign organisational
responsibilities within an existing legal framework.

### Actor vocabulary (from 'must/should/is responsible' extraction)

| Actor | Freq | Role |
|-------|------|------|
| SRO (Senior Responsible Owner) | 142 | Project/programme accountability |
| User | 57 | Military user/operator of equipment |
| Defence organisation | 50 | Any MoD unit/command |
| Accountable person | 19 | H&S accountability role |
| Commander, manager | 17 | Line management chain |
| Contractor | 15 | External supply chain |
| Project Technical Authority | 7 | Technical assurance role |
| Operator | 6 | Equipment operator |
| Infrastructure provider | 5 | Estate management |
| Prime contractor | 4 | Main contract holder |

### Contractor applicability across JSPs

| JSP | Paragraphs | 'contractor' | 'supply chain' | 'third party' | 'accountable person' |
|-----|-----------|-------------|---------------|--------------|---------------------|
| JSP-375 | 1,403 | 62 | 0 | 15 | 131 |
| JSP-975 | 887 | 27 | 0 | 6 | 0 |
| JSP-392 | 1,001 | 24 | 0 | 0 | 0 |
| JSP-816 | 556 | 27 | 15 | 1 | 1 |
| JSP-815 | 433 | 19 | 12 | 2 | 6 |

### Implication for enrichment

- Regex is a coarse filter (like for laws) — can tag contractor_mentioned provisions
- A fine-tuned SLM (fractalaw) is needed to reliably classify:
  - **Responsibility assignment**: who (SRO/User/Contractor/AP) must do what
  - **Obligation strength**: must (directive) vs should (guidance)
  - **Applicability scope**: internal-only / contractor-applicable / all-parties
- This is Phase 3 (fractalaw integration) territory, not sertantai-legal work
- The provision text is now in the database — fractalaw can pull it via Zenoh

## Notes
- HSG65 issue: prose without numbered paragraphs, body text dropped → fixed with :hse_guidance profile
- :hse_guidance uses :prose_body role + auto-incrementing counter per section
- JSP 317 (Fuels) URL returns 404 — may be restricted
- JSP 319 (Gases) is ODT-only — parked
- JSP 816 mirrors JSP 815 structure (12 elements) — :mod_jsp profile works
- NAS backup script renamed export-snapshot.sh → nas-backup.sh, now syncs data/ too
- Using /secondary-source-parsing skill workflow
