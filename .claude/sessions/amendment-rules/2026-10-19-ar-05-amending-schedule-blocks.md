---
session: "AR-05: Blocks from the Amending Law's Own Schedule"
status: closed
opened: '2026-10-19'
closed: '2026-10-20'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md
summary: >
  The reader now reads "The provisions set out in [Part N of] Schedule M shall be substituted for / inserted after …"
  as the provisions that Schedule quotes (bf752873): EReA 1999 s.7 and s.8 reach ERA 1996 ss.71–80 and 57A–57B
  (169 records). The trace found three neighbouring causes, split into AR-11 (feed range), AR-12 (commencement
  order Schedule; with it the ERA pilot moves unknown 477 → 319) and AR-13 (repeals-table cells).
decisions:
  - what: The block's targets are what the amending law's Schedule (or its Part) quotes, gathered from the elements under it
    why: the AR-00 schema expands a block to what it quotes; "inserted after section 57" has no other way to name ss.57A–57B
    result: 'EReA s.7 → ss.71–80 substituted, s.8 → ss.57A–57B inserted (provision level)'
  - what: '"is amended as set out in Schedule 1" stays a pointer, not a block'
    why: that Schedule holds instructions with their own quotes; reading it as one block would reach every quoted provision
    result: guard test
  - what: Feed range, commencement order Schedule and repeals-table cells each their own pending AR session (AR-11, AR-12, AR-13)
    why: 'Jason 2026-10-20: "open them as pending AR sessions"; one session per bug'
    result: AR-12 done next (it dates the AR-05 records)
  - what: Close with the re-pilot deferred to the AR measure run
    why: 'Jason 2026-10-20: one active session at a time (meta excepted); the fix is done and piloted with AR-12'
    result: closed
metrics:
  instances: { amending_laws_stored_scanned: 2733, instructions: 9, amending_laws: 6, in_register: 1, era_rows: 180 }
  collector_era_1996: { erea_records: 285, section_7: 150, section_8: 32 }
  pilot_ar05_only: { label_diffs: 0, reason: records undated until AR-12 }
  pilot_with_ar12: { unknown: '477 → 319', undated_change: '965 → 881', rows_dated_by_erea_1999_12_15: 180 }
lessons:
  - title: A reach fix can show nothing until its dating lands
    detail: 'AR-05 alone gave 0 label changes on ERA: every record was undated because the commencement order was misread (AR-12). Check the records'' effective_from before reading a 0-diff pilot as "no effect".'
    tag: data
  - title: Trace one law end to end before fixing a form
    detail: 'The EReA → ERA trace found four causes in four places (reader, feed range, commencement order, repeals-table cells) for the same ~180 rows; fixing the reader alone would have looked like no progress.'
    tag: data
