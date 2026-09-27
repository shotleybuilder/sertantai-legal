---
session: "LAT Sync Manifest (fractalatai #62, legal side)"
status: active
opened: 2026-09-26
related: ["fractalatai#62", "fractalatai#61", 120]
bugs:
  - pattern: "mix lat.fix_section_ids rewrites/deletes legal_articles rows in place without a ChangeNotifier event, so fractalaw's hub kept the old section_id generation (e.g. UK_ssi_2016_88 reg.4(4) holding '4.—(1)…' text)"
    category: sync
    module: Mix.Tasks.Lat.FixSectionIds
    affected: "laws touched by the #120 fix"
    fix: "Emit a lat event (with lat_hash) per law after applying corrections; the manifest self-heals past misses"
    status: fixed
  - pattern: "making_funnel asks for a LAT parse on revoked laws: 803 revoked laws have next_action lat_parse / lat_parse_or_review"
    category: funnel
    module: making_funnel view (next_action)
    affected: 811
    fix: "Migration 20260926163414: revoked laws (live Revoked|Repealed|Abolished) get no next_action; new revoked column. On dev: lat_parse 2,706 → 2,430, lat_parse_or_review 983 → 456, review_lat_deleted 8 → 0"
    status: fixed
  - pattern: "Fractalaw enriched revoked laws from stale hub LAT that legal no longer holds; 9 of the 11 #58 false→true flips are revoked (e.g. PPC 2000, Water Quality 2000, Solvent Emissions 2004, Renewables Obligation 2009)"
    category: sync
    module: fractalaw hub / #62 manifest
    affected: 9
    fix: "Fractalaw: don't enrich laws the manifest says legal doesn't hold; Jason to decide whether the 9 revoked Making flags stand"
    status: open
  - pattern: "Suspicious live status: UK_ukpga_1949_97 (National Parks and Access to the Countryside Act 1949) and UK_ukpga_1949_74 (Coast Protection Act 1949) are marked Revoked; NPACA 1949 is largely in force. The register also still holds one regnal-year name (UK_ukpga_1961_Eliz2/9-10/62)"
    category: register_hygiene
    module: legal_register.live / naming (QQ-06)
    affected: 3
    fix: "Re-check live status against legislation.gov.uk; rename the regnal-year record"
    status: open
  - pattern: "LatParser sort_key encodes the lettered items (c)/(d) as Roman numerals 100/500 (also i, l, m, v, x), so e.g. reg.6(4)(c),(d) sort after (g). The LAT queryable orders by sort_key, so fractalaw receives these rows out of order"
    category: lat_parser
    module: SertantaiLegal.Legal.Lat.Transforms.build_sort_key/2
    affected: "5,040 paragraph sort breaks in 545 laws (stored)"
    fix: "Code fixed: the paragraph (P3) segment is letters-only (normalize_provision_to_sort_key(p, roman: false)); inserted (za)/(aa) keep their legislative order. Re-parsing a 20-law sample in memory cut paragraph breaks ~175 → 5. Stored data rewritten in place (Jason: in-place now, rest later) with `mix lat.rewrite_sort_keys --apply`: 20,848 rows in 579 laws, snapshot `sort_key_rewrite_snapshot_20260926`. Stored paragraph breaks 5,040 → 1,930; the remainder is the older-format laws (see below)"
    status: fixed
  - pattern: "Signed rows get sort_key 000.000…, so every law's signed row sorts first while positioned last (755 laws)"
    category: lat_parser
    module: SertantaiLegal.Legal.Lat.Transforms.build_sort_key/2
    affected: 755
    fix: "Code fixed: the signed row gets part segment 999, so it sorts after the body and before the schedules. Stored data rewritten in place (same run): stored breaks 755 → 290; the remainder is the older-format laws"
    status: fixed
  - pattern: "Apparent parent drop after nested sub-paragraphs (UK_wsi_2025_1321 reg.39(e), 27(i), 44(d), 46(b))"
    category: lat_parser
    module: none (source markup)
    affected: 0
    fix: "Not a bug: legislation.gov.uk's own XML closes the P2 before these items and gives them the official ids regulation-39-e etc.; legal's ids mirror the official ones. No fix and no id churn"
    status: fixed
  - pattern: "EU retained laws: every 'Article N' shared one sort_key provision segment (the letters 'AR'); labelled parts (PART7A, CHAPTER III) likewise"
    category: lat_parser
    module: SertantaiLegal.Legal.Lat.Transforms.normalize_provision_to_sort_key/2
    affected: "65 EU laws (9,235 rows); 6 laws with labelled parts (258 rows)"
    fix: "Code fixed: strip known number labels (ARTICLE, PART, CHAPTER…) and parentheses before building segments. Stored data rewritten in place (snapshots sort_key_rewrite_eu_snapshot_20260926 and sort_key_rewrite_part_snapshot_20260926). EU article breaks ~1,050 → 74"
    status: fixed
  - pattern: "386 of 980 laws carry sort_keys from older parser generations (80,111 rows with 22 segments and no position; 56,444 with the crude 3-segment format), which the current code never produced"
    category: lat_data
    module: legal_articles.sort_key (historical)
    affected: 386
    fix: "Re-parse those laws. But DELETE+INSERT wipes fractalaw provision enrichment (101 of them are enriched) and may shift section_ids, so do it after fractalaw's #62 diff-apply or with a provision republish"
    status: open
  - pattern: "Merge gate counted legacy_id (import-era identity) as enrichment and refused UK_nisr_2014_224 over one shifted positional heading row"
    category: lat_merge
    module: SertantaiLegal.Scraper.LatPersister.Carry
    affected: 1
    fix: "The gate ignores legacy_id (still carried when rows match)"
    status: fixed
