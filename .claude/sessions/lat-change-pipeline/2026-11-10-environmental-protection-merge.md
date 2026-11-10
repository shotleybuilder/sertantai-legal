---
session: 'Environmental Protection: Merge'
status: closed
opened: '2026-11-10'
closed: '2026-11-10'
outcome: success
family: '💚 ENVIRONMENTAL PROTECTION'

summary: >
  Merge passed for Environmental Protection, OH&S and Maritime Safety on the code gate. EP's 99 unnamed groups and OH&S's parked 83 were reviewed in the sources' records (178 names, no Merge fault in review). Then the one agent pass (48/50) found two hidden classes. A joined event was lent to places the feed records with effects of their own: fixed in Merge.joined_instruction (Decision 3), with one rebuild of the three families. A note citation read short was parked with the Markup reader. Both became gate causes. Gates 721/440/317 known; golden 27/27; mix test 10,663.

decisions:
  - what: "Decision 1 (A): three merge forms named known limits — law text and legacy markup apart with no feed effect (3), the feed naming the operative regulation and the law its Schedule (2), two law-text records for one effect (1)"
    why: "each below triage in changes; a Schedule-relatedness fix could join two real events of one law; both records stay visible"
    result: "RULES known-limits row"
  - what: "Decision 2 (A): the Town & Country Planning twin-apart bug kept parked, sized"
    why: "its readers are not yet through, so its 115 split-risk changes would be read through unchecked readers; in the families through the class reduces to named known limits"
    result: "sized in the bug entry; that family's Merge gate"
  - what: "Decision 3 (A): the agent's two classes as gate causes, and the joined_instruction fix"
    why: "pass rule: each agent class becomes a code group; class 1 is the Merge's own code (another place's date and operation given to a provision: binds-on-date)"
    result: "joined_instruction lends nothing where another effect by the same law names the joined event's amending provision; EPA 1990 43 and SI 1992/2966 20 changes moved; 268 remaining lends checked mechanically"

metrics:
  strata_before: { EP: "J 4709 / U 32 / C 17", OHS: "J 2354 / U 16 / C 2", Maritime: "J 2124 / U 6 / C 4" }
  strata_after: { EP: "J 4667 / U 33 / C 17", OHS: "J 2334 / U 17 / C 2", Maritime: "J 2120 / U 6 / C 4" }
  join_rate_after: { EP: "law text 3478/4042 (86.0%), markup 3520/3674 (95.8%)" }
  spread_keys: { EP: 39, OHS: 61, Maritime: 19 }
  gate: { EP: "695 (99 unnamed) → 721 known", OHS: "429 (83 unnamed) → 440 known", Maritime: "309 → 317 known" }
  agent_pass: { seed: 61, items: 50, ok: 48, wrong: 2, tokens: 179044 }
  golden: "27/27"
  mix_test: "10,663 pass"

lessons:
  - title: A default name per cause can hide a second shape
    detail: "'markup alone' was named by default as 'the feed holds no effect', yet held markup beside a joined twin (a note read short); the agent found it. Split a cause in code by shape before naming it by default."
    tag: tooling
  - title: Preview a merge fix in memory before any write
    detail: "Two first rules for joined_instruction refused too much (the joined effect's own dated stages; an 'in each place' list's other items). An in-memory build of 7 laws against the stored changes (gate causes and moved keys) caught both in minutes; one rebuild followed."
    tag: tooling
  - title: The agent pass earned its cost on the by-design groups
    detail: "The review by shape found no Merge fault in 636 changes; the 50-change agent pass over by-design groups found a Merge fault reaching 63 changes. The by-design groups are where the merge's own assumptions sit."
    tag: data

