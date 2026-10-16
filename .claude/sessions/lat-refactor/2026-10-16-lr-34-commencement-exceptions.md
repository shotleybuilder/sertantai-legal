---
session: 'LR-34: Commencement Exceptions'
status: closed
opened: '2026-10-16'
closed: '2026-10-16'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'A law''s commencement clause now starts its provisions, not just the law: LawStart.Provisions assigns rows to provision_dated, provision_by_order (J6: in force as at the text, since unknown),
  provision_qualified and provision_unread, written as per-row commencement records. Applied by relabel 2026-10-16: unknown today 19,736 → 18,340; 9,496 label changes in 67 laws, all live, none to unknown.'
decisions:
- what: 'D1 (b): provisions left to commencement orders with no dated commencement of their own are in force as at the revised text, since unknown (J6, gap commenced_by_order)'
  why: 'Jason 2026-10-16 ''Your recommendations'': 27,741 rows in 29 Acts read ''in force since Royal Assent'', which the law doesn''t say; making them unknown would lose 25K rows the text shows in force'
  result: 18,735 rows carry commenced_by_order; 2,165 in-force dates emptied; laws commenced wholly by order gain an in-force status
- what: 'D2: qualified commencements (''so far as …'', ''in relation to Wales'') are listed, no effect'
  why: they commence a provision for some purposes or places only
  result: provision_qualified on 4,230 rows in 28 laws
- what: A clause date after the law's start is the row's commencement, not its start
  why: 'dry run 2: uksi 2026/109 reg.2(2) (23 Mar 2027) and asc 2025/4 showed nothing today instead of prospective'
  result: rows exist from the law's start, prospective until their date (D3)
- what: J6 only where nothing else says when the row commenced
  why: 'dry run 1: asp 2026/6 s.10 has a dated (future) commencement order; J6 wiped its prospective status (229 rows)'
  result: own dated commencement → D3; marked prospective → J2; else J6
metrics:
  relabel_2026_10_16:
    laws: 1066
    failed: 0
    stale_after: 0
    predicted_changes_live: 9496
    mismatches: 0
    unknown_today_before: 19736
    unknown_today_after: 18340
    no_start_after: 7731
    commenced_by_order: 18735
  provisions:
    provision_dated:
      laws: 79
      rows: 14185
    provision_by_order:
      laws: 55
      rows: 30821
    provision_qualified:
      laws: 28
      rows: 4230
    provision_unread:
      laws: 35
  dry_runs: 3
lessons:
- title: A resume file outlives the wave it was written for
  detail: mix lat.relabel --stale skipped all 1,066 stale laws because relabel.done from LR-33's apply listed them; it printed '0 failed' and looked like success. Only the post-apply verify (0 of 9,496
    predicted changes live) caught it. Resume files are now keyed by the code version.
  tag: tooling
- title: Removing a start is not the same as not knowing a start
  detail: Twice a rule that dropped the law's start for some rows also dropped their known prospective history (future commencement orders, future clause dates). A provision that exists but isn't in force
    is prospective, not unknown.
  tag: data
- title: Inspect the biggest gainers as well as the losers
  detail: wsi 2026/103 gaining 630 'in force' rows looked like good news; reading its clause showed 'Chapter 1 of Part 6' read as all of Part 6 and an item-level 'except' ignored.
  tag: data
bugs:
- pattern: 'A made law whose general commencement date is in the future has no period today for its undated provisions (unknown), where prospective is the truth (wsi 2026/103: 531 rows until 1 Oct 2027)'
  category: timeline gap
  module: LabelProjection J1
  affected: 531
  fix: 'a law made but not yet in force: its rows prospective from the made date until the law''s start (its own A8 session)'
  status: open
- pattern: Provisions of Acts commenced in stages read 'in force since' the earliest stated date, though the law leaves them to commencement orders
  category: overstated label
  module: LawStart / LabelProjection J1
  affected: 27741
  fix: LawStart.Provisions + J6
  status: fixed
- pattern: Provisions a clause dates apart from the general date took the law's general date
  category: wrong date
  module: LawStart
  affected: 14185
  fix: provision_dated records; row start or own commencement
  status: fixed
