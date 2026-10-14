---
session: 'LR-08: The Amending Law as a Source'
status: active
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "Gaps mode asked no rows: a boolean match (`dated? = …`) inside a `for` comprehension acts as a filter and dropped every false — 0 law records in the first all-law dry run"
    category: tooling
    module: ChangeCollector.amending_law/4
    affected: "all gap rows (first dry run: 0 records)"
    fix: "explicit dated?/3 filter compared to the mode; test"
    status: fixed
  - pattern: "A provision's own commencement words ('This section shall come into force on the passing of this Act') ignored when the Act-wide rule excepted it — dated records came out undated"
    category: amending-law-date
    module: AmendingLaw.Commencement
    affected: "e.g. Utilities Act 2000 s.68 (1989/29 s.15A)"
    fix: "read the provision's own commencement words first; test"
    status: fixed
  - pattern: "Benchmark review: an inserted provision's number guessed from the quoted words ('a fee …' read as paragraph (a)) put a law record on the wrong row (1990/43 s.6(2)(a))"
    category: amending-law-target
    module: AmendingLaw.Text / Target
    affected: "found in a 25-record sample"
    fix: "inserted provisions only from the quote's Pnumber tree, matched by full path"
    status: fixed
  - pattern: "Target's nearest-law rule fell through: an instruction naming only another law could match a container title; laws named in quoted old words counted"
    category: amending-law-target
    module: AmendingLaw.Target
    affected: "2 in a 25-record sample (right by luck)"
    fix: "the first text naming any law decides; quoted old words name nothing"
    status: fixed
  - pattern: "A whole Schedule (pointer 'Sch. 26') read as one instruction gave 'inserted' where its repeals table says repealed (1989/29 s.56C(7))"
    category: amending-law-target
    module: ChangeCollector.AmendingLaw / RepealTable
    affected: "found by the benchmark"
    fix: "only a single provision is read as an instruction; whole Schedules only through RepealTable, which now reads the modern 2-column form"
    status: fixed
---

# Session: LR-08 The Amending Law as a Source (ACTIVE)

> **Resumed 2026-10-14** as the change register's amending-law and commencing-law collectors (LR-22 architecture; LR-23 register, LR-24/26 timeline). **Suspended 2026-10-13** (Jason): we were building a change system without designing it as one. Resumes as the amending-law and commencing-law collectors of the change register (LR-22, `lat_change_log`). Hop 1 fetch and the probe stand as evidence.

## Problem

