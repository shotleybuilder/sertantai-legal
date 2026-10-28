---
session: 'CV-S05f: Target-Named Extent Statements'
status: active
opened: '2026-10-28'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
depends_on:
  - change-vocabulary/2026-10-22-cv-s05-extent-reader.md
---

# Session: CV-S05f: Target-Named Extent Statements (ACTIVE)

## Problem

Some amending laws state the extent of a change by its target in the amended law, not by their own provision: "The repeal of section 4(8) extends also to Scotland" (SOCPA 2005 Sch.7 para 27(4)), "The repeal of the Arbitration Act 1975 extends only to England and Wales and Northern Ireland" (ukpga 1996/23), "The amendments of the International Criminal Court Act 2001 extend to England and Wales and Northern Ireland only" (ukpga 2010/23). Extent rows are keyed by amending provision, so the reader leaves these unread, which withholds the bound (CV-S05 round 6: wider is safe). Where one amending provision makes several changes with different extents (SOCPA Sch.7 para 27(2) repeals RTA 1988 s.4(6)–(8): s.4(6) and (7) E+W, s.4(8) also S), no bound on the provision is right for all of them.

Found by CV-S06's golden run from inputs (2026-10-28): RTA 1988 s.4(6) fails, repealed everywhere from 2006 where it stays in force in Scotland. Placed by Jason 2026-10-28: a PENDING sub-session straight after CV-S06's agent seeds; the golden case is a known limit until then.

## Todo