bugs:
  - pattern: 'A feed effect on a range ("s. 71 - 80 (Pt. 8) substituted", EReA 1999 s.7 on ERA 1996) reaches only the range''s first section (s.71) and the Part row via the note; s.72–s.80 get no record'
    category: feed range refs
    module: ChangeCollector.Feed / EffectIndex
    affected: 'ERA 1996 ss.72–80 (~130 rows) carry no label; corpus count unknown'
    fix: expand an effect's provision range to every section in it (LatRef range, as the evaluator does)
    status: open
  - pattern: 'A commencement order commencing "the provisions of the Act specified in Part II of Schedule 1 to this Order" is read as scope sch.1 of the commenced Act (SI 1999/2830 reg.2 → EReA 1999 sch.1, twice, 1999-10-25 and 1999-12-15); the provisions the order''s Schedule lists are never dated'
    category: commencement reader
    module: Commencement reader (scope from the order's own Schedule)
    affected: 'EReA 1999 (s.7, s.8 … undated); corpus count unknown'
    fix: '"specified in [Part N of] Schedule M to this Order" → read the order''s Schedule rows as the scope; never the commenced Act''s Schedule'
    status: open
  - pattern: 'A repeals-table cell listing several entries ("In section 117, …. Section 118(2) and (3). Section 120(2). … Section 125. …") is read as its first entry only'
    category: amendment reader
    module: Amendment.Reader.repeal_table
    affected: 'EReA 1999 Sch 9 on ERA 1996: 5 cells, ~40 entries → 5 rules; corpus count unknown (the feed''s undated ref records still mark the rows repealed)'
    fix: split a cell's text into entries (sentence per provision named), one rule each
    status: open
  - pattern: 'Spurious targets from a quote''s own numbers and captions: s.99(99), s.47B(47C), s.88(c), s.i'
    category: amendment reader
    module: Amendment.Reader
    affected: 'harmless (no such rows); seen throughout EReA 1999 on ERA 1996'
    fix: with AR-07 — a target only from the instruction's own reference
    status: open
  - pattern: 'A block substituted from the amending law''s own Schedule ("Part I of Schedule 4 shall be substituted for Part VIII": EReA 1999 on ERA 1996) not reached'
    category: amending-law collector
    module: Amendment.Reader
    affected: 'ERA 1996 ss.71–80, 57A–57B (~180 rows); 9 instructions in 6 laws, 1 in the register'
    fix: '"set out in [Part N of] Schedule M … substituted for / inserted after" → the Schedule''s quote (bf752873)'
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader.ex
  - backend/test/sertantai_legal/scraper/amendment/reader_test.exs
  - backend/data/reports/lat-refactor/ar05_pilot.csv
depends_on:
  - 2026-10-19-ar-04-switch-over
enables:
  - AR-11 / AR-12 / AR-13 (split from its trace)
  - the AR measure run
---

# Session: AR-05: Blocks from the Amending Law's Own Schedule (CLOSED)

## Problem

Amendment ruleset (AR-00 meta): "Part I of Schedule 4 shall be substituted for Part VIII" (EReA 1999 on ERA 1996): a target whose new text is the amending law's own Schedule.

## Todo

- ✅ Trace EReA 1999 → ERA 1996 Pt VIII today: what `mix lat.amending --law UK_ukpga_1999_26` reads, which rows the feed and markup date, what is missing
- ✅ Find the other instances: rules (or unread instructions) substituting / inserting a block "for" / "as" the amending law's own Schedule or Part — count across the stored rules
- ✅ Reader: such an instruction targets the amended block (Part / range), its rows reached as a provision-level change (reader + collect tests first)
- ⏸️ Pilot on the affected laws (`mix lat.wave_preview --relabel --laws …`); classified diff; batch into the AR measure run — first pilot 0 label changes (undated until AR-12); with AR-12 (`ar12_pilot`): ERA unknown 477 → 319, 180 rows dated 1999-12-15 by EReA; re-pilot with AR-11 (deferred to the AR measure run)
- ✅ Close LR-43's open bug as fixed when reached (ERA Part VIII reached and dated in ar12_pilot)

## Dependencies

- ✅ AR-00 schema decided (2026-10-19)
- ✅ AR-04 switch-over applied (2026-10-20)

## Trace: EReA 1999 → ERA 1996 Part VIII (2026-10-20)

- **Two block instructions, neither read.** s.7 "The provisions set out in Part I of Schedule 4 shall be substituted for Part VIII of the Employment Rights Act 1996" and s.8 "… Part II of Schedule 4 shall be inserted after section 57 of that Act". `mix lat.amending --law UK_ukpga_1996_18` has no rule from either; the stored rules from EReA are its Sch 4 Pt III paragraphs, s.18, s.23, s.32 and Sch 8/9.
- **The feed has it, but reaches two rows.** Effect "s. 71 - 80 (Pt. 8) substituted by s. 7 Sch. 4 Pt. 1" (undated) lands on `pt.VIII` (note_cited) and `s.71` (ref) only. ss.72–80 (about 130 rows, markup in force) have **no label row at all**; s.71 is labelled in force from 2003-09-01 (a later substitution), no changed_by.
- **The date is missing upstream too.** SI 1999/2830 reg.2(2) commences "the provisions of the Act specified in Part II of Schedule 1 to this Order" on 1999-12-15; the commencement reader stores this as scope `sch.1` (of EReA). So even a reached record would be undated (T1: undated_change).
- **Repeals-table cells.** Sch 9's cells each list many entries; each cell gave one rule (its first entry). The feed's own records still mark those rows repealed, undated.

So reaching ERA Part VIII needs three things, in different places: the amendment reader (the block instruction), the feed range (s.71–80), and the commencement reader (the order's Schedule). The last two are outside AR-05's scope: AR-11 (feed range) and AR-12 (commencement order Schedule), Jason 2026-10-20; the repeals-table cells are AR-13, the spurious targets go with AR-07.

## Count: block instructions from the amending law's own Schedule (2026-10-20)

Scanned the stored XML of the 2,733 stored amending laws (of 7,621 in the change log) for "The provisions / section / Schedule set out in [Part N of] Schedule M [to this Act] shall be substituted for / inserted after / inserted as …", plus a second pass for "Schedule M … shall be / is inserted" (it added only commentary lines such as "Schedule 4A is inserted by regulation 41(8)"; none were instructions).

| Amending law | Instruction | Amends | In our register |
|---|---|---|---|
| EReA 1999 (ukpga 1999/26) | s.7 Sch 4 Pt I substituted for Part VIII | ERA 1996 | **yes**: ss.71–80, ~150 rows |
| EReA 1999 | s.8 Sch 4 Pt II inserted after s.57 | ERA 1996 | **yes**: ss.57A–57B, 32 rows (the feed reaches 4, some rows unlabelled) |
| Administration of Justice Act 1982 (ukpga 1982/53) | ss.15, 55, 69: a section from Sch 1 / 4 / 7 | Senior Courts Act 1981; Judicature (NI) Act 1978 | no |
| ukpga 1995/20 | s.3: Sch 2 inserted as Sch 5A | Criminal Procedure (Scotland) Act 1975 | no |
| ukpga 1996/46 | Sch 4 inserted as the Schedule | Rehabilitation of Offenders Act 1974 | no |
| RPA 2000 (ukpga 2000/2) | Sch 5 inserted as Sch 3A | RPA 1983 | no |
| uksi 1994/2280 | reg.7: Sch 1 inserted after Sch 21 | — | not traced (no records) |

**AR-05's reach is one amending law on one law: about 180 ERA rows.** The form is old drafting (1982–2000), so the corpus is unlikely to hold many more. Even once reached, the rows stay undated until AR-12 reads SI 1999/2830's Schedule; AR-11 (the feed range) reaches the same Part VIII rows from the feed's side.

## Reader fix (2026-10-20, bf752873)

`Reader.instruction/4`: an instruction quoting nothing whose verb clause says the provisions "set out in [Part N of] Schedule M [to this Act] shall be / are substituted for / inserted after|before" a Part, Chapter or provision (`@set_out`) takes the quote of that Schedule (or Part): the paths of every element under it (each quote sits in a wrapper with its own id, which `Text` skips). Then the rule is made as for any quoting instruction. "is amended as set out in Schedule 1" is not matched (it points to the Schedule's own instructions). Three reader tests (EReA s.7, s.8, the "amended as set out" guard); suite 2,893 pass.

- **Real law:** `mix lat.amending --read --amending UK_ukpga_1999_26` → s.7: ERA ss.71–80 substituted (provision); s.8: ss.57A–57B inserted (provision). As before for quoting instructions, "after section 57" adds `s.57(57A)…` targets (no such rows; AR-07).
- **Collector on ERA 1996:** EReA records 285 (s.7: 138 rows substituted + 12 words-level, option c, on rows inserted later such as s.71(3)(ba); s.8: 31 rows + 1 words-level).
- **Pilot (`ar05_pilot`, no write):** 0 label changes. Every EReA record is undated because SI 1999/2830 commences what its own Schedule lists (AR-12), so the rows stay unknown / insertion_not_in_register (ERA 477). The rule has to wait for AR-12 before it pays off.
- The read pass now sees a new reader version, so every amending law's index is stale. The collector reads documents until the next `mix lat.amending --read` (about 16 min). That run goes with the AR measure run.