---

# Session: LAT Sync Manifest, legal side of fractalatai #62 (ACTIVE)

## Problem

Fractalaw's hub copy of LAT has drifted from legal's: 345 of 802 hub laws are missing text, including 1,545 duty paragraphs across 128 laws. Three things cause it:
- fire-once `lat` events with no version, which are dropped while the ChangeNotifier publisher isn't ready;
- legal write paths that emit no event (`lat.fix_section_ids`, #120);
- fractalaw's never-delete upsert.

The agreed fix is a per-law `lat_hash` manifest that fractalaw polls, re-pulling any law whose hash differs.

## Todo

- ✅ `LatHash` (pure reference implementation) and the SQL function `lat_hash_for()`, held equal by tests over persisted rows with NBSP, U+202F, U+1680, U+2007, decomposed accents, empty-text rows and bytewise ordering. Line = `section_id \t sort_key \t normalise(text) \n`.
- ✅ Shared vectors in `backend/test/fixtures/lat_hash/vectors.json` (synthetic, empty, fixture_law = LatParser on `test/fixtures/body_xml/with_schedules.xml`: 9 rows, 5 empty-text). Expected hashes computed by an independent Python implementation; legal pins them in `lat_hash_test.exs`.
- ✅ `DataServer` queryable `lat-manifest/{law}` and `lat-manifest/*` via `Zenoh.LatManifest` (Arrow default, `?format=json`), declared live after a server restart. **Change of plan: the hash is stored, not computed on demand.** The earlier "127 ms" was a measurement artefact (Postgres skipped the hash inside `count(*)`); the real full-corpus cost is 8.4 s. Now `legal_register.lat_hash` is maintained by the statement-level LAT stats triggers (migration `20260926160743`). INSERT/DELETE refresh affected laws; UPDATE refreshes only laws whose (law_id, section_id, sort_key, text) changed (EXCEPT both ways), so enrichment updates cost nothing. The manifest read takes 57 ms. The dev backfill hashed 980 laws in 9.6 s, and lat_count = served rows for all 980.
- ✅ `lat` events carry `row_count` + `lat_hash` via `LatEvents`, sent after commit. `LatPersister` previously notified inside the transaction, so the event could beat the commit. Covers persist (guarded so a failed event cannot turn a committed write into an error) and admin `lat_deleted` (0 + empty hash).
- ✅ `lat.fix_section_ids` sends one `persist` event per affected law after commit (`reason: section_ids_fixed`). The trigger keeps `lat_hash` right for any raw-SQL path regardless.
- ✅ The queryable and the hash share one row definition (`LatHash.Query.served_query/1`, used by `DataServer.fetch_lat_by_law`); tests assert the stored hash equals the hash of the served rows.
- ✅ Classify the 76 hub-only laws. 66 are revoked, and legal holds no LAT for them (they include 9 of the #58 flips). 5 are regnal-year duplicates of modern names (e.g. `UK_ukpga_1875_Vict/38-39/17` → `UK_ukpga_1875_17`). 5 are in force with no LAT in legal, which is legal's gap: `UK_ssi_2005_157`, `UK_uksi_1998_892`, `UK_uksi_2015_10`, `UK_wsi_2014_3303`, `UK_ukpga_1994_27`.
- ✅ LAT-parsed the 5 in-force hub-only laws (session `lat-parse-hub-only-in-force-2026-09-26-1504`): UK_ssi_2005_157 has 258 rows, UK_uksi_2015_10 141, UK_wsi_2014_3303 133, UK_ukpga_1994_27 20 and UK_uksi_1998_892 9, with 0 errors. QA: 0 fail, 4 warn (sort breaks = the two parser bugs above). 4 were already `enriched` from stale hub LAT, so they need re-enrichment on the fresh LAT.
- ✅ Decision (Jason, 2026-09-26): `sort_key` is included in the hash. Final row line: `section_id \t sort_key \t normalise(text) \n` (sort_key as-is, NULL → ""). The LatParser sort_key fix will therefore self-heal through the manifest. New vectors were sent to fractalaw: synthetic (sort_key `00001~`) `79bc96ea…f07b`, empty law `e3b0c442…b855`.
- ✅ Contract amendments agreed by fractalaw (row set = all served rows; explicit White_Space set; event metadata). Synthetic vector `f6ae5038…f8a5` and empty-law vector sent; a checked-in fixture law vector is to follow from the LatHash tests.

- ✅ Fractalaw live cross-check (2026-09-26): 0 mismatches. All 3 vectors match its independent Python implementation. `lat-manifest/*` over Zenoh (Arrow) returned 980 laws; fractalaw pulled `lat/{law}` for all 980 and recomputed, with 980/980 matching on hash and row_count (~14 s pass). A no-LAT law gives row_count 0 + the empty hash; `?format=json` works. Note: `lat/{law}` for a no-LAT law replies with a zero-length payload, not an empty Arrow stream, which fractalaw treats as 0 rows.
- ⏸️ Migration `down` not exercised (rollback denied in this session); it restores the 20260925161749 trigger functions verbatim

- ✅ In-place sort_key rewrite (`SortKeyRewrite` pure + `SortKeyRewrite.Store`, `mix lat.rewrite_sort_keys`): 20,848 rows in 579 laws, with enrichment and section_ids kept. The triggers refreshed lat_hash for all 579, and 0 of 980 stored hashes differ from `lat_hash_for()`. Fractalaw was told.
- ⏸️ Re-parse the 386 older-format laws: after fractalaw's #62 diff-apply (see the open bug above)

- ✅ (Gemini review) `LatPersister`: merge on re-parse instead of DELETE+INSERT. Keep provision enrichment on rows with the same section_id and text, carry it across renames by unique text match, and blank only rows whose text changed. This also closes today's exposure: any re-parse of an enriched law wipes its enrichment (209,084 enriched rows in 637 laws).
- ✅ (Gemini review) Re-parse emits an explicit old→new section_id map (reuse the #120 text-join), flags ambiguous duplicates, migrates `control_mappings` / `amendment_annotations` in the same transaction, and sends the map to fractalaw.
- ✅ (Gemini review) Per-law gate: no enrichment lost on unchanged-text rows (report changed rows separately), FK counts preserved. Batch snapshots, then pilot (1 unenriched, 1 enriched with id changes, 5–10 laws), then batches of ~30.

- ✅ Merge built (`LatMerge` pure, `LatPersister.Carry` DB): carries every non-parser column, runs the gate, migrates FKs, and logs to `lat_section_id_renames`, served as the `lat-renames/{law}` / `*` queryable (?since=). Match types: unique_text, ordered_text, extent_tag.
- ✅ The matcher was tuned on real drift using a dry run (`mix lat.reparse --dry-run`) over the 101 enriched older-format laws. Carried enriched rows: 64% → 87.6% (30,257 / 34,550). The remainder is repealed dots, changed text, heading rows the new parser omits, and 126 ambiguous; 10 laws fail the gate.
- ✅ struct_hash (Jason, via fractalaw): the manifest and events carry it; trigger-maintained; vectors; fractalaw cross-checked 980/980.
- ✅ NAS backup (`nas-backup.sh --archive`) before the rollout.
- ✅ Pilot 1 (unenriched `UK_uksi_2006_1521`) passed.
- ✅ Re-parsed the 284 unenriched older-format laws (batches of 30, snapshots `lat_reparse_unenriched_b00` and `lat_reparse_unenriched_r01`–`r09`, reports `data/reports/lat-reparse/`), with 0 errors. Rows 85,759 → 91,847; 443 renamed, 68 ambiguous, 10,195 dropped (older-generation rows the current parser splits differently), 0 orphaned control mappings. Corpus sort breaks are now 1,623 (from ~8,000 at session start). Only the 101 enriched laws remain in the older format. Hashes are consistent for all 980 laws. The first run stopped at `UK_nisr_2014_224` on a legacy_id-only gate hit; the fix is below.
- ✅ Enriched older-format laws (101). Jason accepted that the lost rows go on fractalaw's re-enrichment backlog. 91 were re-parsed with the gate on and 10 forced (`UK_ukpga_1990_43`, `1974_40`, `1984_55`, `1990_9`, `1995_25`, `2009_23`, `2013_32`, `2021_30`, `UK_uksi_2018_390`, `2026_318`), with 0 errors; snapshots are `lat_reparse_enriched_b00` (15 laws) and `lat_reparse_enriched2_b00`–`b02` plus `_forced10`. Enriched rows went 34,550 → 25,414 (9,136 lost); 33,933 non-empty rows now need enrichment (the new parser splits much finer, e.g. UK_ukpga_1991_56 has 809 → 8,288 rows). Per-law list: `data/reports/lat-reparse/reenrichment-list.csv`, sent to fractalaw.
- ✅ Fractalaw review: the merge had carried enrichment onto same-id rows whose old text contained the new (parents that aggregated children, headings now empty), attributing the children's duties to the stripped-down row. The rule is now new ⊇ old only (aligned with fractalaw). The 15 laws re-parsed before the fix were corrected (enrichment cleared on 237 rows in 11 laws).
- ✅ End state: 0 laws in the older sort_key format; corpus sort breaks 668 (from ~8,000); lat_hash and struct_hash consistent for all laws. Control mappings: 3 re-pointed to extent-tagged ids (EPA 1990 s.78F, EA 1995 s.113(3), s.80(5)); 2 left orphaned because their provisions are now repealed (EPA 1990 s.40(4), s.74(3); control 4080cd6c…), which needs a review decision.

- ✅ Remaining 668 sort breaks fixed (Jason, via fractalaw, 2026-09-27). Causes (per break: `data/reports/lat-reparse/sort-breaks-2026-09-27.csv`):
  - 208 insert-order / numbering conflicts
  - 133 title-valued or irregular Part/Chapter/heading numbering
  - 96 `#n` duplicate ids
  - 70 letter-then-digit numbers (`105Z27`, `z10`)
  - 63 source markup (item after its paragraph closed)
  - 58 numbering the key cannot express (`(1ZA)`, `(A8)`, `(vic)`)
  - 20 tables
  - 20 parallel-extent rows

  Encoder fixes: 6-digit position (UK_ukpga_2003_21 has 10,900 rows), letter-then-digit numbers, title-valued Parts. Everything else is handled by the document-order repair (`SortKeyRewrite.monotonic/1`): it keeps each law's longest increasing run of keys and gives the other rows their predecessor's structural prefix with their own position. It is applied in `LatParser.parse/2` and in the in-place rewrite, and re-keyed 3,230 rows.
  - Applied to all 352,300 rows (snapshot `sort_key_rewrite_snapshot_20260927`). Corpus breaks 668 → 0; hashes consistent; the tool is idempotent (a re-run plans 0 rows).
  - Caveat: repaired rows' key segments are borrowed from the preceding row, so they order correctly, but the segments are not the row's own numbering. Read structure from the part/provision columns, never by decoding sort_key.

## Dependencies

- ✅ Contract proposed by fractalaw-a4 (2026-09-26); legal's changes sent: hash over all served rows, explicit whitespace set, event metadata
- ✅ Fractalaw agreed the amended contract (2026-09-26)
- ✅ LAT queryable already returns the complete row set (no paging)
- ⬜ Fractalaw's #62 diff-apply (fractalaw will notify legal). It blocks the 386-law re-parse and the parent-drop section_id fix. Its text-match carry-over preserves tier data across id changes, and it treats sort_key-only changes (the 579 rewritten laws) as in-place updates. No fractalaw re-pulls until then.

## Gemini review (2026-09-26)

Brief: `backend/data/code-reviews/2026-09-26-lat-sync-enrichment-brief.md`. Review (gemini-2.5-pro): `backend/data/code-reviews/2026-09-26-lat-sync-enrichment-review.md`.

Adopted:
- Legal owns preservation: merge in `LatPersister`, not recovery by fractalaw republish.
- An explicit id map from legal.
- FK migration in the same transaction.
- Per-law gates, batch snapshots and a pilot.
- The race between an enrichment publish and a re-parse, which the merge also fixes.

Adjusted:
- The gate is "no enrichment lost on rows whose text is unchanged", not equal enriched-row counts: enrichment on genuinely changed text is stale and should be re-derived.
- No separate staging environment or multi-week phases: dev is the only environment of record. Use a NAS backup and batch snapshot tables, and do the pilot on dev.
- `position` stays out of the hash by design, because it is derived from sort order.
