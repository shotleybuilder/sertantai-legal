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
    fix: "Code fixed: the paragraph (P3) segment is letters-only (normalize_provision_to_sort_key(p, roman: false)); inserted (za)/(aa) keep their legislative order. Re-parsing a 20-law sample in memory cut paragraph breaks ~175 → 5. Stored data is not yet rewritten (awaiting Jason's decision)"
    status: fixed
  - pattern: "Signed rows get sort_key 000.000…, so every law's signed row sorts first while positioned last (755 laws)"
    category: lat_parser
    module: SertantaiLegal.Legal.Lat.Transforms.build_sort_key/2
    affected: 755
    fix: "Code fixed: the signed row gets part segment 999, so it sorts after the body and before the schedules. Stored data is not yet rewritten"
    status: fixed
  - pattern: "LatParser loses the parent paragraph after a nested sub-paragraph: e.g. UK_wsi_2025_1321 reg.39(2)(d)(vi) is followed by reg.39(e), which should be reg.39(2)(e) (also reg.27(i), reg.44(d), reg.46(b))"
    category: lat_parser
    module: SertantaiLegal.Scraper.LatParser (context after P4)
    affected: "unknown; seen in 1 of a 20-law sample"
    fix: "Not fixed here (scope): it changes section_ids, which fractalaw keys tier data on, so it should land with or after fractalaw's #62 diff-apply (text-match carry-over)"
    status: open
  - pattern: "EU retained laws (eur/eudr) have article rows out of sort order after re-parse (e.g. UK_eur_2008_1272 34 breaks, UK_eudr_2013_35 9)"
    category: lat_parser
    module: SertantaiLegal.Legal.Lat.Transforms / LatParser EU mode
    affected: "EU laws; not measured corpus-wide"
    fix: "Investigate the EU article/title numbering in sort_key (not the paragraph bug)"
    status: open
  - pattern: "386 of 980 laws carry sort_keys from older parser generations (80,111 rows with 22 segments and no position; 56,444 with the crude 3-segment format), which the current code never produced"
    category: lat_data
    module: legal_articles.sort_key (historical)
    affected: 386
    fix: "Re-parse those laws. But DELETE+INSERT wipes fractalaw provision enrichment (101 of them are enriched) and may shift section_ids, so do it after fractalaw's #62 diff-apply or with a provision republish"
    status: open
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

## Dependencies

- ✅ Contract proposed by fractalaw-a4 (2026-09-26); legal's changes sent: hash over all served rows, explicit whitespace set, event metadata
- ✅ Fractalaw agreed the amended contract (2026-09-26)
- ✅ LAT queryable already returns the complete row set (no paging)
