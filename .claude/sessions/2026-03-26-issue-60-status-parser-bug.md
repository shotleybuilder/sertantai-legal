# Issue #60: Status parser incorrectly marks in-force laws as revoked/repealed

**Started**: 2026-03-26T11:05Z
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/60
**Blocking**: #56 (LAT deletion feature)

## Todo
- [x] Bug 1: `determine_live_status` missing "except for" partial revocation pattern — only checks "in part", misses `"revoked (except for regs. 1, 2(2)(b)...)"`
- [x] Bug 2: `set_live_status` maps `document_status: "final"` → `✔ In force` — but "final" means "original text, not revised", NOT "currently in force". Genuinely revoked laws (e.g. uksi/2010/676) have `"final"` status
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
- Bug 2 investigation: `document_status` values on legislation.gov.uk:
  - `"final"` = original text, not revised by legislation.gov.uk — NOT an in-force indicator
  - `"revised"` = legislation.gov.uk has updated the text — NOT an in-force indicator (revoked laws can be "revised")
  - `"repealed"`/`"revoked"` = definitive revocation marker BUT rarely used (most revoked laws have "revised")
  - **Title `(repealed DD.MM.YYYY)` or `(revoked DD.MM.YYYY)` is the definitive metadata signal**
  - Confirmed: Clean Air Act 1956 title = "Clean Air Act 1956 (repealed 27.8.1993)", status = "revised"
  - Confirmed: Badgers Act 1991 title = "Badgers (Further Protection) Act 1991 (repealed 16.10.1992)", status = "revised"
  - Edge case: uksi/2010/676 genuinely revoked but NO title marker AND status = "revised" — only detectable via /changes/affected
- Bug 2 fix: `set_live_status` now checks title for `(repealed` / `(revoked` first (definitive), then `document_status` repealed/revoked, then defaults to in_force. 8 tests added.

## Bug 4 — Recommendation: Simplify live status to "changes-primary, metadata-override"

### Problem

The current "Most Severe Wins" reconciliation (`staged_parser.ex:469`) uses two independent sources to determine `live`:

| Source | Stage | Endpoint | What it tells us |
|--------|-------|----------|-----------------|
| `live_from_changes` | `amended_by` (stage 5) | `/changes/affected` | Analyses revocation entries — detects partial AND full revocations |
| `live_from_metadata` | `repeal_revoke` (stage 6) | `/resources/data.xml` | Checks `dc:title` for `(repealed...)`, `RepealedLaw` element, `SupersededBy` element |

Investigation shows:
- The `resources/data.xml` endpoint returns the **same** `dc:title` and `DocumentStatus` as `introduction/data.xml` (metadata stage 1)
- `RepealedLaw` and `SupersededBy` XML elements are **never populated** in any law tested
- So `repeal_revoke` (stage 6) duplicates what `metadata` (stage 1) already provides after Bug 2 fix
- The title `(repealed ...)` marker is only present on ~half of genuinely revoked laws — it is definitive when present but patchy
- `/changes/affected` is the **only** source that can detect revocations for laws without a title marker (e.g. uksi/2010/676)

### Data (5,510 parsed records)

| live | source | conflict | count | note |
|------|--------|----------|-------|------|
| ✔ In force | both | false | 2,716 | Both agree — no problem |
| ❌ Revoked | changes | true | 1,267 | Changes says revoked, metadata says in force — **the bug group** |
| ❌ Revoked | both | false | 828 | Both agree revoked — no problem |
| ⭕ Partial | changes | true | 640 | Changes detected partial — correct behaviour |
| ❌ Revoked | changes | false | 40 | Only changes available — correct |
| ❌ Revoked | metadata | true | 19 | Metadata says revoked, changes says in force — correct |

### Proposed new strategy: "Changes-primary, metadata-override"

**Changes is the primary source.** It analyses actual revocation entries and is the only way to detect most revocations. After bugs 1-2, it is now more accurate.

**Metadata overrides only when definitive.** Title marker `(repealed ...)` / `(revoked ...)` is a hard override to revoked — no reconciliation needed.

Resolution rules:
1. If metadata says revoked (title marker or doc_status) → **revoked** (definitive)
2. Otherwise → **use changes** (in_force / partial / revoked as determined by `determine_live_status`)

### Proposed implementation

**A. Remove `repeal_revoke` stage entirely (stage 6)**
- Its only useful signal (title check) is now done by `metadata` stage (Bug 2 fix)
- `RepealedLaw` / `SupersededBy` elements are never populated — dead code
- Saves one HTTP request per law during parsing

**B. Simplify `reconcile_live_status` → single function**
- No more severity ranking, no more "Most Severe Wins"
- New logic in `update_result` after `amended_by` stage completes:

```
if metadata says revoked (from title/doc_status) → live = revoked
else → live = live_from_changes
```

**C. Simplify DB schema** — drop 4 columns:
- `live_from_metadata` — redundant (always same as metadata stage's title-derived status)  
- `live_conflict` — no longer meaningful with single-source priority
- `live_conflict_detail` — JSONB, no longer needed
- `live_source` — always deterministic from the rule above, no need to store

Keep: `live` (final status), `live_from_changes` (useful for debugging / audit trail), `live_description`

**D. Frontend changes**
- Remove `live_from_metadata`, `live_conflict`, `live_conflict_detail`, `live_source` from:
  - `UkLrtRecord` type in `+page.svelte`
  - `LRT_COLUMNS` SQL string
  - Column definitions
  - `LIVE_VIEW_COLUMNS` / `LAT_CLEANUP_COLUMNS`
  - PGLite `schema.sql.ts` and `sync.ts`
  - `analytics.ts` and `lat.ts` types
- Simplify Live Status admin view to show `live` + `live_from_changes` only

### Risk / edge cases

- **uksi/2010/676 pattern** (genuinely revoked, no title marker, no metadata signal): changes correctly says revoked via `/changes/affected` → now becomes the primary → **correctly resolved**
- **HASAWA pattern** (in force, section-level repeals): after Bug 1 fix, changes now correctly says partial → **correctly resolved**
- **False full revocation from changes** (still possible for edge cases): no metadata override available, so this remains a risk — but greatly reduced after Bug 1 `"except"` fix
- **13,820 unparsed records**: their `live` values come from the original SQL import, not the parser. This change only affects future parses.

### Alternative: Keep columns, just change the logic

If dropping DB columns feels too risky or the audit trail is valued, we could:
- Keep all 7 `live_*` columns
- Just replace the reconciliation logic (option B above)
- This is a smaller, safer change and the schema migration can happen later
