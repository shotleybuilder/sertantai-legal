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
- ⬜ EU annex refs converted (`annex-XVII` → a provision we can hold or name): 824 effects, 14 laws
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


## Survey of placement today (2026-10-22, read-only)

OH&S core family, 6,568 effects. `Feed.read` places each effect on its structured refs; one with none usable becomes `"?"`. The reader never checks a target against the rows we hold.

| outcome | effects | laws |
|---|---|---|
| placed on a row we hold | 3,443 | 98 |
| placed on its territorial versions (C3: `s.23[E+W]`) | 261 | 2 |
| target in a schedule; our LAT holds no schedules | 1,704 | 69 |
| refs not converted (EU annexes: `annex-XVII`) | 824 | 14 |
| not in the current CLML (gone, or a grouped ref split wrongly: "reg. 13(2)(a)(vi)(vii)") | 201 | 25 |
| no ref ("C/O", "specified amended provision(s)", "Directive") | 75 | 21 |
| whole law | 53 | 22 |
| in the CLML, not in our LAT | 7 | 3 |

**Decision (Jason 2026-10-22): schedules absent from LAT are a known limit for v0.1.** "We started by not parsing schedules into LAT. Some are huge reference tables. Then two schedule roles we need them for: amending and duties. I don't think selective schedule parsing is done." An effect on a schedule we don't parse is unplaced with that reason, a known limit, not a reader fault.

## Known faults (2026-10-22; Jason: "Fix known faults first, then baseline")

- **EU annexes (824 effects, 14 laws): fixed** (`e0220498`). `Ref.from_clml` converts `annex-XVII` to `annex.XVII`. No law in the DB holds annex rows, so an unparsed annex is the EU form of the schedule limit. My reading of the schedules decision, flagged to Jason.
- **"In the text, not our rows" (7 effects, 3 laws).** Each looked at in the CLML:
  - **NI SR 1997/248 reg.13(2)(b)(i)(aa):** a P5 item, deeper than our rows. Its words sit inside row `reg.13(2)(b)(i)`, so the change belongs there, but the fold never sees a change on `(aa)`. **Policy for Jason:** move a target deeper than our rows to its nearest held ancestor, as a words change? (C9, "a child's change never versions its parent", was written for children with their own rows.)
  - **EU 1989/391 Article 17 and REACH Article 127EA:** in the CLML with text, but the LAT parse made no row (the row made is `art.Article 17a`). A LAT parse bug, not the feed reader's.
  - **"(bb)" in the same NI effect:** legislation.gov.uk's own structured ref is `regulation-13-2-bb` (under 13(2), not 13(2)(b)(i)). The feed's error, faithfully read, so "not in the text"; noted for CV-S08.
