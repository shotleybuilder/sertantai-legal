# Issue #60: Status parser incorrectly marks in-force laws as revoked/repealed

**Started**: 2026-03-26T11:05Z
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/60
**Blocking**: #56 (LAT deletion feature)

## Todo
- [x] Bug 1: `determine_live_status` missing "except for" partial revocation pattern — only checks "in part", misses `"revoked (except for regs. 1, 2(2)(b)...)"`
- [ ] Bug 2: `set_live_status` maps `document_status: "final"` → `✔ In force` — but "final" means "original text, not revised", NOT "currently in force". Genuinely revoked laws (e.g. uksi/2010/676) have `"final"` status
- [ ] Bug 3: HASAWA parsed at 09:20 on March 12, before 3 fixes to `determine_live_status` committed later that day (13:58, 14:39, 17:10) — stale parse data, needs re-parse
- [ ] Bug 4: `reconcile_live_status` "Most Severe Wins" strategy can't work when neither source is reliable — needs rethinking after bugs 1-2 are fixed
- [ ] Re-parse the 1,266 conflict records (changes=revoked, metadata=in_force) after fixing bugs 1-2

## Notes
- 1,266 records: changes=revoked, metadata=in_force — mix of genuinely revoked AND genuinely in force
- 974 of those parsed AFTER March 12 fix — bug 1 still causing over-reporting
- HASAWA (UK_ukpga_1974_37): parsed pre-fix, 31 section-level repeals all misclassified as full revocation
- uksi/2010/676: genuinely revoked (confirmed on legislation.gov.uk) but metadata says "final" not "revoked"
- `document_status: "revised"` may be the only reliable positive indicator of in-force
- Key files: `amending.ex:455` (determine_live_status), `metadata.ex:428` (set_live_status), `staged_parser.ex:469` (reconcile_live_status)
- Bug 1 fix: added `"except"` check to `determine_live_status` cond chain, fixture row 26, test added
- Verified: uksi/2007/175 now correctly returns `⭕ Part Revocation` (was `❌ Revoked`)
