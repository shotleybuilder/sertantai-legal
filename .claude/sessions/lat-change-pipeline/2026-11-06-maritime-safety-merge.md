---
session: 'Maritime Safety: Merge'
status: closed
opened: '2026-11-06'
closed: '2026-11-06'
outcome: success
family: '💙 TRANSPORT: Maritime Safety'

summary: >
  Merge passed for Maritime Safety on a code gate (MergeGate): 310 merge decisions grouped by cause and amending law, every one named in merges.json, plus one agent pass over the by-design groups (Decision 1, picked with Gemini). No join was wrong; the agent found one Merge class — new paragraphs a joined change makes were left with the law-text key and no date — fixed by Merge.Copies (Decision 2, with Gemini: 35 in the family, 22 had no in-force date). Strata J 2,125 / U 8 / C 4 unchanged; join rate law text 88.9%, markup 98.6%; golden 27/27.

decisions:
  - what: "Decision 1: a code gate over every merge decision plus one agent pass of 50 drawn only from the by-design groups; no resample"
    why: "Jason asked Gemini and me to pick together; Gemini chose a gate plus one agent pass and challenged the assumption that 'same amending provision, same operation' is one event; sampling the by-design groups tests exactly that"
    result: "310 groups named; agent 47/50 OK, no over-join; 2 new classes (one Merge's, fixed; one the Amending-law reader's, parked); 129,479 agent tokens"
  - what: "Decision 2 (A): new provisions a joined change makes below it stay their own changes but take the event's key and its feed dates, marked placed on the parent (RULES.md new-provisions-carry-their-event)"
    why: "binds-on-date: 22 new paragraphs had no in-force date and 7 differed from their parent; legislation.gov.uk's markup wraps them under the one effect id, so the date is a source fact (Gemini, judged on AIMS.md); the law's own commencement still wins"
    result: "Maritime 35 copies → 0 (MSA 1995 s.271(6)(a)–(c) now 2013-07-25 with s.271(6)); OH&S 39 → 0 in 9 laws, U/C unchanged"
  - what: "'dates differ' is a suffix on the join basis, not an over-join cause"
    why: "all 113 were one event with one record per source; the date conflict is the Commencement reader's"
    result: "parked amending-law-start-misread (SI 2006/1244 purpose-limited start, Acts at Royal Assent)"

metrics:
  strata: { J: 2125, U: 8, C: 4, spread_keys: 20 }
  join_rate: { law_text: "1431/1609 (88.9%)", markup: "1668/1691 (98.6%)" }
  gate: { groups: 310, known: 310, fix_found: 1 }
  agent_pass: { seed: 51, items: 50, ok: 47, wrong: 2, doubtful: 1, tokens: 129479 }
  copies: { maritime_before: 35, maritime_after: 0, ohs_before: 39, ohs_after: 0, undated_before: 22 }
  ohs_regression: { U: 16, C: 2, spread: "61 → 62 (Part 4A's carried regs, by design)" }
  golden: "27/27"
  mix_test: "10,145 pass after the version except fix"

lessons:
  - title: Group by how a change joined, not by whether sources agree
    detail: "The join basis (same effect id, the law naming legislation.gov.uk's own amending provision, a legacy note naming the feed's, weaker partner joins) sorts 2,125 joined changes into a handful of by-design groups and a small residue to read; five refinements in review (legacy note citation, several markup records of one effect, two law-text records the feed names together) turned most of the residue into named classes."
    tag: data
  - title: Spend the one agent pass on the by-design assumption
    detail: "Sampling only the groups the gate names by design found a real class (new paragraphs left undated) that no residue group showed, because those changes sat outside every stratum. The class then became a code group over the corpus (157 rows across families), as the rule asks."
    tag: tooling
  - title: A check module under a versioned glob stales every stored change
    detail: "merge_gate.ex sits in change_vocabulary/*.ex, so it entered ChangeVocabulary.Version and reached Leftovers; the version-coverage test caught it only in the full mix test. Put a new check module on the except: list when it is created, before any rebuild (the Amending-law reader session hit the same with disagreement.ex)."
    tag: tooling
  - title: Date disagreements on joined changes are a commencement signal
    detail: "113 joined changes whose feed date is none of the law's commencement dates were all one event; the gate's 'dates differ' suffix is a ready-made worklist for the Commencement reader (purpose-limited starts, Acts read at Royal Assent)."
    tag: data

