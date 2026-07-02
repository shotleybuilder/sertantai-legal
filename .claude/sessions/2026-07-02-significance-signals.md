# Title: Significance Signals from Fractalaw

**Started**: 2026-07-02
**Context**: Fractalaw now publishes significance ratings at law-level and provision-level via Zenoh taxa payloads (see `docs/ZENOH-SPEC.md` v2.0)

## Todo
- [ ] Read ZENOH-SPEC.md and identify new fields
- [ ] Add law-level significance columns to LegalRegister (rating, score, high/med/low counts, total)
- [ ] Add provision-level significance columns to LegalArticle (5 dimensions + confidence + overall)
- [ ] Update TaxaSubscriber to map new law-level significance fields
- [ ] Update ProvisionSubscriber to map new provision-level significance fields
- [ ] Handle actors field change: now `Utf8` (JSON string) not `List<Struct>`
- [ ] Handle extraction_method vocab change: regex, reconciled, slm, llm, inferred
- [ ] Generate migration
- [ ] Test with live publish
- [ ] Update pipeline status skill to include significance

- [ ] Add `significance_parts` (JSON) to LegalRegister — part-level breakdown for large Acts
- [ ] Map `significance_parts` in TaxaSubscriber
- [ ] Migration for significance_parts column
- [ ] Test with HSWA publish (has Part structure)

## Notes
- Law-level: significance_rating (H/M/L), significance_score (float), K-profile counts
- Provision-level: 5 dimensions (gravity, scope_duty_bearer, scope_protected_class, strength, hierarchy) + confidence + overall
- Part-level: significance_parts JSON array `[{part, high, medium, low, total}]` — only for Acts with ≥50 rated provisions
- actors column now JSON string not Arrow struct — ProvisionSubscriber needs to parse
- extraction_method values changed from old vocab