- ✅ Measure: 20 target-named statements in 14 amending laws; 2 bear on OH&S changes (SOCPA Sch.7 para 27(4), EPA 1990 Sch.16 Pt III); 89 unread Schedule own-paragraph rows in 47 laws (see Measure)
- ✅ Design: target statements `{kind, place, scope, law, refs}` (new `Extent.Targeted`), rows `target_<kind>` with a new `amends` column, matched in `Lookup.of_change/3` by the change's law and target; own-paragraph forms widened (see Design)
- ✅ Read the forms (6ecbc958, check fix 26d91b7e): `Extent.Targeted` + `Extent.ChangeTarget`, `amends` column; own-paragraph forms widened; catalogue 10 new patterns, 8 examples re-read (see Build)
- ✅ Golden from inputs 27/27; extent check PASS (our faults 0); catalogue; one chain (see Chain)
- ⬜ Agreement measure (CV-S06's revised check, Jason 2026-10-28): the extent reader's bound (`law_text.extent`) against the feed's `effect_extent` / `territorial_application`, like for like, over every bounded change; agents on the disagreements and on changes with no feed extent. Added to the quality statement

## Dependencies

- ✅ CV-S05 Extent and application reader (closed)

## Measure (2026-10-28)

A read-only scratchpad scan (`scratchpad/s05f/measure.py`, 33 s) went over every stored body and schedules text: 4,417 files, with quoted words left out. It found 383 sentences whose subject is a change (amendment, repeal, revocation) and that state an extent.

- **Own provision named** ("the amendments made by section 12", "the repeals in Schedule 7"): 278 sentences. These are the reader's existing forms, outside this session.
- **Target in another law named:** 74 sentences, 53 of them in amending laws with rules. The 53 were classed by hand:

| Class | Sentences | Laws | Reader now |
|---|---|---|---|
| General "same extent as the enactment amended" | 19 | 18 | read (`same`) |
| **Specific: named law or provision, plus territory** | **20** | **14** | `unread` (bound withheld) |
| Noise: another law's changes (asp 2009/6, asp 2010/5 ×3), mentions (overseas territories, Isle of Man, Channel Islands, powers) | 14 | 13 | n/a |

The 20 specific statements:
- EPA 1990 Sch.16 Pt I–III notes ×3;
- RSA 1993 Sch.6 Pt I note;
- 1993/28 s.188(7) (an exception);
- Arbitration Act 1996 s.108(4);
- 2002/17 s.42(7);
- SOCPA 2005 Sch.7 para 27(4);
- 2009/23 Sch.22 Pt 2;
- 2009/25 Sch.23 Pt 2 ×2;
- 2012/9 Sch.10 Pt 2 ×3 (lists);
- 2013/24 s.102(6) (a list);
- SI 2008/948 Sch.2 para 2;
- SI 2010/866 art.3(2) (a list);
- AFA 2015/2 s.96(2) and (3);
- 2016/20 s.85(2) (an exception to "same").

**OH&S bearing.** The 14 laws all make OH&S changes, but most of the named targets are laws outside the family: the Arbitration Act 1975, Police Act 1997, Armed Forces Act 2006, Coast Protection Act 1949 and the libel Acts. Two statements bear on the family:
- **SOCPA Sch.7 para 27(4):** RTA 1988 s.4(8) is also repealed for Scotland, while s.4(6) and (7) are repealed for E+W only. The golden case, s.4(6), is stored E+W from an older read; the fresh read from inputs leaves para 27 unread, so the bound is nil and the repeal applies everywhere.
- **EPA 1990 Sch.16 Pt III:** the repeals in COPA 1974 (s.57(a), ss.58 and 59, parts of s.69) do not extend to Scotland. No provision change holds any of these targets: there is one rule (s.57(a)) and no change. That is a coverage gap, CV-07's class, not an extent fault.

**Own-paragraph forms** (todo 3, "This paragraph extends …"): stored as `unread` with a Schedule paragraph or Part as the item. That is 89 rows in 47 laws, of which 68 rows in 35 laws are in laws that make stored changes.

## Design (2026-10-28, Jason: "go ahead" on the narrow scope)

**What is read.** A *target statement* states the extent of the changes one amending provision (its **scope**) makes to a named **target** in the amended law. It is a list entry in the extent reading's own kinds (`:also`, `:only`, `:not`, `:named`), kept apart from `lists` in a new struct field `Extent.targets`:

`%{kind, place, scope, law, refs}`
- **scope:**
  - the paragraph, for a Schedule paragraph's sentence (SOCPA Sch.7 para 27(4) → `sch.7.para.27`);
  - the Part, for a note under a repeals Schedule Part (EPA 1990 Sch.16 Pt III → `sch.16.pt.III`);
  - `"*"` for a section's sentence (Arbitration Act 1996 s.108(4)).
- **law:** the amended law as named, a title normalised (no "the", no "(c. N)"). It is nil when no law is named ("the repeal of section 4(8)"), which means the law the scope's own instructions amend.
- **refs:** the target provisions in the amended law's grammar (`s.4(8)`), or `["*"]` for the whole law ("the repeal of the Arbitration Act 1975", "the repeals in the Clean Air Act 1956").

**Forms read** (new pure module `Extent.Targeted`, below 300 lines). The subject is `(The|An|Any) (repeal|repeals|amendment|amendments|revocation|revocations)( and …)? (of|in|to) X`, where X is provisions, a title, or provisions of a title. Several subjects can join with commas or "and" ("The repeal of the Libel Act 1792, the repeal in section 1 of …"). A leading "Note:" is dropped. The verb is one of: extends also to → also; extends only to, or extends to … only → only; does not extend to → not; extends to → named. Also read:
- the list form, "The repeals and revocations in the following provisions extend to …— (a) …" (2012/9, 2013/24, SI 2010/866), each item a target;
- "An amendment or repeal of a provision of the X Act extends to …" (AFA 2015/2 s.96(2)).

**Left unread (known limits, logged):**
- a target statement inside an exception ("This Part, except … the repeals in …", 1993/28 s.188(7); "An amendment (other than an amendment of Part 1A of the Petroleum Act 1998)", 2016/20 s.85(2));
- one with a lead-in exception ("Except as provided in Part II of this Schedule, the repeal of …", RSA 1993 Sch.6);
- a relative clause (2002/17 s.42(7));
- "so far as it is applied by" (2015/2 s.96(3)).

These stay `unread`, so their bound is still withheld.

**Classed as read.** `Patterns.outcome/5` checks `Targeted` first. A sentence whose statements are all in `e.targets` is `target:<kind>:<place>`, otherwise `unread:target`. Only an unread one gives `Unread` its `{:unread, nil, scope}`, as now.

**Lookup.** `Lookup.of_change/3` takes `refs` and the change `%{law: law_name, title: act_title, target: ref}`. `of_change/2` stays and delegates with nil.
1. The base is `of_change/2` as now.
2. The target statements whose scope covers one of `refs` and whose refs cover the target (`RefList.covers?`, or `"*"`) apply in `@apply_order` to the base: only sets it; named sets it (unioned with a stated default, as `of/2`); also unions with the base (nil stays nil); not subtracts.
3. A statement naming a law applies only where the title matches. If the title is nil (not given), any statement in scope gives nil: unknown, never a wrong bound.

The callers pass the change: `Readers.Feed.extent/3` passes `law_name`, the target and `act_title` (a new `read/8` argument from `ChangeVocabulary.build`), and `NoteDate.extent_claims` passes `c.target` with the law and title. `lat.extent_check` keeps `/2`.

**Stored.** `extent_rules` rows: kind `target_also|target_only|target_not|target_named`, place, items = refs, source_ref = scope, and a new nullable **`amends`** column for the law as named. It is added to `ExtentRule` (Ash generates the migration; the kind constraint widens) and to `Store` `@columns` and `@compared`. `Rows.to_rows/from_rows` round-trip them. A restore point of `extent_rules` is taken before the write.

**Own-paragraph forms** (todo 3). `OwnParagraph` widens to:
- "extends to the whole of the United Kingdom";
- "extends to England and Wales and to Northern Ireland (but not to Scotland)": named, the bracket consistent with it;
- "extends also to Scotland": also;
- "has the same extent as that Act" or "as the provision amended": `:same`.

**Alternatives weighed:**
- Resolving the law to a `law_name` at read time from CLML `Citation` URIs: rejected. Citations are absent where needed (SOCPA para 27, 2009/25 Sch.23 Pt 2 have none), and the reading must stay pure from the document.
- Keeping the law in `items` ("@Title"): rejected. It overloads refs, and a column is plain.
- One bound per amending provision (today's model): this can't give s.4(6) E+W and s.4(8) E+W+S from one paragraph, which is this session's problem.

**Tests first (red):**
- `Targeted` units for each form, from the sentences in Measure;
- a `Lookup.of_change/3` case for SOCPA para 27: s.4(6) E+W, s.4(8) E+W+S, a nil title gives nil;
- the `Rows` round trip;
- the `OwnParagraph` new forms;
- `ReadVersion` coverage takes the new module.

**Acceptance:** the extent catalogue diff reviewed (`mix lat.extent_patterns`, only target and own-paragraph classes change); `lat.extent_check` with our faults 0; golden from inputs 27/27; one chain (read pass, rebuild, golden).

## Build (2026-10-28)

**Code** (6ecbc958):
- `Extent.Targeted` (214 lines) reads the statements;
- `Extent.ChangeTarget` (125) applies them to a change (`Lookup.of_change/3`; `/2` unchanged);
- `extent_rules.amends` (an Ash migration);
- rows `target_<kind>`;
- `Patterns` classes `target:<kind>:<code>` and `unread:target` (the latter withholds, as before);
- `Feed.read/8` and `NoteDate.extent_claims/3` pass the change's law, title and target.

Register titles carry no year ("Road Traffic Act"), so a named law is matched on its name plus the year from the law's id. `patterns.ex` (522 lines) and `feed.ex` (518) were already over 300 before this change; this session added under 20 lines to each.

**Tests:** 24 new (`targeted_test`, `own_paragraph_test`, `lookup_test` of_change/3, `rows_test`). amending_law suite 1,647 pass.

**Catalogue** (`mix lat.extent_patterns --accept`, 7m41s; the first run was restarted in parallel once Jason closed the VM).
- 10 new patterns accepted, 1 gone (`…|only|-|unread:in_clause`, now `target:only:…`).
- 8 examples read differently, each checked against its sentence and right: 1990/43 Pt I, 1996/23, 1996/47, 2003/44, 2005/15 para 49, 2010/23, 2012/9, 2015/2.
- Pre-flight found and fixed two misreads before acceptance:
  - SI 2012/2404 reg.4 "The amendment in Schedule 1": the law's own Schedule. With no law named, a target statement is only read in a Schedule paragraph.
  - 2003/44 s.337 "The repeals in Part 4 of Schedule 37 relating to— (a) the … Act": the scope is the Part and the targets are the laws.

**Known limits logged:**
- SI 2008/948 Sch.2 has the paragraph id `wrapper2n1`, so its statement's scope never meets a feed ref (not OH&S). This is a parser naming tell-tale.
- The exception and lead-in forms listed in Design.

**Extent check (OH&S):**
- The first run reported 384 `stale`: the check compared a hard-coded column list without `amends`. Fixed to use `Store.compared/0` (26d91b7e).
- Now 5 stale: exactly the OH&S amending laws whose reading changed (EPA 1990, Arbitration 1996, SOCPA 2005, ERRA 2013, AFA 2015). They clear when their extent rows are written.

## Chain (2026-10-28, Jason: "Full read pass")

1. **Restore point** `cv-s05f-before-chain` (extent_rules, amendment_rules, provision_changes, provision_change_claims).
2. **Read pass** (`mix lat.amending --read`, 9m48s): 2,102 laws read, rules unchanged (42,746 → 42,746, as expected: no amendment-reader change). Extent rows were rewritten for the laws whose reading changed: 28 `target_*` rows in 10 laws, plus SOCPA Sch.7's own-paragraph rows (paras 47–49, 51, 54, 56, 57, 60) and `target_also S sch.7.para.27 {s.4(8)}`.
3. **Extent check (OH&S):** PASS, our faults 0. Territory from the law's bound covers 3,057 of 4,911 changes; `none:unread_statement` is 321.
4. **Rebuild** (`lat.vocabulary --check --family OH&S`, 1m31s): 27/27. That figure is scored from stored changes. RTA 1988 lies outside the family, so its stored changes (built 2026-10-22) still say s.4(8) E+W.
5. **Golden from inputs** (`--golden`, 2m48s): **27/27**. RTA 1988 s.4(6) passes from a fresh read; it was the CV-S06 known limit.

Lookup from the stored rows on the feed's own affecting refs (`sch.7.para.27(2)`, `sch.17.pt.2`): s.4(6) E+W, **s.4(8) E+W+S**. The stored RTA changes take it at RTA's own rebuild (not in OH&S).