The other half of Jason's 2026-10-09 decision: a change the markup and effects don't carry is "checked against the law it was built from". Parked as "later, not scheduled" (2026-10-09), so notes filled the gap (LR-00 meta, "Why the notes decision was not delivered"). The amending law's own text names the provision it changes, the change and its commencement and extent; that is law, where a note is not. Scope (LR-20, Jason approved D2 2026-10-12): class b — 1,828 notes in 183 laws with no effect whose amending law is in the CLML store — and a law's own commencement provisions (part of class c1). Amending laws not in the store stay empty for v0.1 (#179, compliance v0.2).

## Todo

- ✅ Size, in rows (after LR-19): which note-labelled rows have their amending law in the store
- ✅ Stop rules for fetching amending laws into the CLML store (Jason, 2026-10-13: rules first, so we don't run through the legislation.gov.uk corpus)
- ✅ Fetch hop 1 (the amending laws meeting the rules) into the CLML store: list → Jason → fetch
- ✅ Probe: find the amending provision for a change (amending law + affected provision from the effect or the note's pointer), read its operation (substitute / insert / omit / repeal), commencement and extent from the amending law's CLML
- ✅ Re-measure against the timeline's gaps: rows `undated_change` / `insertion_not_in_register` / `no_start` whose note points to an amending law now in the CLML store (hop 1)
- ✅ Design (Gemini, then Jason): `ChangeCollector.AmendingLaw` — from a pointer (note's citation + provision) read the amending provision; record (source `law`, evidence = provision path) only when its text names the affected law and provision (defined terms resolved); operation from the text; date from the law's own commencement words (LR-24 rules: commencing provision > law's own date)
- ⬜ Hop 2: the commencing SIs (37 at N = 5) → list → Jason → fetch
- ⬜ Tests first; the collector; register dry run (fidelity) → Jason → apply; timeline rebuild → Jason → apply
- Not in scope: applying unapplied amendments to the text (#171), backlog

## Decisions for Jason

- **D5 — approved 2026-10-14** (Jason: "fetch the Schedules for the amending laws that we need, but only into the .xml store. Don't pollute the session trying to get Schedules parsed into LAT"): 274 `/schedules` documents fetched into the CLML store only; LAT untouched
- **D6 — Write the law records to the register** (`mix lat.collect_changes --all --apply`; dry run below); timeline rebuild after hop 2 (the records are mostly undated until then). **Jason: approve**
- **D4 — approved 2026-10-14**: collector design, consensus after Gemini (see "Gemini on the design")
- **D1 — Scope** (see Size; to be re-measured against the timeline gaps): (a) rows whose amending law is in the store, 3,628; (b) the 1,206 rows with no law named, from the law's own commencement; (c) the 7,150 rows whose amending law has a `uk_lrt` record but no CLML file: not downloaded from legislation.gov.uk for v0.1 (#179)
- **D3 — Stop rules**: approved 2026-10-13, R1–R6 with **N = 5** (191 amending laws, 47% of 404; 6,768 of 7,150 rows, 95%)
- **D2 — Dates** (now LR-24's rule: the commencing provision over the amending law's own date over the effect; else empty): the amending law names the change and itself; the date is usually set by a commencement order (a second law). effective_from only when the amending law fixes the date itself or its commencement order is in the store; otherwise empty

## Dependencies

- ✅ LR-20 inventory and rule (D1, D2 approved)
- ✅ LR-22 register design; LR-23 register (139,691 records); LR-24/26/27 timeline (505,244 periods) with gaps listed

## Size (2026-10-13)

Rows labelled from notes (`change_provenance.change = note`) after LR-19: 14,709 rows, 262 laws. By which data repo holds their amending law (the law the note names). Repos: CLML store = `backend/data/cache/clml/<type>/<y>/<n>/body/data.xml.gz` (968 laws' XML); LAT = `legal_articles` (1,066 laws, parsed from the CLML); `uk_lrt` = the legal register table (19,813 laws, metadata only, no text); report `backend/data/reports/lat-refactor/lr08_rows.tsv` (gitignored).

| Class | Rows | Laws | Amending laws | Amending law before 2002 |
|---|---|---|---|---|
| CLML store + LAT; the feed has effects by it on other provisions | 1,944 | 50 | 63 | 1,041 |
| CLML store + LAT; no effect by it on the law | 1,684 | 53 | 56 | 1,635 |
| `uk_lrt` only (37 of the 404 also in LAT, without CLML) | 7,150 | 201 | 404 | 4,838 |
| No repo | 2,725 | 119 | 231 | 2,003 |
| No law named (date only; own commencement?) | 1,206 | 64 | — | — |

The two store classes total 3,628 rows in 82 laws, from 113 amending laws. Most are pre-2002 changes, where the feed records few effects (legislation.gov.uk's effects run from 2002). Example: Town and Country Planning Act 1990: 512 rows labelled from notes as changed by the Planning and Compensation Act 1991; the feed holds only that Act's prospective repeals on 1990/8. The rows' dates (1991-09-25, 1992-01-02, 1992-07-17 …) come from commencement orders, not from the 1991 Act.

## Stop rules (draft, 2026-10-13)

Jason: rules first, then pull the share of the 404 that meets them into the CLML store. The cascade to stop: a fetched law names further laws (its own amenders, its commencing orders, laws it cites), and each could name more.

- **R0 Top of the cascade** (Jason, 2026-10-13: "not all LRT laws equally need enrichment"). Demand comes only from LAT rows of laws that are in force in some way (`uk_lrt.live` ✔ In force or ⭕ Part Revocation / Repeal) and have an EHS&HR family (`uk_lrt.family` set).
- **R1 Demand only.** A law is fetched only because a LAT row (`legal_articles`) is labelled from a note naming it and no effect covers the row. Nothing else triggers a fetch.
- **R2 Fetched laws make no demand.** A law fetched as a source is stored as source only: no LAT rows, no `uk_lrt` change, not added to `clml.fetch`'s LAT list. Its notes, feed and citations are never read for further fetches.
- **R3 Two hops at most.** Hop 1: the amending law. Hop 2: the commencing SI the row's note names (the "; S.I. YYYY/N" after the amending citation), and only when hop 1 doesn't date the change itself. No hop 3.
- **R4 Threshold.** An amending law qualifies when it labels at least N LAT rows.
- **R5 Caps.** A fixed list per hop, written before anything is fetched; the run fetches that list and stops. Hop 2's list is drawn up after hop 1 has been read.
- **R6 Text types only.** Types with CLML text (ukpga, uksi, asp, ssi, wsi, nia, nisr, nisi, eur, eudr); not ukcm, eudn.

Measured on the 7,150 rows / 404 amending laws held only in `uk_lrt`:

| N (rows per amending law) | Amending laws | Share of 404 | Rows covered | Share of 7,150 |
|---|---|---|---|---|
| 1 | 404 | 100% | 7,150 | 100% |
| 5 | 191 | 47% | 6,768 | 95% |
| 10 | 127 | 31% | 6,349 | 89% |
| 20 | 78 | 19% | 5,712 | 80% |
| 50 | 28 | 7% | 4,118 | 58% |

Hop 2 (from note pointers, a ceiling): 1,967 rows name a commencing SI after the amending citation; 97 distinct SIs, 65 in `uk_lrt`, none in the CLML store. 1,384 rows' notes carry a date but no SI (dated by the amending law itself, or by an order the note doesn't name). Notes name the amending provision (s. / reg. / Sch. …) for 4,158 of the 4,700 rows with a placed note: the pointer to the provision to read.

## Hop 1 list (2026-10-13)

`backend/data/reports/lat-refactor/lr08_hop1.tsv` (gitignored): 191 amending laws at N = 5; R6 drops UK_eudn_2018_853 (5 rows), leaving **190 laws, 6,763 rows**. 21 of them are LAT laws without a CLML file (a normal LAT store fill). Largest: Utilities Act 2000 (1,086 rows), Forestry and Land Management (Scotland) Act 2018 (322), Transport Act 2000 (285), Directive (EU) 2018/851 (208), Employment Rights (Dispute Resolution) Act 1998 (194).

R2 holds without a code change: nothing enumerates the CLML store to choose LAT laws (`clml.fetch`'s default list is the laws in `legal_articles`; `lat.qa_sample` reads the store only for laws it samples), so a stored body creates no LAT rows. Fetch with `mix clml.fetch --laws <list>`: body only for a law with no `LatScope`; resumable, one request per document.

R0 applied (2026-10-13): of the 7,150 rows, 568 (28 laws) have no family and 6 (3 laws) aren't in force; demand 6,576 rows in 170 laws naming 379 amending laws. At N = 5 with R6: **hop 1 = 173 laws, 6,203 rows** (`lr08_hop1_r0.tsv`), all within the approved 190. Fetch started: `mix clml.fetch --laws <173>`.

## Hop 1 fetch (2026-10-13)

- **151 of 173 bodies stored** (CLML store 968 → 1,118 body files).
- **1 unavailable:** Merchant Shipping (Registration, etc.) Act 1993 (ukpga 1993/22, repealed 1996). legislation.gov.uk serves no body for it.
- **21 are LAT laws with a `LatScope`** (fragments only), so `clml.fetch` fetched only their LAT fragments. Their amending provisions came instead from the notes' pointers (s. / Sch. after the amending citation): 109 named fragments, 3 already held, 104 fetched (`section/N`, `schedule/N`). 2 returned 404: ukpga 1960/34 Sch. 1 and ukpga 1994/22 Sch. 7, probably pointer misreads. Their bodies were not fetched, so `LatScope` fragment reads and `lat.qa_sample` are unchanged.

## Probe (2026-10-13)

Hop 1 rows: 6,203, of which 4,200 carry a placed note (4,343 notes); the rest are labelled through an ancestor. Scripts: scratchpad `lr08_verify.py` and the commencement classifier. Both are crude regex first cuts, used for sizing only.

**Example: Utilities Act 2000 (1,086 rows: Gas Act 1986 562, Electricity Act 1989 523).**
- s. 60: "The 1989 Act is amended as follows. (2) In subsection (1) of section 25 … for "and (5)" there is substituted …; (4) … paragraphs (b) and (c) shall cease to have effect; (5) After subsection (5) … there is inserted …".
- The law text gives the target (through a defined term and "that section") and the operation.
- It gives no date: s. 110(2) "such day as the Secretary of State may by order … appoint". The dates are in S.I. 2000/3343, 2001/1781 and 2001/3266.
- Extent: s. 110(4) "Any amendment or repeal made by this Act has the same extent as the enactment being amended".
- The only dates inside the Act's CLML are its own notes ("S. 60 in force at 1.10.2001 by S.I. 2001/3266"). These are notes on another law and are not a source.

**Row → amending provision.** The link is the note's pointer (amending law + provision), which the rule allows: a pointer, not a fact.
- The crude parse resolved 2,061 of 4,343 notes to a provision in the CLML.
- 1,682 didn't parse. Causes: "(c. 38, SIF 43:1)", "ss 156", lowercase "sch.", and EU amending acts whose notes name no article. These are parser gaps, fixable.
- 608 parsed but the provision wasn't found: schedule part/paragraph ids, and fragments.

**Verifying the provision is about the row.**
- Of the 2,061 found, the text names the target law by title or year in 1,329 and the target provision number in 648.
- The misses are mostly defined terms ("the 1989 Act", "the Energy Order", "the principal Act"), Schedule cross-headings naming the law once, and anaphora ("that section"). Those need resolving.

**Operation from the law text.** "there is substituted", "is inserted", "shall cease to have effect", "is repealed" give the effect kind directly.

**Dates (hop 1 laws, the law's own commencement words, notes stripped):**

| How the amending law commences | Laws | Rows |
|---|---|---|
| Fixed or relative date in the law ("come into force on 10th August 2000", "day after Royal Assent") | 82 | 1,661 |
| Mixed: some provisions fixed or at assent, the rest by order | 23 | 2,056 |
| By order only (hop 2) | 22 | 1,021 |
| No body (scoped LAT laws, fragments only; 1 unavailable) | 22 | 848 |
| Unclassified ("exit day", lists, no words found) | 24 | 617 |

Some "amending laws" are commencement orders (uksi 2001/114, ssi 2002/118, ssi 2013/51: "1st April 2013 is the day appointed …"). The row's fact is a commencement, and the order's own text dates it.

**Hop 2 size.** 67 amending laws need an order (by order, mixed, or no body). Their rows' notes name 65 distinct commencing SIs (2,205 rows with a placed note); 1 is in the CLML store. At N = 5: 37 SIs, 2,529 notes.

## Re-measure against the timeline's gaps (2026-10-14)

Gaps from `lr27_rebuild.gaps.csv`. For each gap row: does an amendment note on it (a pointer) name a law, and is that law in the CLML store (1,219 laws: the LAT laws plus hop 1)?

| Gap | Rows | Note names a law | Law in the store | Law not in the store |
|---|---|---|---|---|
| undated_change | 19,031 | 18,426 | **14,587** | 7,051 |
| insertion_not_in_register | 8,134 | 4,549 | **3,416** | 1,275 |
| no_start | 22,113 | 883 | 64 | 819 |

A row can carry notes naming several laws, so the columns overlap. **About 18,000 gap rows have an amending law in the store to read.** That's the collector's scope; whether each yields a fact depends on finding the amending provision, verifying that it names the row, and dating it. no_start is mostly not this source (a law's own commencement and metadata).

## Design (draft, 2026-10-14)

**Goal.** Give the timeline's gap rows facts from the law itself: a change record (source `law`) in `lat_change_log` for a row, read from the amending provision a note points to, and only when the amending text names the row's law and provision. The note is a pointer, never a fact.

**Scope (v1).** Gap-driven: `(row, amending law)` pairs where the register holds no dated change on the row by that law (`undated_change`, `insertion_not_in_register`) and the amending law is in the CLML store. Reads the store only; never fetches (hop 2 is a separate, approved fetch). Effects stay authoritative where they exist, so v1 creates no law-vs-effect conflicts. Widening it to cross-check effects is a later decision.

### Modules: pure pieces, one IO edge, none over ~200 lines

| Module | Pure? | Responsibility | In → out |
|---|---|---|---|
| `AmendingLaw.Pointer` | pure | Parse a note's pointer only: the amending law (its `citation_law`), the amending provision refs after the citation ("s. 60(5)", "Sch. 6 Pt. II para. 33(c)"), and any commencing instrument after ";" ("S.I. 2001/3266, art. 2"). Never dates, never operations. | note → `%Pointer{}` |
| `AmendingLaw.Locator` | pure | Provision ref → element ids in the amending law's CLML ("s. 60(5)" → `section-60-5`; "Sch. 6 Pt. II para. 33" → `schedule-6-part-II-paragraph-33`, falling back up the hierarchy to the nearest held id). | ref + doc ids → ids |
| `AmendingLaw.Text` | pure | An element's law text: Commentary and notes stripped, BlockAmendment content kept and marked as quoted (inserted words, not instructions). | element → `%Text{instruction, quoted}` |
| `AmendingLaw.DefinedTerms` | pure | The amending law's defined terms for laws ("“the 1989 Act” means the Electricity Act 1989", "the principal Act"), and the heading a Schedule paragraph sits under ("The Electricity Act 1989"). | doc → `%{term => law_name}` |
| `AmendingLaw.Target` | pure | Does the instruction name the row's law (title, year and chapter, or a defined term) and provision ("section 25", "subsection (5) of that section" resolved within the same provision)? | `%Text{}`, terms, row → `{:ok, refs}` / `:no_match` |
| `AmendingLaw.Operation` | pure | The operation from the drafting verbs: "there is substituted" / "for … substitute" → substituted; "is inserted" / "insert" → inserted; "shall cease to have effect" / "omit" / "is repealed" → repealed; else amended. | `%Text{}` → operation |
| `AmendingLaw.Commencement` | pure | The amending law's own commencement for a provision: a fixed date, relative to Royal Assent (`ukm:EnactmentDate`) or making, "on such day as … appoint" (by order), with exceptions ("apart from this section and section 68"). | doc, provision → `{:date, d}` / `:by_order` / `:unknown` |
| `ChangeCollector.AmendingLaw` | pure | Orchestrates the above for a law's gap rows into `%Record{source: "law", evidence: "ukpga/2000/27/section/60", affecting_law, affecting_ref, operation, effective_from, dated_by_law, dated_by_ref, pointer: note code, via: ["law_pointer"]}`; a record only on a `Target` match; `effective_from` only from `Commencement` (or hop 2 later). | rows, notes, gaps, `docs_fun` → records |
| `ChangeCollector` (existing) | IO | Adds the `amending_law` collector: loads gaps and notes, injects `docs_fun` (a memoised store read per amending law), writes with the others (one transaction, fidelity gate). | — |

**Structs.** `%Pointer{}` (affecting_law, provisions, commencing, note_code) and `%Text{}` (instruction, quoted) with `@enforce_keys`. `Record` is reused.

**Dates (LR-24 rule):** the commencing provision (hop 2) over the amending law's own date; `:by_order` with no order held leaves `effective_from` empty, and the row stays an undated change (truth). `dated_by_law` / `dated_by_ref` say which law dated it.

**Projection.** No change: `LabelProjection` treats a `law` record like any dated change (text operations version the row; repeals set status), so a matched, dated record removes the row's gap. A matched but undated record keeps the "date unknown" signal and adds the evidence.

**Verification.**
- **Tests first,** per module, with trimmed fixtures from the stored CLML: Utilities Act 2000 s. 60 on Electricity Act 1989 s. 25; Sch. 6 Pt. II para. 33 under its "The Electricity Act 1989" heading; a modern "omit … insert" instruction. `key-` ids scrubbed.
- **Register dry run** with the fidelity gate.
- **Precision sample:** for N matched records, compare to the note's own date and law, as a **QA signal only** (the note is never the value), and list disagreements.
- **Timeline dry run** → Jason → apply.

**Out of scope.** Hop 2 (commencing SIs: a list → Jason → fetch, then a `CommencingOrder` reader); laws not in the store (#179); text application (#171).

## Gemini on the design (2026-10-14)

`backend/data/code-reviews/2026-10-14-lr-08-amending-law-collector-design.md`. **VERDICT: ACCEPT WITH CHANGES.** The decomposition, the one IO edge and the strict Target rule are agreed.

Taken:
- **Structs for the inputs.**
  - `AmendingLaw.Doc`: a parsed amending law, with ids, metadata (enactment date, type), defined terms and the heading per Schedule paragraph, built once per law.
  - `AmendingLaw.RowRef`: the row's law, title, short title and provision path, parsed from `section_id`.

  No raw XML or ad-hoc maps cross the module boundaries.
- **Truth handling per case:**
  - **No match:**
    - a note pointing to the wrong provision (the text must confirm independently);
    - anaphora reaching beyond the same amending provision, or ambiguous;
    - savings and transitional provisions;
    - an ambiguous defined term ("the principal Act" with more than one candidate).
  - **Handled:**
    - "that section" and "the said Act" within the same provision;
    - a Schedule paragraph under a heading naming the law;
    - a provision amending several laws (each matched on its own);
    - partial amendments ("in subsection (2)(a)": the change is recorded on the row it names; a words change is `amended`);
    - commencement exceptions;
    - commencement by order or for some purposes (`effective_from` empty).
- **Repeal tables in v1** (`AmendingLaw.RepealTable`): pre-2002 repeals are mostly Schedules of repeals (Chapter / Short title / Extent of repeal; "1993 c. 43, … Sch. 14"). A table reader, not the text Target, matches a row only when the Chapter or Short title names the row's law and the "Extent of repeal" names its provision.
- **Precision first:** zero wrong facts in the reviewed sample before any write. Recall is secondary.

Added (consensus):
- **A benchmark against effects.** Run the collector on (row, law) pairs where the feed already holds a dated effect, and compare operation and date. It's an automatic precision and recall measure on thousands of cases, without trusting notes. Then a manual sample of 50 gap records, read against the amending text. Acceptance: no wrong operation or date in either; recall reported.
- **The fidelity gate is the existing one** (compact = per-row) plus that benchmark. The note stays a QA hint only.

Not taken: a separate drafting-verb registry module (the verbs stay in `Operation` until they outgrow it).

**Modules (v1):**
- `Pointer`, `Doc`, `RowRef`, `Locator`, `Text`, `DefinedTerms`, `Target`, `RepealTable`, `Operation`, `Commencement` (all pure, each small);
- `ChangeCollector.AmendingLaw` (pure orchestration);
- the IO stays in `ChangeCollector`.

## Schedules aren't in the store (2026-10-14)

Building the fixtures showed the stored amending laws hold **no Schedules**. `clml.fetch` stores each law's `/body/data.xml`, and legislation.gov.uk serves Schedules as a separate document (`/schedules/data.xml`). LAT laws' Schedules aren't stored either (LR-10 took Schedules out of LAT).

Of the 18,003 gap rows whose note points to an amending law in the store:
- **10,370 (58%) point into a Schedule**, e.g. "2000 c. 27, s. 108, Sch. 6 Pt. II para. 33(c)", or a "Sch. 14" table of repeals. They come from 274 amending laws;
- 8,723 point into the body.

Without the Schedules the collector can serve about 8,700 rows; consequential amendments and repeal tables, the main pre-2002 forms, need the Schedules (D5).

## Build (2026-10-14)

**Schedules fetched** (D5): 274 `/schedules` documents into the CLML store only; 272 stored, 2 are 404 (nisr 2012/187, uksi 1995/1983 have no Schedules). LAT and `LatScope` untouched.

**Modules** (`lib/sertantai_legal/scraper/amending_law/`, each small, pure):
- `Pointer`: a note's pointer only;
- `Doc`: a parsed law with ids, positions, container titles and enactment date, plus text in document order;
- `RowRef`, `Locator`;
- `Text`: instruction, quoted words, the inserted provisions' Pnumber paths, context;
- `DefinedTerms`: Citation URI first;
- `Operation`;
- `Commencement`: read once per law;
- `Target`: the strict rule;
- `RepealTable`: the 3-column and 2-column forms.

`ChangeCollector.AmendingLaw` (pure) is wired into `ChangeCollector.collect/2` as collector `amending_law`. Rows asked: gaps mode, where a note names a law with no dated feed change on the row or an ancestor. The IO edge reads notes, titles and the stored CLML (body, Schedules, fragments), each law parsed once per process. `mix lat.amending_law_benchmark` is read-only. Tests: 45 for the module family; suite 2,708.

**Benchmark against the feed** (rows where the feed already dates a change by the law; compared on the row's family). Ten laws (1989/29, 1986/44, 1974/37, 1990/43, 1991/56, 1996/18, 1990/8, 1974/40, 1968/73, uksi 1999/3242): **4,605 law records**:

| Verdict | Records |
|---|---|
| agree on the operation | 4,233 |
| of which also dated by the law's own words, and every date agrees | 108 |
| date disagrees | 0 |
| operation differs | 252 |
| no feed change on the family | 120 |

**Manual review** (two samples of 25, weighted to "differs" and "no feed change", read against the amending text):
- **First sample:** 23 right. Two faults: an inserted number guessed from quoted words; the nearest-law rule falling through (bugs above). Fixed with tests.
- **Second sample:** 25 right on reading. "Operation differs" is the feed recording only a modification or generic "amended" on those rows; the substitution or insertion is in the law. One structural weakness fixed (inserted provisions matched by full path, not by numbers found anywhere in the quote).
- **Dates:** the law's own words date few changes (Acts mostly commence by order), so most records are undated until hop 2.

## Register dry run with the collector (2026-10-14)

The first all-law dry run gave **0 law records**, which exposed two faults (bugs above): the gap rows were filtered out by a boolean match in a `for`, and a provision's own commencement words were ignored. Both fixed with tests (suite 2,709). The ten-law benchmark after the fixes was unchanged: 0 date disagreements.

**Gap records' dates against their notes** (QA hint only; the note is never the value), ten laws: 2,671 law records. 27 are dated by the law's own words: 26 match the note's date, 1 note has none, **0 differ**. 2,644 are undated (by order: hop 2).

**All-law dry run** (`lr08_collect_dry`): 1,066 laws, 0 errors, **0 fidelity failures**.
- **4,681 law records** (per row) in **105 laws**. Largest: Gas Act 1986 785, 1990/43 752, Electricity Act 1989 646, 1988/52 462, 1981/69 320.
- **Stored:** 141,390 (+1,699 compact).

About 18,000 gap rows had an amending law in the store. 4,681 get a law record under the strict rule (the text must name both the law and the provision). The rest have no match: a pointer to a provision whose text doesn't name the row, a heading or Schedule form not read, or a law not in the store's documents.