bugs:
  - pattern: "An amending provision's list items read twice, under the paragraph's id and again under the numbered list's (SI 2013/3113 reg.94(2): regulation-94-2-a…d and regulation-94-a…d); the second copy is left apart by the merge"
    category: list-items-read-twice
    module: amending_law/ (Doc.ListItems, numbering items that already hold ids)
    affected: 4 rules, one law (corpus-wide pattern search)
    fix: "Number only list items with no id under a parent that holds no numbered children"
    step: Amending-law reader
    status: open
  - pattern: "The feed's '#made' record (an effect's earlier maker, 'as inserted by') copies the later law's affecting provisions and date, so it never joins the maker's own text (SI 2019/696 on SI 2008/1597 reg.7, 13, 21; SI 2019/758 on REACH Pt 15A)"
    category: made-record-carries-later-affecting
    module: change_vocabulary/readers/feed.ex (with_maker)
    affected: 5 changes in 2 laws left apart; 150 '#made' records corpus-wide
    fix: "Drop the later law's affecting provisions (and its date) from the maker's record, so the merge joins it as naming no amending provision"
    step: Feed reader
    status: open
  - pattern: "A whole-law rule ('*', NISR 2012/179 reg.33(1) revoking NISR 2007/31) makes no change: the law text's claims never reach the 40 provisions the feed's revocation is placed on"
    category: whole-law-rule-makes-no-change
    module: change_vocabulary/readers/amending_law.ex
    affected: 10 whole-law repeal rules corpus-wide, 6 on built laws; labels right (the feed carries the revocation)
    fix: "Attach a '*' law-text rule to every change carrying its feed effect"
    step: Amending-law reader
    status: open
  - pattern: "A legacy note's citation 'arts. 1, 2' read as its first piece only (art.1, the commencement article), so the markup record stays apart from its joined twin (EPA s.153(1)(ee) by SI 1996/1431: d29p24693 beside the feed's effect and the law's art.2)"
    category: note-citation-list-read-short
    module: change_vocabulary/readers/markup (the note's affecting provisions)
    affected: "1 found by the agent; now counted by the merge gate's 'markup alone beside its joined twin'"
    fix: "Keep every piece of an 'arts./regs./ss. X, Y' citation; a provision relates if any piece does"
    step: Markup reader
    status: open
  - pattern: "One instruction joined to an event at one place lent that event's feed facts (key, date, operation) to every other place it names, even where the feed records the instruction per place with its own effects (EPA s.78G(3)(a) given SSI 2005/658 reg.2(2)'s s.78A(7)(b)(i) effect, key on 39 provisions)"
    category: instruction-lends-another-place-effect
    module: change_vocabulary/merge.ex (joined_instruction)
    affected: "EPA 1990 38 changes (SSI 2005/658), plus repeals-Schedule places; SI 1992/2966 20 (SI 2022/8)"
    fix: "Never lend where another effect by the same law names the joined event's amending provision (the feed records it per place)"
    step: Merge
    status: fixed
  - pattern: "OH&S Merge gate: 85 groups not named, as at 2026-11-08"
    category: ohs-gate-merge
    module: test/fixtures/merge/merges.json
    affected: 85
    fix: "review each group known/fix/check"
    step: Merge
    status: fixed
  - pattern: "One event split where legislation.gov.uk's markup ChangeId differs from the feed's EffectId (SI 1993/3138 reg.28)"
    category: changeid-differs-from-effectid
    module: test/fixtures/merge/merges.json
    affected: "3 changes in 3 laws (SI 1999/3206, wsi 2013/755, SI 1995/2036); counted by the gate's 'markup alone beside its joined twin'; legislation.gov.uk's own ids, a known limit (RULES)"
    fix: "none: known limit"
    step: Merge
    status: fixed
  - pattern: "Merge: an alias joins two events (SI 1995/2038 reg.6(8)); KX territory (SI 2008/1597 reg.3); a KX chain change left apart"
    category: merge-alias-kx
    module: change_vocabulary/merge.ex; readers/feed.ex
    affected: "alias 1 change and territory 1 law: known limits (RULES); the chain moved to the Feed reader (made-record-carries-later-affecting, 5 changes in 2 laws)"
    fix: "see made-record-carries-later-affecting"
    step: Merge
    status: moved
  - pattern: "Merge/placement: NISR 2012/179's whole-law '*' rule has no '*' change; an 'in each place' words change kept on the parent (NISR 2010/160 reg.28)"
    category: merge-whole-law-each-place
    module: change_vocabulary/readers/amending_law.ex
    affected: "whole-law rule moved to the Amending-law reader (whole-law-rule-makes-no-change: 10 rules, 6 on built laws; labels right); 'in each place' 1 change, a known limit"
    fix: "see whole-law-rule-makes-no-change"
    step: Merge
    status: moved

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge_gate.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/merge_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/merge_gate_test.exs
  - backend/test/fixtures/merge/merges.json
  - backend/data/reports/merge/environmental-protection-gate-review-1.md
  - backend/data/reports/merge/ohs-gate-review-2026-11-10.md

depends_on:
  - 2026-11-10-environmental-protection-amending-law-reader

enables:
  - "Environmental Protection: Evidence"
---

# Session: Environmental Protection: Merge (CLOSED)

## Problem

This is step 7 of the LAT Change Pipeline for Environmental Protection. Its aim is one change per real event, whichever sources state it: no change holding two events, no event left as two changes, and no event placed on different provisions. Under the standing rule, the bugs parked on Merge are fixed here, whatever family found them, and anything left parked gets its size and reason. The plan is `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`, approved 2026-11-10.

## Todo

- ✅ Open the step session with the baselines (the three families' strata and gates, the stale state) and the parked bugs
- ✅ Dump and review every unnamed group, EP (99) and OH&S (83), widest first; name each in `merges.json` (dry run first), with reasons in a report; measure each parked bug's reach: 178 statuses written, all three gates PASS, no Merge fault
- ✅ Decisions for Jason: known limits, any `fix:` class, the parked bugs' outcomes (Decisions 1–2 below)
- ✅ The one agent pass (seed 61, 50 by-design EP changes, `cmp` identical): 48 OK, 2 wrong, both new classes; 179,044 tokens. Its classes as gate groups: Decision 3
- ✅ Fix the `fix:` classes and Merge's parked bugs over triage, test first; pre-flight; one approved restore point and rebuild round (Decision 3: `joined_instruction` fixed; the gate's two new causes; pre-flight clean; restore point taken; rebuild of the three families done)
- ✅ The gate PASS for all three families (721/440/317); regression: OH&S U 16 → 17 (SI 2022/8 reg.6(a) at reg.10, left apart by the fix's rule, no longer lent reg.6's effect), C and spread unchanged; Maritime unchanged
- ✅ Golden 27/27 (with the fix, from inputs); `mix test` 10,663, 0 failures; Credo adds no issue
- ✅ Pass and close: WORKFLOW step 7 note, RULES, the skill's history, parked bugs with size and reason, the meta row, commits

## Dependencies

- ✅ Environmental Protection: Amending-law reader closed (2026-11-10): `disagreements.json`, whose statuses the gate inherits
- ✅ The three families' changes were built after the Amending-law reader's last write. They are stale only on `commencement_reader` (below).

## Pass rule (fixed, WORKFLOW step 7)

1. `mix lat.merge_check --family F --gate --all` prints PASS for Environmental Protection, OH&S and Maritime Safety. Every group is `known:` in `test/fixtures/merge/merges.json`.
2. One agent pass: 50 EP changes from the by-design groups, seed 61, drawn twice and compared with `cmp`. Its classes become gate groups. No resample.
3. No regression: OH&S and Maritime U, C and spread no higher than the baseline.
4. Golden 27/27.
5. `mix test` has 0 failures; Credo clean; hooks pass.
6. The join rate and a quality statement are published.

Triage size: 10 changes, or 2 or more amending laws. Frozen: `golden.exs` and `disagreements.json`.

## Baselines (2026-11-10, before any change)

The reports are `backend/data/reports/merge/*-gate-0-2026-11-10.txt` and `*-strata-0-2026-11-10.txt`.

| Family | J | U | C | Join rate, law text | Join rate, markup | Spread keys | Gate |
|---|---|---|---|---|---|---|---|
| Environmental Protection | 4,709 | 32 | 17 | 3,520/4,042 (87.1%) | 3,520/3,674 (95.8%) | 39 | FAIL: 695 groups, 99 not named |
| OH&S | 2,354 | 16 | 2 | 1,433/1,903 (75.3%) | 1,690/1,881 (89.8%) | 61 | FAIL: 429 groups, 83 not named |
| Maritime Safety | 2,124 | 6 | 4 | 1,438/1,614 (89.1%) | 1,668/1,691 (98.6%) | 19 | PASS: 309 groups |

Since their passes, Maritime has moved from J 2,125 / U 8 to 2,124 / 6, and OH&S's unnamed groups from 85 to 83, both through the Amending-law reader's fixes.

**Stale state:** 18 EP, 30 OH&S and 10 Maritime built laws are stale only on `commencement_reader`. Some of their amending laws keep commencement rules from older reader code (2000 c.27 holds 204 rules, 2000 c.37 holds 22). That is the Commencement reader's state, already parked. It moves dates only, not joins.

## Parked bugs on Merge (5)

- OH&S gate: 85 groups not named (now 83).
- A primary change and its legislation.gov.uk twin left apart (TCPA 1990, 184 on golden laws).
- An alias joining two events (SI 1995/2038 reg.6(8)); territory cut to the later law's extent (SI 2008/1597 reg.3); a chain change left apart.
- NISR 2012/179's whole-law `*` rule; an "in each place" words change kept on the parent (NISR 2007/31, 40 changes).
- One event split where the markup's ChangeId differs from the feed's EffectId (SI 1993/3138 reg.28).

## Review (todo 2)

The reports are `backend/data/reports/merge/environmental-protection-gate-review-1.md` and `ohs-gate-review-2026-11-10.md`. The scratch dumps are `dump_merge.exs`, `show_u.py`, `chk.py`, `groups.py` and `name_merges.py` with `merge_overrides.json`, for the tooling session.

- **Every unnamed change checked by shape.** In 286 of EP's 294 and in nearly all of OH&S's 342, every source names one operation and the markup's note cites the change's amending law. The rest were read one by one.
- **Each unjoined change and candidate (EP 32 + 17, OH&S 16 + 2) was read with the changes beside it.**
- **178 statuses written** to `merges.json` (dry run first). Gates: EP 695/695 known, OH&S 429/429, Maritime 309/309. **All PASS.**
- **Merge faults found: none.** What the review found:
  - **Other steps' faults** (named, parked):
    - asp 2014/3 (7 changes): the Act read as starting the day after Royal Assent, so the day rule keeps its records apart. Commencement reader, existing amending-law-start-misread.
    - SI 2013/3113 reg.94(2): items read twice, under `regulation-94-2-a` and `regulation-94-a` (4 rules, one law). Amending-law reader.
    - The feed's `#made` records (an effect's earlier maker) carry the later law's affecting provisions, so they never join the maker's own text (5 changes in 2 laws; 150 `#made` records corpus-wide). Feed reader.
    - SI 1988/1655's modification read as amendments: the Amending-law reader's open decision 7.
  - **legislation.gov.uk's own records:**
    - markup effect ids its feed doesn't place (SI 1999/3206, wsi 2013/755, SI 1995/2036: 1 change each);
    - an affecting provision named "s.73" for reg.73 (SI 2005/894, 1);
    - legacy markup showing a repeal's dots as an Addition (by design).
  - **Known limits of the merge** (Decision 1):
    - one event in two id-less records, the law's text and legacy markup, with no feed effect (1999 c.29: 3 changes);
    - the feed naming the operative provision while the law's text or markup names its Schedule (SI 2023/149, SI 1996/3022: 1 change each);
    - two law-text records for one feed effect (NISR 2017/86: 1).

