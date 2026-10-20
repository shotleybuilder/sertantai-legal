---
session: "AR-09: Territory of a Devolved Amending Law"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
bugs:
  - pattern: 'An amending-law record carries no territory: a devolved instrument''s change (nisr / ssi / wsi, nia / asp / anaw) reads as UK-wide (NI SR 2009/248 repealing Explosives Act 1875 ss.53–76 for NI only)'
    category: amending-law
    module: Amendment.Collect
    affected: '169 rows in 42 laws at most (records whose territory misses the row); 11 rows in 2 of 10 pilot laws'
    fix: 'territorial_application from the amending law''s type (devolved), else its register extent when narrower than the UK; none when the amended law is devolved to the same territory'
    status: fixed
---

# Session: AR-09: Territory of a Devolved Amending Law (ACTIVE)

## Problem

An amending-law record carries no territory: a devolved instrument's change (nisr / ssi / wsi, nia / asp / anaw) reads as UK-wide — NI SR 2009/248 repealing Explosives Act 1875 ss.53–76 for NI only (AR-04 open bug; `Amendment.Collect`). The LabelProjection guard stops its false repeals; the dates still spread.

## Todo

- ✅ Decide (Jason): type, then extent — a devolved law's type; a UK-level law's register extent when narrower than the UK
- ✅ Record it on the amending-law record (`Amendment.Collect.territory/3` → `territorial_application`); the projection reads it as it reads the feed's
- ✅ Count the rows it changes (pilot 11 rows / 10 laws, all right; ≤169 rows in 42 laws corpus-wide); batched into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)

## 1. Decision (Jason, 2026-10-20): type, then extent

Evidence: Welsh amending laws carry register extent E+W (wsi 50, asc 177, anaw 12 records) but apply in Wales — an extent alone would reach English rows. So a devolved law's type sets the territory (the `LiveStatus` map: ssi/asp S; wsi/anaw/asc/mwa W; nisr/nisro/nia/apni/nisi NI). A UK-level law's register extent applies when narrower than the UK (GB → E+W+S; UK / all four / blank → none): an extent is the law's whole reach, too wide at worst, never the wrong territory.

## 2. On the record

`Collect.territory/3` (pure) sets `territorial_application`; `ChangeCollector` passes `law_extent:` (the amending law's `geo_extent`, once per law's collection). Added rule: none when the amended law is devolved to the same territory — a Welsh law's rows extend to E+W, so a Welsh repeal of them is still whole. The 8 records where a UK-level law's extent misses the row (1984 c.22 → 1982 c.16 s.36(5)[S]; 1994 c.39 → 1968 c.73 s.9(1)(c)(i)[E+W+NI]) are extent versions sharing an xml id: the territory now stops them dating the wrong version (LR-32).

## 3. Pilot and count

`ar09_pilot` (10 laws) against `ar09_ctl` (AR-09 stashed, same reader): AR-09 alone changes 11 rows in 2 laws, all right —
- 1875 c.17 (10 rows): NI SR 2006/425 and 2009/248 repeals had started a UK-wide version (changed_by / effective_from 2006-12-01, 2009-08-07); the feed's effects already said N.I. Now the GB version is unstarted; s.103's territory E+W+S (its markup excludes NI).
- 1974 c.40 s.106(4) [E+W+S]: the Roads (Scotland) Act 1984 (extent S) repeal no longer dates it.
- Welsh-on-Welsh (asc 2023/3, anaw 2017/2, wsi 2026/103) and SSI on 1990 c.43 / SI 1996/972: 0 changes.

Other diffs in these laws (1968 c.73, 1974 c.40, 1990 c.43) are AR-08's (in the control too). Corpus bound: 1,296 matched records carry a territory, 194 of them not covering their row — 169 rows in 42 laws. Exact count in the AR measure run.