- pattern: mix lat.relabel --stale resumed from a previous wave's done file and skipped every stale law
  category: tooling
  module: Mix.Tasks.Lat.Relabel
  affected: 1066
  fix: done file keyed by LabelVersion
  status: fixed
artifacts:
- backend/lib/sertantai_legal/scraper/law_start/provisions.ex
- backend/lib/sertantai_legal/scraper/change_collector/commencement.ex
- backend/lib/sertantai_legal/scraper/label_projection.ex
- backend/lib/sertantai_legal/scraper/label_timeline.ex
- backend/lib/mix/tasks/lat.relabel.ex
- backend/lib/mix/tasks/lat.law_start.ex
- backend/test/sertantai_legal/scraper/law_start_provisions_test.exs
- backend/data/reports/lat-refactor/lr34_dry3.csv
depends_on:
- 2026-10-15-lr-33-no-start-date
enables:
- 'A8: law made but not yet in force (prospective, not unknown)'
- A8 next gap class
---

# Session: LR-34 Commencement Exceptions (CLOSED)

## Problem

LR-33 gives each law one start (`LawStart`: the general date its commencement clause states). Many clauses carry dated exceptions for particular provisions: "Subject to paragraph (3), this Order comes into force on [date]; Articles 45(4)(d) and (5)(a) and 48 come into force on the first day of the second month following …" (uksi 2015/1947), "Regulation 12 shall come into operation on 31st May 2015" (nisr 2015/236). Those provisions take the law's general date today. P1 (Jason 2026-10-16) put the exceptions on their provisions.

## Todo

- ✅ Measure: clauses with dated exceptions across the corpus, and the provisions they name
- ✅ Jason 2026-10-16: D1 (b) and D2 known limit ("Your recommendations")
- ✅ Resolve the named provisions to rows (the `ProvisionText` / `EffectTarget` grammar, "Articles 45(4)(d) and 48", "Part II", "regulation 26, with the exception of paragraph (4)")
- ✅ Write them as provision-level `commencement` records (a `LawStart` treatment each), J1 starting the row at its own commencement
- ✅ Dry run (`lr34_dry3`) → Jason ("Go with the apply") → NAS backup → `mix lat.relabel --stale` (second run, after the resume-file fix) → verify: 0 failed, 0 stale, 9,496/9,496 predicted changes live, 18,340 unknown today

## Dependencies

- ✅ LR-33 law start applied (2026-10-16)

## Measure (2026-10-16)

The commencement provision LR-33 found for each law (its evidence row and that provision's other rows), every sentence that commences something narrower than the whole law. 104 laws, 287 sentences, classified roughly (by the subject before "come into force" and the tail after it):

| Subject | Tail | Sentences | Laws |
|---|---|---|---|
| named provisions ("Regulation 12", "Articles 45(4)(d) and 48", "This section and sections 62, 63 and 65") | dated | 77 | 57 |
| | by order | 19 | 16 |
| | a list follows / other | 39 | 30 |
| qualified: "so far as it relates to …", "in relation to Wales", "for the purposes of making regulations", "to the extent necessary …" | any | 95 | 46 |
| "the remaining / other provisions of this Act" | by order | 27 | 27 |
| | dated | 9 | 9 |
| other subjects ("The following provisions —", "This Part") | any | 55 | ~40 |

### Finding: "the remaining provisions … by order" overstates 27 laws today

In 29 laws (27,741 rows), mostly large Acts staged by commencement order, the clause dates a few named provisions ("This section and sections 3 to 6 come into force on Royal Assent") and leaves the rest to orders ("The provisions of this Act, except …, come into force on such day as the Scottish Ministers may by order appoint"). Examples: EPA 1990 (4,777 rows), Equality Act 2010 (3,362), asc 2023/3 (2,698), WCA 1981 (2,678). LR-33 made the earliest stated date the law's start (`clause_staged`), and J1 applies that start to every row, so the by-order rows read "in force since Royal Assent", which isn't what the law says. Only 1,981 of the rows have a dated commencement effect of their own in the register. Their revised text (J2 input) shows 25,331 in force, 2,006 prospective, 404 repealed.

## Decisions for Jason

- **D1. Rows the law leaves to commencement orders** (no dated commencement of their own). Options:
  - (a) Unknown: no law start; their own commencement effect, else no period (~25K rows in force today become unknown).
  - (b) **In force as at the revised text, since unknown** (recommended): the revised text (markup, J2) shows them not prospective, so they are in force at the text's version date (`dct:valid`); one period from that date, status in_force, `in_force_from` empty (the same "date unknown" reading as T1). Before that date: unknown. Prospective rows stay prospective. A dated commencement effect, where held, starts the row as now.
  - (c) Keep the earliest part's date (today's labels; overstated).