## Parked bugs: outcomes

| Bug | Outcome | Size, reason |
|---|---|---|
| OH&S Merge gate: 85 not named | **Fixed** | 83 → 0 named (`ohs-gate-review-2026-11-10.md`) |
| A primary change and its twin left apart (TCPA 1990) | Decision 2 | TOWN & COUNTRY PLANNING now has U 24 + C 91 = 115 split-risk changes (from 184 on the golden laws). Its readers are not yet through. In the three families through, the class is the named forms above (each 3 changes or fewer). |
| An alias joining two events (SI 1995/2038 reg.6(8)) | Known limit | 1 change: the feed's "amendment to earlier affecting provision" (2020/660) carries a 1995 commencement id as alias; no operation, so no label effect |
| Territory cut to the later law's extent (SI 2008/1597 reg.3) | Known limit | 1 law: reg.3 by SI 2019/696 carries E+W+S; not re-measured further |
| A chain change left apart (SI 2008/1597 by SI 2019/696) | **Moved to the Feed reader** | 5 changes in 2 laws (SI 2019/696, 2019/758); 150 `#made` records corpus-wide. `with_maker` copies the later law's affecting provisions onto the maker's record |
| NISR 2012/179's whole-law `*` rule has no change | **Moved to the Amending-law reader** | Not Merge's: the reader of amending-law rules into changes makes no change for a `*` rule (none in memory). The feed carries the revocation on all 40 provisions, so the label is right. 10 whole-law repeal rules corpus-wide, 6 on built laws |
| An "in each place" change kept on the parent (NISR 2010/160 reg.28) | Known limit | 1 change, one law (NISR 2019/6 on reg.28) |
| ChangeId differs from EffectId (SI 1993/3138 reg.28) | Known limit, legislation.gov.uk's ids | 3 changes in 3 laws, now each visible as a "markup alone" group with an effect id the feed doesn't place |