bugs:
  - pattern: "An amending law's start misread on changes legislation.gov.uk dates later: a purpose-limited start read as the whole start (SI 2006/1244 reg.1(4) 15 July 2006 'so far as necessary … to enable certificates'; reg.1(2) the Bunkers Convention's day, 21 Nov 2008); Acts' amending provisions read as starting at Royal Assent (2011 c.8, 2025 c.36, 2006 c.36, 2015 c.15); SI 2018/1221 reg.2(a) '22nd day after laid' read as exit day"
    category: amending-law-start-misread
    module: commencement/ (Commencement.Amending, the amending law's own clause)
    affected: 113 joined changes in Maritime Safety (87 SI 2006/1244, 26 Acts) + 2 SI 2018/1221 pairs kept apart
    fix: "Read a purpose-limited 'so far as necessary for …' start as partial, the main start from the clause's other sentence; an Act's amending provisions by its commencement section, not Royal Assent; '22nd day after laid' from the laying date"
    step: Commencement reader
    status: open
  - pattern: "An amending provision's unnumbered list items (OrderedList Type=alpha Start>1, no ids) read at the paragraph: one law-text change per operation ('…paragraph-2#substituted' with four statements) for several feed events, joined to none (SI 2011/2616 Sch.1 para.2(c)–(i))"
    category: unnumbered-list-items-collapsed
    module: amending_law/ (Text, list items as provisions)
    affected: 7 feed effects in Maritime Safety; 19 '#op' keys across families (some the legitimate 'omit X and insert Y')
    fix: "Number an OrderedList's items from Start plus position ('schedule-1-paragraph-2-d') and key each on its own"
    step: Amending-law reader
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge_gate.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge/copies.ex
  - backend/lib/mix/tasks/lat.merge_check.ex
  - backend/test/fixtures/merge/merges.json
  - backend/data/reports/merge/maritime-gate-review-1.md
  - backend/data/code-reviews/2026-11-06-merge-gate-options-gemini.md
  - backend/data/code-reviews/2026-11-06-merge-new-paragraphs-gemini.md

depends_on:
  - 2026-11-06-maritime-safety-amending-law-reader

enables:
  - "Maritime Safety: Evidence"
---

# Session: Maritime Safety: Merge (CLOSED)

## Problem

Step 7 of the LAT Change Pipeline for TRANSPORT: Maritime Safety. The aim is one change per real event, whichever sources state it: no over-join, split or misplaced change. OH&S passed Merge after 7 agent rounds. This family's gate is code first, with one agent pass (Decision 1).

## Todo

- ✅ Open the session with the todos and Decision 1; baselines; Gemini's review saved
- ✅ The gate (TDD): `MergeGate` with its causes; `--gate` in `lat.merge_check`; `merges.json` started
- ✅ Review every non-by-design group in the sources' records (fix / known / check), with a report: 0 fix; gate PASS (310 groups)
- ✅ The one agent pass over 50 by-design changes (seed 51, 129,479 tokens): 47 OK, 2 new classes, both now code groups
- ✅ Fix the `fix:` groups by reach (TDD): `Merge.Copies` (Decision 2); pre-flight on 5 laws; RULES.md rule and known limits; 2 bugs parked
- ✅ Restore point and family rebuild: gate PASS, OH&S strata (U/C unchanged), golden 27/27, `mix test` (one failure, the version's except list, fixed and rebuilt)
- ✅ Docs: WORKFLOW.md step 7, the `merge-check` skill and history; RULES.md rule and known limits; the `amending-reader-check` skill names the two carried items
- ✅ Close the session and the meta row; code commit 93599e6d (hooks), session commit separate; no push

## Dependencies

- ✅ Maritime Safety: Amending-law reader closed (2026-11-06): its gate names every disagreeing and law-text-only change (`disagreements.json`)
- ✅ The family's changes built after the Amending-law reader's last read pass

## Baselines (2026-11-06, before any change)

- **Strata,** from `mix lat.merge_check --family "TRANSPORT: Maritime Safety" --strata`. 117 laws, with 2,137 text changes in a stratum:
  - J, joined: 2,125;
  - U, unjoined: 8;
  - C, candidates: 4.
- **Join rate:** law text 1,431/1,609 (88.9%); markup 1,668/1,691 (98.6%).
- **Spread:** 20 keys on more than 3 top provisions.
- **J by how it joined:**

  | How it joined | Operations agree | Operations differ |
  |---|---|---|
  | feed and markup, one effect id | 673 | 9 |
  | law text names the same amending provision as the feed | 1,259 (890 with markup too) | 92 |
  | through a legacy markup id | ~70 | |
  | related provision, feed names none, or no provision named | ~25 | |
- **OH&S, the regression baseline:** J 2,348, U 16, C 2, spread 61. U and C have drifted since its pass (U 1, C 9) through later steps' fixes. The drift is recorded, not chased.
- **Parked Merge bugs, from OH&S:**
  - primary twin apart (TCPA 1990, 184);
  - an alias joining two events, and others (4);
  - NISR whole-law '*' and 'in each place'.

  Each is fixed only where a gate group shows it in Maritime over the triage size.

## Decisions

### 1. The pass rule — DECIDED 2026-11-06

**Question:** how is Merge checked for this family?
**Aim:** `one-change-per-event`, `checks-in-code`.
**Jason:** "put the options to gemini and together pick the best way". The review is in `backend/data/code-reviews/2026-11-06-merge-gate-options-gemini.md` (Flash).

**Options:**
- A: a code gate, no agent;
- B: a code gate plus one agent sample of 50 joined changes;
- C: the rule as last used, pooled agent samples to the 95% bound.

**Gemini chose B.** Its challenge: one amending provision can make two events on one provision (staged dates, "omit X and insert Y"), so "same provision, same operation" is an assumption.

**Picked: B, refined.**
- The one agent sample (50, new seed) is drawn only from the by-design groups, which tests that assumption. Every other group is reviewed in full.
- What the agent finds becomes a code group. No resample.
- Gemini's "dates differ", "two records of one source" and "markup alone" are taken as code groups.
- Its fuzzy text matching is contested: law-text-only changes are named in the Amending-law reader's gate already.

**Pass:**
- the gate prints PASS (every group `known:`);
- the agent pass done once, its classes in the gate;
- OH&S's U, C and spread don't grow;
- golden 27/27;
- `mix test` passes;
- the join rate and a quality statement published.

## The gate and its review

- **`ChangeVocabulary.MergeGate`** (pure, 15 tests) and `mix lat.merge_check --gate [--all]`. Statuses are in `backend/test/fixtures/merge/merges.json`. Groups whose cause is named alone are the agent pass's population (`--by-design`).
- **Review:** `backend/data/reports/merge/maritime-gate-review-1.md`. 306 groups at first, then 310 after five refinements made in review:
  - dates as a suffix on the join basis;
  - a legacy note's citation counting as legislation.gov.uk's amending provision;
  - several markup records of one effect;
  - two law-text records the feed names together;
  - legislation.gov.uk's unlike operations named.

  **No merge fault found.** The gate gives PASS.
- **Every date disagreement (113) is one event.** The date is the Commencement reader's, parked as `amending-law-start-misread`.

## The agent pass (seed 51, 50 by-design joined changes, 129,479 tokens)

**Result:** 47 OK, 2 WRONG, 1 doubtful. No over-join was found. Neither staged dates nor two operations by one amending provision gave a wrong join.

- **New class 1, `law-text copy apart from its joined event`.** It is now a code group (35 changes in 16 laws in Maritime; about 157 across all families). An amendment substitutes words in a provision and so makes new paragraphs below it: for example 2009 c.25 Sch.21 para.34, "in subsection (6), for 'where' to the end substitute", which makes MSA 1995 s.271(6)(a)–(c). The parent joins legislation.gov.uk's effect. The new paragraphs stay their own changes, by the earlier rulings (CV-S06 seed 33, CV-S09 round 7). But they keep the law-text key, not the event's, and carry none of its dates:
  - 22 have **no date** where the event has one;
  - 7 carry the law's date where the parent took legislation.gov.uk's (s.271(6)(a)–(c) 2009, s.271(6) 2013).

  Decision 2.
- **New class 2:** unnumbered list items in an amending provision are read at the paragraph (SI 2011/2616 Sch.1 para.2(c)–(i)): one law-text change per operation for several events. It belongs to the Amending-law reader, and is parked.
- **Doubtful:** SI 2004/2883 reg.2(6) markup on reg.7C. The feed names 7A and 7B only. One change: legislation.gov.uk's markup over-reach (KR-range), a known limit.

## Decisions

### 2. The new paragraphs of a joined event — DECIDED 2026-11-06 (A)

**Question:** should a new paragraph made below a joined change carry that event's identity and dates?
**Aim:** `one-change-per-event`, and the time-machine aim (a provision with no "in force from" can't answer "does it bind me on this date").

**Options:**
- **A (recommended):** the copy stays its own change on its own provision, as the rulings say, but takes the event's key (the effect id; its law-text key kept as an alias) and the event's dated claims, as the feed's, marked as placed on the parent. Evidence then picks its date as it does for the parent: one event, one date, on every provision it makes.
  - It is a Merge fix with unit tests and one family rebuild.
  - OH&S's labels change where it has the class. It is checked by the OH&S strata and golden.
- **B:** leave it. The 22 children have no in-force date, and 7 differ from their parent. The class is named a known limit.
- **C:** fold the children into the parent's change. This reverses CV-S06 and CV-S09 (an inserted paragraph would read as words, and the parent as inserted), so it is not recommended.

**Jason:** "share the problem, your options and recommendation with google gemini and determine the right design based on the aim". Gemini (Flash; `backend/data/code-reviews/2026-11-06-merge-new-paragraphs-gemini.md`) chose A.
- **`binds-on-date`:** 22 provisions with no date fail the aim.
- **Not a guess (`unknown-over-guess`):** legislation.gov.uk's markup wraps the new paragraphs under the one effect id, so the date is a source fact about that event.
- **Guards:** the class kept narrow; the child's own commencement still wins (`law-text-wins`); the carried date marked with its source.

**Design:** `Merge.Copies`, a post-pass. It applies to a law-text change whose key was joined to a feed effect on a provision above it, and only to that.
- The change takes the event's key (its own kept as an alias).
- It takes the event's feed `date`, `partial` and `qualification` claims, with a feed `placed` claim naming the parent's provision (the existing pointer: the feed's claims speak for that provision).
- No operation, level or territory is carried.

## The fix and its results

- **`Merge.Copies`** (Decision 2), with 4 tests, runs just before `Merge.Shared`. The gate gains the group `law-text copy apart from its joined event`. A carried copy counts as the feed's own in a spread key.
- **Pre-flight:** 5 laws built (MSA 1995 and four others). MSA 1995 s.271(6)(a)–(c) now carry …b81ece, dated 25 Jul 2013. reg.12(1)(a) of SI 2010/1075 is dated 2019-02-23 where it had no date.
- **Restore point:** `maritime-merge` (`provision_changes`, `provision_change_claims`, `lat_events`).
- **Family rebuild** (117 laws, 37 s). Strata unchanged (J 2,125, U 8, C 4). Join rate: law text 1,431/1,609 (88.9%), markup 1,668/1,691 (98.6%). Copies 35 → 0. **Gate PASS**, 310 groups, all known.
- **OH&S:** only the 9 laws holding the class were rebuilt (39 copies → 0).
  - U 16 and C 2 are unchanged.
  - Spread 61 → 62: SI 2009/1348's one Part 4A insertion now covers its new regs 23A–C, by design.
  - Law-text changes 1,896 → 1,911, with feed-met unchanged: the 9 laws were last built before the Amending-law reader's fixes, so this is that reader's newer reading, not the merge.
- **Golden:** 27/27, before the fix and again after it.
- **Version:** the full `mix test` caught `merge_gate.ex` inside `ChangeVocabulary.Version`. It is now on its `except:` list, with Maritime and the 9 OH&S laws rebuilt again; nothing else changed.
- **Quality statement:** every one of Maritime's 2,137 changes in a stratum, and its 20 spread keys, has a named merge cause. Every date disagreement on a joined change is one event. No over-join was found by the gate or the agent's 50. New paragraphs now carry their event.

## Parking list

- Amending-law reader: unnumbered-list-items-collapsed — an amending provision's unnumbered ListItems (OrderedList Start>1) read at the paragraph, one law-text change per operation for several events (SI 2011/2616 Sch.1 para.2(c)–(i): 7 feed effects lose their law-text source)
- Commencement reader: amending-law-start-misread — a purpose-limited start read as the whole start (SI 2006/1244, 87); Acts read as starting at Royal Assent (26); SI 2018/1221 "22nd day after laid" read as exit day
