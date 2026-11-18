# Waste, Water and Climate: Sources — fetch rounds, re-scrape and rebuild (2026-11-18)

Moved from the session `2026-11-18-waste-water-and-climate-sources.md` at its close.


- **Gate after the fix** (`-1.txt`): 1,540 needs, 786 failing (feeds 547, own 65, introductions 22, territory 15, dates 13, backlog 124), 259 register differences.
- **Round 1** (Jason's go, 2026-11-18): `--fetch` of the 786 (`-fetch-1.txt`).
  - 784 fetched, 2 feeds 500 (SI 2020/1540, 2020/1647), both fetched on retry.
  - Gate (`-2.txt`): 1,557 needs, 14 failing: the orders on the 2 order lists round 1 searched (Control of Pollution Act 1974's SIs 1994–95), needed now as designed. 119 register differences (from 259).
- **Build** (restore point `sources-waste-water-and-climate-build`): 565 laws, 92,537 changes, 365 s, 0 failed; 109 laws build no changes (`-build.log`).
- **Full-needs gate** (`-3.txt`): 4,279 needs, 1,155 failing — territory 287, introductions 485, enabling parents 6, dates 142, backlog 217, royal assent 18; 21 order lists to search. Under the stop.
- **Round 2** (Jason's go): the round, then the four switched families (`waste-water-and-climate-fetch-2`, `switched-environmentalprotection-fetch-2`, `fire-and-ohs-fetch-3`, `switched-ohsoccupational-fetch-2`, `switched-maritimesafety-fetch-2`).
  - Fetched: the round 1,154 of 1,155; EP 202 of 203; Fire and OH&S 142 of 144; Occupational 83 of 83; Maritime 13 of 14.
  - The 5 failures were all order-list searches for amending Acts not in the register (no title to search by): the Control of Smoke Pollution Act 1989, the Further and Higher Education (Scotland) Act 1992, the Criminal Jurisdiction Act 1975, the Oil and Gas (Enterprise) Act 1982, the Tobacco and Vapes Act 2026.
  - Fix (Sources' own, `lat.sources` `fetch_one(:orders)`): the register's title, else the Act's own held text (`dc:title`, as `lat.commencement` does), without a repealed Act's "(repealed …)" note. The 5 lists searched on retry: 0, 2, 2, 4 and 2 orders.
- **Gates after round 2** (read-only): the round (`-4.txt`) 4,522 needs, 107 failing (dates 56, backlog 28 plus 1 stale, enabling parents 22; the orders on the newly searched lists and the parents the new introductions name), 119 register differences. Switched: EP 72 (`-6`), Fire and OH&S 33 (`-14`), Occupational 22 (`-6`), Maritime 4 (`-6`), 0 register differences each. Round 3 sized at 238 documents.
- **Round 3** (Jason's go): 238 fetched, 0 failed (the round 107, EP 72, Fire and OH&S 33, Occupational 22, Maritime 4; `-fetch-3`/`fire-and-ohs-fetch-4`).
- **Gates after round 3** (read-only): the round (`-5.txt`) **0 failing documents**; it fails only on the 119 register differences (todo 6). EP (`-7`) PASS, Maritime (`-7`) PASS. Fire and OH&S (`-15`) 2 and Occupational (`-7`) 7: bodies held since 2026-10-18 that legislation.gov.uk has since updated (stale backlog, newly needed by round 3's orders). Round 4 sized at 9 refetches.
- **Round 4** (Jason's go): the stale bodies refetched, Fire and OH&S 17, Occupational 10, 0 failed (more than the 9 sized: the fetch's own gate found more stale). Gates: Fire and OH&S (`-16`) PASS, Occupational (`-8`) PASS. **Every fetch done:** the round 0 failing documents; all four switched families PASS.
- **NAS update** (Jason's go): `./scripts/nas/nas-backup.sh --data-only`, exit 0, `backend/data` 61,233 files, 1.9 GB synced (`waste-water-and-climate-nas.log`).
- **Re-scrape** (Decision 3 a; restore point `sources-waste-water-and-climate-rescrape`): 119 applied, 0 failed (`waste-water-and-climate-rescrape.txt`). The 21 live changes are the dry run's 21, law for law.
- **Gate after the re-scrape** (`-6.txt`): 27 failing:
  - 25 backlog bodies stale, for 9 Acts whose refreshed feeds now point to them (13 for the Agriculture Act 1945 alone);
  - 2 feeds stale (the Water Act 1973, the Noise and Statutory Nuisance Act 1993), which legislation.gov.uk updated today.

  2 register differences remain, the capped Water Acts 1991, for `explained.json`.
- **Round 5** (Jason's go): 27 fetched, 0 failed. The 2 capped Water Acts 1991 went into `explained.json` (register-stats-capped-at-1000). **Round gate PASS** (`-7.txt`): 0 failures, 0 register differences.
- **Stale** (`mix lat.stale --list --family`, read-only; `waste-water-and-climate-stale.txt`): 233 of the round's built laws.
  - 21 are stale for Sources' inputs, built before this step's fetches and re-scrape: 10 feed, 11 law text. They include the Control of Pollution Act 1974, the Water Act 1973 and the Noise and Statutory Nuisance Act 1993.
  - 2 of the 21 are switched Maritime SIs (SI 1998/1691, SI 1998/2241): law text refetched in round 4, so their labels are stale by fold inputs.
  - The rest are stale for the Commencement and Extent readers (210 and 126 reasons), which have not yet run for the round: those steps' input, not this step's.
- **Rebuild** (Jason's go; restore point `sources-waste-water-and-climate-rebuild`: `provision_changes`, `provision_change_claims`, `lat_events`, `lat_label_timeline`):
  - the 21 in 159 s, 0 failed (`-rebuild.log`);
  - 2 more of the same reasons, missed in the first read of the list (asc 2024/2 law text, asp 2002/3 feed), in 14 s (`-rebuild-2.log`);
  - the 2 Maritime SIs' labels refolded (`LabelRefresh.refold/1`, `:ok`).

  `lat.stale` (`-stale-3.txt`): 0 stale for feed or law text; switched families 0 of 527. The 224 left are stale for the Commencement and Extent readers only.
- **Gate after the rebuild** (`-8.txt`): 4,523 needs, 1 failing: SI 2025/163's Schedules (backlog, for SI 2013/1582), which the rebuilt changes now point to. 0 register differences.
- **Round 6** (Jason's go): 1 fetched, 0 failed. **Round gate PASS** (`-9.txt`): 4,523 needs, 0 failures, 0 register differences. Second NAS data sync after it (`-nas-2.log`).