## Decisions

### 1. The merge's known limits — DECIDED 2026-11-10: A (known limits)

**Question:** are three forms named as known limits rather than fixed in the merge?
1. one event in two id-less records, the law's text and legacy markup, with no feed effect (1999 c.29: 3 changes, one law);
2. the feed naming the operative provision ("reg.2: the Schedule has effect") while the law's text or markup names the Schedule (SI 2023/149, SI 1996/3022: 1 change each, two laws);
3. two law-text records for one feed effect (NISR 2017/86: 1).

**Aim:** `one-change-per-event`.

**Options:**
- **A (recommended):** name them known limits (RULES.md, Known limits). Each is visible: both records stay in the register, and neither is lost.
  - Form 2 reaches two laws, the triage line, but only 1 change each. A fix would have to call a regulation "related" to a Schedule, which could join two real events of one law.
  - Forms 1 and 3 are one law each.
- **B:** fix form 2 in `Merge.Partner`: a lone partner whose amending provision gives the named Schedule effect joins. That needs the amending law's words in the merge. Rebuild of the three families.

### 2. The parked twin-apart bug from Town & Country Planning — DECIDED 2026-11-10: A (kept parked, sized)

**Question:** is the Town & Country Planning class reviewed now, or kept parked with its size until that family's Merge?
**Aim:** `one-change-per-event`.

