---
session: Parse Environmental Guidance (OGL series)
project: sertantai-legal
status: closed
opened: 2026-07-16
closed: 2026-07-16
outcome: deferred
commits: []

summary: >
  Research session. Environmental guidance lacks clean numbered series like
  HSGs/ACoPs. Old PPG/GPP moved to web-only. Key OGL PDFs identified
  (Waste Duty of Care, WM3, EP Core Guidance) but thin set — MoD JSPs
  already cover environmental compliance for defence contractors. Suspended.

decisions:
  - what: Defer environmental guidance parsing
    why: Fragmented landscape (no numbered series), MoD JSPs already cover environmental compliance (JSP-418 + JSP-816 = 2,078 provisions), and the available EA PDFs are regulatory process guidance rather than operational compliance
    result: Research captured, 3 key PDF URLs identified for future use

lessons:
  - title: Environmental guidance is not a clean numbered series — it's individual gov.uk publications
    detail: "Unlike HSE which has L-series (ACoPs) and HSG (guidance) as well-structured numbered catalogues, EA/Defra environmental guidance was fragmented across PPG→GPP→web-only transitions. The old PPG series was withdrawn, GPP moved to NetRegs web-only, SGN/TGN partially replaced by 'appropriate measures' pages. Only a handful of standalone PDFs remain on gov.uk."
    tag: data

artifacts: []

depends_on:
  - second-tier-duties/phase-2-provision-parsing.md

enables:
  - Future environmental guidance parsing if customer demand warrants it
---

# Title: Parse Environmental Guidance (OGL series)

**Started**: 2026-07-16
**Parent**: second-tier-duties/meta.md

## Todo
- [x] Research EA/Defra environmental guidance series
- [ ] Download and parse available environmental guidance PDFs
- [ ] Register as secondary sources (type: guidance, weight: regard_had_to)

## Research findings
Environmental guidance is NOT a clean numbered series like HSG or L-series.
The old PPG (Pollution Prevention Guidelines) were withdrawn and replaced by
GPP (Guidance for Pollution Prevention) which moved to web-only on NetRegs.
EA technical guidance (SGN/TGN) also partially withdrawn.

What IS available as OGL PDFs on gov.uk:

### Waste
- Waste Duty of Care Code of Practice (Defra, 20pp, 315KB)
  `https://assets.publishing.service.gov.uk/media/6274d74bd3bf7f5e3ade6090/Waste_duty_of_care_code_of_practice.pdf`
- Waste Classification Technical Guidance WM3 (EA, 5.4MB)
  `https://assets.publishing.service.gov.uk/media/6152d0b78fa8f5610b9c222b/Waste_classification_technical_guidance_WM3.pdf`

### Environmental Permitting
- EP Core Guidance for EPR 2016 (Defra, 93pp, 665KB)
  `https://assets.publishing.service.gov.uk/media/5fb3a39dd3bf7f37d7e7270e/environmental-permitting-core-guidance.pdf`
- EP Waste Framework Directive guidance
- EP IPPC Directive guidance
- EP Solvent Emissions Directive guidance
- EP Groundwater Activities guidance
- EP Statutory Nuisance guidance

### Already covered by JSPs
- JSP-418 (9 leaflets, 857 provisions) — MoD environmental protection
- JSP-816 (13 elements, 1,221 provisions) — MoD environmental management system

## Notes
- All gov.uk publications are OGL v3.0 (confirmed from page footers)
- Environmental guidance is less structured than H&S — more individual documents
- Key question: are the EP part guides worth parsing? They're regulatory process
  guidance, not operational compliance like HSGs/ACoPs
