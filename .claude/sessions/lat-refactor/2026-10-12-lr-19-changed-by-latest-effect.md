---
session: 'LR-19: changed_by From the Latest Joined Effect'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "A note's changed_by comes from the latest-dated effect joined to it, not the law the note itself cites (its Citation): later changes to the same words replace the note's own amender"
    category: lat-change-facts
    module: "scraper/change_facts.ex (note/3, changed_by = last.affecting)"
    affected: 1716 notes / 176 laws
    fix: "decide: the note's own Citation (citation_law) wins when present, effects only date it; or keep the latest effect"
    status: open
---

# Session: LR-19 changed_by From the Latest Joined Effect (PENDING)

## Problem

Found in LR-15 (2026-10-12). 2,849 notes in 206 laws have a `changed_by` different from the law the note itself cites (`citation_law`, from its `<Citation>` markup). 1,133 are the expected Welsh SI twins (uksi URI, wsi law). **1,716 notes in 176 laws** name a different law: when a note joins effects, `ChangeFacts.note/3` takes `changed_by` from the latest-dated joined effect (`last.affecting`); `citation_law` is used only when no effect joins. Examples: 1981/69 "Words substituted by Local Government Act 1985 (c. 51)" → changed_by 2006/16; eur 2008/1272 Art. 49(3) "inserted by S.I. 2019/720" → 2020/1567; 2015/310 reg.6 "substituted (N.I.) by S.I. 2019/583" → 2020/1616.

## Todo

- ⬜ Classify the 1,716: later change to the same words; amendment of the amending instrument (2020/1567 amended 2019/720 before exit day); wrong join
- ⬜ Check against the QA spec (T7: changed_by = the first instrument after " by ") and LR-05's intent (citation_law precedence)
- ⬜ Jason decides
- ⬜ If fix: tests first; classified diff; re-parse dry run → Jason → apply

## Decisions for Jason

- **D1 — Which law is a note's changed_by**: the law the note cites (its Citation) with effects only dating it, or the latest joined effect's law

## Dependencies

- ✅ LR-07, LR-05 closed