**Options:**
- **A (recommended):** keep it parked, with its size (115 split-risk changes, U 24 + C 91) and its reason. Its feed, markup, commencement and amending-law readers have not been through, so its splits would be read through unchecked readers. In the three families through, the class reduces to the named forms above. It is not returned to at this step's re-runs; it is that family's Merge gate.
- **B:** review the 115 now, as OH&S's 83 were.

## The agent pass (todo 4)

Seed 61, 50 changes from EP's by-design groups, drawn twice (`cmp` identical); 179,044 tokens, 27 tool uses, 6½ min. **48 OK, 2 wrong, both new.** Pairs: 39 of 41 OK.

- **New class 1, the Merge's own code: a joined event's feed facts lent to a provision its effect doesn't name** (EPA s.78G(3)(a) by SSI 2005/658).
  - The amending-law reader reads reg.2(2)'s list of places as every section crossed with every number, so s.78G(3)(a) is among its targets though it isn't in the list.
  - `Merge.joined_instruction` then gives that place the feed effect for s.78A(7)(b)(i) (key on 39 targets). The feed has its own effect for each listed place; s.78G(3)(a)'s own event is reg.2(6)(b), left apart.
  - Rough reach, a joined change whose feed placement is neither its provision nor above or below it, with the law's text present: **EP 291 changes in 62 (law, amending law) pairs, OH&S 140 in 25, Maritime 121 in 27.** Many of them are legitimate: one effect over a range, a heading with its section, a list's siblings. The real fault count is not yet known.
