---
session: Parse ACoPs
project: sertantai-legal
status: closed
opened: 2026-07-16
closed: 2026-07-16
outcome: success
commits: []

summary: >
  Parsed 21 HSE ACoPs (L-series) with :hse_acop profile — 12,321 provisions,
  6,347 paragraphs, 0 errors. Verified 8 "missing" ACoPs are all withdrawn or
  superseded by publications already parsed. 100% coverage of current ACoPs.

decisions:
  - what: Accept 21 of 29 seeded ACoPs as complete coverage
    why: 8 missing L-numbers are withdrawn (L127→L143, L134-137→L138) or removed entirely (L1, L21, L44). All superseding publications already parsed.
    result: 100% current ACoP coverage confirmed

metrics:
  acops_parsed: 21
  acop_provisions: 12321
  acop_paragraphs: 6347
  total_corpus_provisions: 26007
  parse_errors: 0
  withdrawn_acops: { L127: "→L143", L134: "→L138", L135: "→L138", L136: "→L138", L137: "→L138" }
  removed_acops: ["L1", "L21", "L44"]
  largest_acop: { id: "L121", provisions: 1128, paragraphs: 551 }

lessons:
  - title: "\"Missing\" HSE ACoP PDFs are withdrawn editions, not paywalled content"
    detail: "Initial assumption was that 8 ACoPs were priced publications behind a paywall. Checking the HSE book pages revealed they're all withdrawn -- L127 superseded by L143, L134-137 consolidated into L138 (both already parsed). L1/L21/L44 have no page at all (removed). Always check the book page before assuming access restrictions."
    tag: data
  - title: The :hse_acop profile handled all 21 ACoPs without any tuning
    detail: "Every ACoP parsed first time with the 10pt body / 'N Text' numbering profile. HSE formatting is remarkably consistent across the L-series. No profile adaptation needed unlike JSPs which needed multiple tune cycles."
    tag: tooling

artifacts: []

depends_on:
  - second-tier-duties/phase-2-provision-parsing.md

enables:
  - Fractalaw enrichment of ACoP provisions
  - Baserow sync of ACoP obligations alongside law provisions
---

# Title: Parse ACoPs

**Started**: 2026-07-16
**Parent**: second-tier-duties/meta.md

## Todo
- [x] Download HSE ACoP PDFs — 21 of 29 available (8 are priced/not free)
- [x] Parse all 21 ACoPs with :hse_acop profile — 0 errors
- [x] Verify paragraph counts — 12,321 provisions, 6,347 paragraphs
- [x] Profile tuning — none needed, :hse_acop worked for all 21

## Missing ACoPs — all withdrawn/superseded, not missing
- L1, L21, L44: no HSE page exists (404) — old editions removed entirely
- L127 (Asbestos): withdrawn → superseded by L143 (already parsed, 465 paras)
- L134, L135, L136, L137 (DSEAR): withdrawn → consolidated into L138 (already parsed, 524 paras)
- **100% coverage of current ACoPs achieved**

## Notes
- All 21 ACoPs parsed first time with :hse_acop profile, no tuning needed
- Largest: L121 (Ionising Radiation) = 1,128 provisions, 551 paragraphs
- Smallest: L8 (Legionella) = 168 provisions, 99 paragraphs
- Total corpus: 26,007 provisions across JSPs + ACoPs + HSG65
