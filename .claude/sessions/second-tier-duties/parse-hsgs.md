---
session: Parse HSGs
project: sertantai-legal
status: closed
opened: 2026-07-16
closed: 2026-07-16
outcome: success
commits: []

summary: >
  Parsed 29 HSE Guidance publications with :hse_guidance profile — 19,454
  provisions, 14,822 paragraphs, 0 errors, no profile tuning. Copyright
  confirmed as OGL v3.0. Total corpus now 45,049 provisions.

decisions:
  - what: Parse all 29 available HSGs rather than filtering by relevance
    why: All are freely available OGL content, :hse_guidance profile handles them without tuning, and customer relevance varies — better to have the corpus available
    result: 29 HSGs, 19,454 provisions. Largest HSG76 (1,629 paras), smallest HSG276 (68 paras)

metrics:
  hsgs_parsed: 29
  hsg_provisions: 19454
  hsg_paragraphs: 14822
  total_corpus: 45049
  parse_errors: 0
  profile_tuning_needed: 0
  largest: { id: "HSG76", title: "Warehousing and Storage", paragraphs: 1629 }

lessons:
  - title: HSE guidance formatting is remarkably consistent — :hse_guidance profile needed zero tuning across 29 documents
    detail: "Unlike JSPs which needed 6 tune cycles and a profile refactor, all 29 HSGs parsed first time with the prose body capture profile. HSE's publishing template is standardised across the entire HSG series."
    tag: data
  - title: HSGs are H&S domain only — environmental guidance comes from EA/SEPA, MoD guidance from JSPs
    detail: "User corrected assumption that HSGs might span domains. HSG = HSE H&S Guidance, full stop. Environmental, radiation, defence safety all have their own publication series."
    tag: data
  - title: All HSE publications (ACoPs, HSGs) are Crown Copyright under OGL v3.0
    detail: "Confirmed from both the HSE website footer and the PDF copyright notice inside HSG65. Text content is free to copy, publish, distribute, adapt with attribution. Images may have separate copyright but we only store text. Same terms apply to JSPs (MoD Crown Copyright)."
    tag: data

artifacts: []

depends_on:
  - second-tier-duties/phase-2-provision-parsing.md

enables:
  - Baserow sync of HSG guidance alongside law provisions and ACoP obligations
  - Fractalaw enrichment of HSG provisions
---

# Title: Parse HSGs

**Started**: 2026-07-16
**Parent**: second-tier-duties/meta.md

## Copyright
- HSGs are Crown Copyright under Open Government Licence v3.0
- Text content: free to copy, publish, distribute, adapt
- Images/illustrations: may have separate copyright (we only store text)
- Attribution required: "© Crown Copyright. Open Government Licence v3.0"
- Same terms as ACoPs and JSPs

## Todo
- [x] Verify copyright status — OGL confirmed from PDF and HSE website
- [x] Identify relevant HSGs from HSE website — 29 free PDFs found
- [x] Download 28 HSG PDFs — all 200 OK
- [x] Register all 29 as secondary sources
- [x] Parse with :hse_guidance profile — 0 errors, no tuning needed
- [x] Verify: 19,454 provisions, 14,822 paragraphs across 29 HSGs

## Notes
- HSG65 already parsed: 412 provisions, 191 paragraphs (prose profile)
- :hse_guidance profile handles unnumbered prose body text
- HSGs are guidance (legal_weight = regard_had_to), not ACoPs (reverse_burden)
- All HSGs are Crown Copyright under OGL v3.0