- **New class 2: a note citing "arts. 1, 2" read as art.1 only**, so a legacy markup record stays apart from its joined twin (EPA s.153(1)(ee) by SI 1996/1431).
  - The root cause is the Markup reader's note citation, so it is parked there.
  - The gate's "markup alone" groups hid it: the group named by default "the feed holds no effect for it" also holds markup beside a joined twin. The parked ChangeId bug's fix ("count lone markup changes beside a two-source twin") is the same check.

### 3. The agent's two classes as gate groups — DECIDED 2026-11-10: A (gate groups and the fix)

**Question:** the pass rule makes each class the agent finds a gate group in code (no resample). Both groups are `MergeGate` code only (no rebuild). Class 1 is also a Merge fault in `Merge.joined_instruction`. How far does this step go?

**Aim:** `one-change-per-event`, `binds-on-date` (a provision wrongly given another event's date and operation).

**Options:**
- **A (recommended):**
  1. Add the two causes to `MergeGate`, test first:
     - "a joined event lent to a provision its effect doesn't name" (a feed placement neither the change's provision nor above or below it);
     - "markup alone beside its joined twin".
  2. Review their groups in the three families by shape, as before.
  3. Fix `joined_instruction` to lend an event only to a provision its effect names, or one inside it, test first. Pre-flight, then one restore point and a rebuild of the three families.

  Class 2's root cause is parked with the Markup reader, with its size. This adds about half a day.
- **B:** add the two gate groups and name them as known; park the `joined_instruction` fault with its measured size. The gate's PASS then rests on a known Merge fault.
- **C:** park both with sizes and no gate change. This breaks pass rule 2 (the agent's classes become gate groups).

## The fix (todo 5, Decision 3)

- **`Merge.joined_instruction`:** an instruction joined to an event at one place lends that event to its other places only when the feed doesn't record the instruction per place. If another effect by the same law names the joined event's amending provision, each place joins its own effect or stays apart. Test: `merge_test` "an instruction the feed records per place never lends one place's effect to another".
  - The first rule tried, "another event by the same law already on the provision", refused too much. It caught the joined effect's own dated stages (1995 c.25 s.57's Part IIA), then items of SI 2022/8's "in each place" list. Both were caught in the in-memory preview, before any write.
- **`MergeGate`, two new causes** (no version change):
  - "a joined event lent to a provision its effect doesn't name";
  - "markup alone beside its joined twin".

  Tests are in `merge_gate_test`.
- **In-memory preview of 7 laws** (`preview_merge.exs`, `preview_detail.exs`; writes nothing):
  - EPA 1990: 43 changes move (SSI 2005/658's 38: 37 apart, 1 joining its own effect; repeals-Schedule places the feed records per place). Lent 85 → 44.
  - SI 1992/2966: 20 move (SI 2022/8). Lent 44 → 24.
  - 1995 c.21, EU 2012/649, HSWA, SI 2008/1597, SI 2006/2988: no change moves.
- **Pre-flight:** compile with warnings as errors; Credo adds no issue; change-vocabulary and architecture tests 3,470 pass; golden from inputs 27/27.
- **Restore point** `merge-environmental-protection-before-build` (`provision_changes`, `provision_change_claims`, `lat_events`). Then the three families are rebuilt one at a time.

## Parking list

- Markup reader: note-citation-list-read-short — "arts. 1, 2" read as art.1 only (SI 1996/1431 on EPA s.153(1)(ee)); counted by the gate's "markup alone beside its joined twin".

- Commencement reader: amending-law-start-misread (existing) — asp 2014/3 dated the day after Royal Assent; 7 changes left apart by the day rule in Environmental Protection.
- Amending-law reader: list-items-read-twice — SI 2013/3113 reg.94(2) read under two ids (4 rules, one law).
- Feed reader: made-record-carries-later-affecting — `#made` records carry the later law's affecting provisions (5 changes in 2 laws; 150 records).
- Amending-law reader: whole-law-rule-makes-no-change — a `*` rule gives no change (10 rules, 6 on built laws; the feed carries the revocation).
