---
session: 'CV-S02: Feed Reader'
status: active
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S02: Feed Reader (ACTIVE)

## Problem

Step 2 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each legislation.gov.uk changes-feed effect becomes one change, on the right provision.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (agreed 2026-10-22, below): every effect accounted for; 50 random effects checked by a Claude agent; facts faithful; tested; repeatable
- ⬜ Build the acceptance check; run it (ask Jason before any long run)
- ⬜ Unplaced effects counted and reported with a reason (today they are dropped as target "?")
- ⬜ Grouped provisions in an effect ("s. 78(4BA)(4BB)", "s. 1(4)(b) and word") reach no row (open bug, CV-03)
- ⬜ NI Order kind words: "art. 10" in the feed is the row reg.10 (CV-04 Provision facts)
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01 Sources held (closed PASS 2026-10-22)

## What good looks like (agreed with Jason 2026-10-22)

**The reader's one job** (Jason: "a single purpose, very Elixir pattern"): turn each legislation.gov.uk feed effect into changes on the right provisions, carrying the effect's facts faithfully. Whether the feed itself is right is CV-S08's (evidence).

**Scope:** the OH&S core family's 149 feeds (held and checked, CV-S01).

**Pass when all hold:**
1. **Every effect accounted for:** placed on provisions we hold, or listed unplaced with a reason from a fixed set:
   - provision not in our LAT (outside its scope, or gone);
   - whole-law;
   - reference unparsed (our fault);
   - provision form not read (our fault).
   Nothing unplaced without a reason, and none for our-fault reasons.
2. **Right provision, checked:** 50 effects sampled at random, checked by a Claude agent against each effect's own affected-provision text. Every one right, or each error fixed and re-checked.
3. **Facts carried faithfully** on the same 50: operation, in-force date, affecting law, extent, savings, as the effect states them.
4. **Tested:** the counting and the reasons defined in words, with unit tests.
5. **Repeatable:** two runs give the same report.