- **D2. Qualified commencements** ("so far as it relates to …", "in relation to Wales", "for the purposes of …"): commence a provision for some purposes or places only. Recommend: a known limit (no row start from them; the provision keeps its other start), listed by treatment.
- Named, unqualified exceptions with a date (77 sentences / 57 laws) start their provisions at that date (P1, already agreed); "by order" ones follow D1.

## Design (2026-10-16)

- **`LawStart.Provisions`** (pure): reads the law's commencement provision (the one `LawStart` found) sentence by sentence and assigns rows. Its treatments go in `LawStart.provision_catalogue/0`, beside the law catalogue:
  - `provision_dated`: named provisions of this law commence on a date the clause states → the row's start (in place of the law's)
  - `provision_by_order`: named or "remaining / other" provisions left to orders, and every row of a law commenced wholly by order (D1 b) → no law start; their own dated commencement effect if held, else in force as at the revised text unless it marks them prospective, `in_force_from` empty, gap `commenced_by_order`
  - `provision_qualified`: "so far as …", "in relation to Wales", "for the purposes of …" (D2) → listed on its rows, no effect
  - `provision_unread`: a sentence whose provisions or date the reader can't resolve → listed (law-level), no effect
- A row named by several sentences takes the most specific reference; "remaining" applies to rows no sentence names, never to the commencement provision itself.
- References: "this section", "regulations 17 to 21", "Articles 45(4)(d) and (5)(a) and 48", "Part II", "paragraph (4)"; "except …" / "other than …" subtracted; the law's own provision prefix (domestic SIs: reg.). Schedules aren't in LAT.
- Register: per-row `commencement` records (`effect_type` the provision treatment). `LabelTimeline` keeps them out of the changes and turns them into per-row starts; the text date is the latest parse's `source_valid_date`, else its parse date.

## Build (2026-10-16)

- `LawStart.Provisions` (pure, 13 tests) and `LawStart.provision_catalogue/0`; `ChangeCollector.Commencement` writes a record per row a sentence names (unread: one law-level record); `law_start_input` carries each row's `part`.
- `LabelTimeline`: commencement records never enter the changes; `row_starts/1` turns `provision_dated` into the row's `law_start` and `provision_by_order` into `by_order`; `text_date/1` (latest parse's `source_valid_date`, else its parse date).
- `LabelProjection` J6 (4 tests): a by-order row with no dated start of its own is in force as at the text, `in_force_from` empty, gap `commenced_by_order`; a dated row takes its own date in place of the law's.
- Lists read item by item, inline after "namely—" or a colon, qualified items apart (EPA 1990 s.164(2): 708 rows dated 1 Jan 1991, 4 qualified, 4,062 by order).
- Forms added from the unread list: "This Part", "The preceding provisions", "Otherwise …", "on the passing of this Act", "the day after …" (no "on"), "all regulations other than …", by-order wordings ("in accordance with provision made by … order", "appoints", "specified by order").
- Guard: another law's provisions ("Section 3 of the 2022 Act", a commencement order) are never this law's rows.
- The law-level reader shifts for 6 laws: Water Act 2003 now starts at Royal Assent (s.120(5) "on the passing of this Act"; was two months later); uksi 2021/745 a day after made (was 1 Jul); 4 same-date treatment renames.
- Fresh counts over all laws: provision_dated 15,058 rows / 80 laws; provision_by_order 30,374 / 55; provision_qualified 6,243 / 30; provision_unread 35 laws.
- Full suite: 2,726 pass.

