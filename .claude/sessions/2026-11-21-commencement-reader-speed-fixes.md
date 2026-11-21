---
session: Commencement Reader Speed Fixes
status: active
opened: 2026-11-21
---

# Session: Commencement Reader Speed Fixes (ACTIVE)

## Problem

The code review (`backend/data/code-reviews/commencement-reader-code-review.md`) found the Commencement reader's runs doing the same work again and again. One law (2003 c.21) costs 86 s a check because a range position map is rebuilt on every test. Every clause is read twice in a `--fresh` check. Each law's CLML is gunzipped and parsed again and again (9–15 s a large law). Jason (2026-11-21, Decision 1 (a)): fix the code first, then the step resumes on the new loop. The session makes the fixes; Fable only as a last resort, on Jason's approval with reasons.

## Todo

- ✅ Plan mode: approved 2026-11-21 (`/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`); no timing baseline (Jason: "the baseline is unacceptably slow - that's good enough"); every Taken finding in, none parked
- ✅ Before: a `--laws` `--fresh` check snapshot of about 20 laws covering each path, at HEAD 6ea6045b
- ✅ 1 The range position map built once (`OwnClause.context/1`, `LatRef.positions/1`)
- ✅ 2 One `OrderRead`, as `OwnRead` (`--read-orders`, the `--fresh` check, the gate)
- ✅ 3 CLML parsed only when needed (`OwnRead`; the Schedules file once per law in `Input.of`)
- ✅ 4 One reading per law, order and amender, shared by the `--fresh` check and the leftovers gate
- ✅ 5 The catalogue stays warm: CLML laws keyed on file digests, one reach query, `Order`'s ref helpers moved out of the catalogue version
- ✅ 6 The tasks' shared logic in one place each (rows query, the Act an order commences, `held?`, the unused amending-laws query, per-law queries)
- ✅ 7 Regexes compiled once (`order.ex`, `order/asides.ex`, `law_start/clause.ex`)
- ✅ 8 `Leftovers` split: the reading and the review bookkeeping
- ⬜ Proof: the `--laws` check diffed with the before (only fixes 2 and 4's intended differences), both catalogues no new pattern, full suite, Dialyzer
- ⬜ Close: commits by path, the timings, WORKFLOW step 4 and the skill's run times

## Dependencies

- ✅ The code review and its triage (`.claude/sessions/2026-11-21-commencement-reader-code-review.md`)
- ✅ Waste, Water and Climate: Commencement reader suspended after Settle (pushed 0aff4832); it resumes after this session

## Probes to beat (2026-11-21, `scratchpad/review/probe.txt` in the review session)

| Law | Rows | Rules | Clause read | `Check.rows` | Gate's second read |
|---|---|---|---|---|---|
| 2003 c.21 | 3,967 | 1,532 | 15.3 s | 85.9 s | 1.1 s |
| 1991 c.56 | 8,308 | 19 | 9.4 s | 0.4 s | 3.2 s |

## Before (2026-11-21, HEAD 6ea6045b)

19 laws, `mix lat.commencement_check --laws … --all --fresh`, output and reports in the scratchpad (`speed/before*`): 317 s, 1.8 GB; our faults 0, 3 leftovers not named (all `check: open`).
- Ranges: 2003 c.21, 2024 c.13. Large: 1991 c.56, 1991 c.57, NISI 2006/3336, SI 2024/1332. Scoped: asp 2013/5, 1975 c.23, 1996 c.38. Orders: 2010 c.29, 1974 c.40, 2014 c.21, 2003 c.37, 1989 c.15, 1999 c.24. Amenders: 1991 c.59, 1980 c.45. Small: SI 2012/2079. EU: EUR 2016/879.
- No snapshot law uses "the day appointed for the purpose of" (the one held, the Gas Act 1995, has no LAT rows), nor a Schedule redirect (SI 1989/2169 has none): fix 2's difference is proved by `order_read_test.exs`.

## Fixes 1–4 (commits 3566ff77, a84bed9e, 3c3e315f, cff75f97, e6e91a0a)

- The 19-law check after fix 4: **output and all three reports identical** to the before; 190 s, 2.0 GB.
- A regression found by it and fixed (cff75f97): fix 1 dropped the context's order list, which `OwnCommencement` reads for a heading's or Part's members (2010 c.29 pt.3 read as not reached). Its tests build the context by hand, and the per-fix test set left out `change_vocabulary/`; that folder is now in every per-fix run (6,573 tests, about 1 min).
- The first fix 4 held every law's readings (parsed documents) until the gate: 3.7 GB on 19 laws. Now each law's leftover items are taken as it is read, and no reading is held past its law.
- A fourth order reader found: `lat.commencement --read-amending`'s cited orders, now through `OrderRead` too.

## Fixes 1 (more), 5–8 (commits e3274a07, 259c79ae, 3f5d046a, be8d383d, 913623a2, 5ac5df28)

Probed after fix 4 (`speed/probe2.exs`): the time had moved to the amending laws' reads.

| Law | Clause read | `Check.rows` | Its amending laws read |
|---|---|---|---|
| 2003 c.21 | 13.3 s | 13.8 s (86 s before fix 1) | none |
| 1991 c.56 | 2.0 s (9.4 s before) | 0.3 s | 107 s for 368 laws |
| 1974 c.40 | 0.4 s | 0.5 s | 55 s for 326 laws |

- **The evaluator** (e3274a07) scores each rule once a provision: 2003 c.21's `Check.rows` from 13.8 s to 6.2 s. That misses the plan's target of under 2 s. The rest is every rule's refs tested against every row. An index of rules by provision would be exact (`covers?` is equality except for ranges), but it changes the evaluator's interface, which the label build shares, to save about 4 s on the one law over 1,500 rules. Not done.
- **Fix 5** (259c79ae, 3f5d046a):
  - A law's CLML rows (`ClmlRows`) are cached on its files' digests and `ClmlRows.Version`, which covers only `DocRows`, `ClmlRef` and the document.
  - Own and amending readings are cached under `Commencement.ReadVersion`, with their inputs. A reader fix re-reads every law; a re-run with no reader change re-reads none.
  - The catalogue's reach is one grouped query.
  - The catalogue's version no longer covers `order.ex`. The ref reader moved to `TextRefs`, and the order units' checks moved to `OrderLeftovers` and `OrderMisreads`. The plan named only `Order.ref`, `own_schedule_refs` and `Asides`, but `Leftovers` and `Misreads` reached `Order` through the order units as well.
- **Fix 6** (be8d383d): one query for the amending laws cited without LAT; the LAT-rows query through `Input.rows/1`; the Act through `Orders.act/1`. `held?` was two questions, now two names (`text_held?`, `body_held?`). They differ on one law, 1959 c.24, held only as section fragments, so merging them would have changed the catalogue.
- **Fix 7** (913623a2): 15 constant interpolated regexes became attributes. Measured on OTP 29: an attribute costs what a literal does; an interpolated regex about 1.5 µs more a call.
- **Fix 8** (5ac5df28): `Leftovers` was three concepts. Each leftover's reviewed status and the family gate moved to `LeftoverGate`; groups ranked by reach moved to `ReachGroups`. Delegates stay for the other steps' checks that use the groups.
- The 19-law check after fix 5: identical to the before; 140 s cold, 47 s warm, 0.45 GB.
- Version hashes moved, as planned: `Commencement.ReadVersion`, `FoldVersion`, the change-vocabulary version, the three catalogues' versions, and the extent reader's `ReadVersion` (`order.ex` changed). The resumed step's rebuild covers the build's; the extent reader's cache re-reads on its next pass.

## Parking list

- Extent reader, Amending-law reader, Merge, Evidence: their checks call `Leftovers.add/ranked/summary` (now delegates to `ReachGroups`); move them to `ReachGroups` when each step reopens.