## Dry run 1 (`lr34_dry`): two faults, fixed

- **Fidelity failed for 6 laws** (EPA 1990, ukpga 2013/32, 2021/30, uksi 1988/819, wsi 2026/103, ukpga 1984/55): a row named twice by one sentence (a repeated section_id across versions, or an overlapping list item) gave two records with the same register key. Fixed: one record per row per sentence.
- **J6 too wide**: asp 2026/6 s.10 has a dated commencement of its own (SSI 2026/275, 26 Oct 2026, future); with no law start it showed nothing before then, where it had read prospective since the law's start (229 rows prospective → unknown). J6 now applies only where nothing else says when the row commenced: a row with a dated commencement of its own keeps the law's start and is prospective until then (D3); a row the text marks prospective is prospective from the law's start (J2). J6 starts at the row's insertion if dated, else the text date — never at its earliest amendment.

## Dry run 2 (`lr34_dry2`): one more fault, fixed

0 errors, 0 fidelity failures; unknown today 19,736 → 18,256. A dated provision whose date is after the law's start lost its existence before that date: uksi 2026/109 reg.2(2) ("comes into force on 23rd March 2027") showed nothing today instead of prospective; asc 2025/4 ss.1, 2, 5 likewise. Fixed: a clause date after the law's start is the row's own commencement (the row exists from the law's start, prospective until then; D3), not its start; a date before the law's general date (nisr 1997/455 reg.14) still starts the row. Spot-check: uksi 2026/109 reg.2(2) in_force (today's overstatement) → prospective.

Moves confirmed against known commencements: Fire Safety Order 2005 main provisions → 1 Oct 2006; Energy Act 2013, Countryside and Rights of Way Act 2000, Climate Change Act 2008 parts → two months after passing, as their clauses say.

## Dry run 3 (`lr34_dry3`), with one more reader fix

wsi 2026/103 showed 630 rows in force from the day after made where its list says less: "Chapter 1 of Part 6" was read as all of Part 6, "Part 7 …, except regulation 73" didn't subtract within the item, and a Part could out-rank a regulation another sentence names. Fixed (rows carry `chapter`; each list item's own except; a Part's or Chapter's rows weigh 0 against a named provision); 6 laws' assignments changed and were re-previewed into the same report.

**Result (all 1,066 laws, rolled back): 0 errors, 0 fidelity failures.**

| | Before | After |
|---|---|---|
| Provisions unknown today | 19,736 | 18,340 |
| `no_start` | 8,589 | 7,731 |
| `commenced_by_order` (new: in force as at the text, since unknown) | — | 18,735 |

Label changes 9,496 in 67 laws (`lr34_dry3.classes.csv`): effective_from moved 4,005 (later 3660, earlier 345: provisions dated after the law's start, e.g. Fire Safety Order 2005 → 1 Oct 2006; earlier: Part 1s commenced before the general date, e.g. ssi 2004/428, uksi 2015/966), emptied 2,165 (D1 b: left to orders, date unknown), gained 698; status unknown→in_force 1,347 (laws commenced wholly by order, D1 b; wsi 2026/103's early provisions), unknown→prospective 46, in_force→prospective 1 (uksi 2026/109 reg.2(2), 2027). Nothing moves to unknown.

Open (logged, its own A8 session): a law made but not yet in force leaves its undated rows unknown rather than prospective (wsi 2026/103: 531 rows until 1 Oct 2027).

## Apply (2026-10-16, Jason: "Go with the apply")

NAS backup (archive + DB). The first `mix lat.relabel --stale` relabelled nothing: "0 laws (1066 done)". Its default resume file `relabel.done` still listed every law from LR-33's apply, so a new label version's stale laws were all skipped, and "done; 0 failed" read as success. Caught by the verify (0 of 9,496 predicted changes live, 1,066 still stale). Fixed in the task: the default resume file is `relabel_<LabelVersion>.done`, so a resume only skips laws relabelled by the same code. Re-run started.

Re-run: 1,066 laws, 0 failed. Verify: 0 stale; 9,496 of 9,496 predicted changes live; 18,340 provisions unknown today, as predicted.
