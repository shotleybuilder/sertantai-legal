---
session: 'CV-S05a: Extent Recall Sweep'
status: active
opened: '2026-10-26'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
---

# Session: CV-S05a: Extent Recall Sweep (ACTIVE)

## Problem

The extent catalogue (`Extent.Patterns`) classes only sentences its own detector recognises as extent words, so a wording outside that vocabulary is never seen, counted or flagged. Since round 4 the agent checks have found these by sampling, one at a time; round 6's three NEW defects were all such silent drops ("Subsection (1) does not apply to section …", "The extent of … is the same as that of …"). Jason 2026-10-26: "are we using the agents to randomly find unmatched variation (smack a mole) rather than systematically seeding the patterns like in previous stages?"

Aim: count the whole population of extent-ish sentences in the held amending laws, so every wording is read, counted unread, or shown to be noise, before CV-S05 resumes.

## Todo

- ✅ Define the wide net (signals of extent or application, the law's own words) and what counts as caught (classed by the catalogue)
- ✅ Build the sweep (pure module + test + thin mix task): every own-words sentence matching the net, minus those the catalogue classes; normalise numbers, places and lists, and cluster by shape with counts and examples
- ⬜ Run it over every held amending law (read-only, ~5 min; ask Jason)
- ⬜ Review the clusters with Jason, by count: each a wording to read, a counted unread class, or noise
- ⬜ "Uncaught" as a counted outcome in the catalogue and in `lat.extent_check`
- ⬜ Hand back to CV-S05: the clusters to read (round 6's D1–D3 folded in), and the skill (`extent-reader-check`) updated with the sweep step

## Dependencies

- ✅ CV-S05 round 6 steps 1–3 (`Extent.Unread`: an unread statement withholds its bound), pushed `5e284141`
- ✅ `Extent.ReadCache` (a law's reading and classes kept between runs)
- ✅ `extent-reader-check` skill (`e5a59faf`)

## The net (2026-10-26)

Prototyped on the OH&S amending laws (445) before code. Each version was measured by uncaught sentences and checked against round 6's three known misses:

| Version | Uncaught | Laws | Noise |
|---|---|---|---|
| 1. any "extent/extend", apply + place | 4,178 | 287 | "the extent to which", "extend the period", application forms |
| 2. two nets (A neighbourhood, B strong) | 872 | 163 | "same application has not been lodged", "extends to co-operation", Schedule containers |
| 3. B needs a place or "there/as follows"; "same … as"; idioms out ("as they apply in"); containers skipped | 473 | 97 | net A over provision-level classes |
| 4. A only in a section/regulation/article holding a clause class | **191** | **84** | reviewable |

- **Net A (the clause's neighbourhood):** a sentence in a section, regulation or article holding a classed extent or application clause statement (default, list, part_not, applies, or an in-clause unread), with application/extent/exception words, naming a place or a provision.
- **Net B (strong signals anywhere):**
  - "extend(s) to <place | any part of the UK | the part or parts | that part>", "throughout", "there", "as follows", "accordingly";
  - "the extent of any amendment …";
  - "same (territorial) extent/application (within the UK) as";
  - a provision or the law applying / having effect in, to or in relation to a place.
- **Never:** "to the extent", "extent to which", "any/such extent", "revoked/repealed to the extent", "extend the period", "as it/they apply".
- **Caught:** a classed sentence whole, holding it, or held by it.
- All three round-6 misses are caught: D1 and D3 by A, D2 by B.

## The build (2026-10-26), code `786a63ce`

- `Extent.Sweep` (pure): `uncaught/2`, `net/3`, `shape/1` (quotes, titles, places, provision numbers stood in; the first 14 words), `group/1` (a first guess: outside_uk, outside_gb, same_extent, exception, place, other). There is no commencement guess: the architecture test (CR-06) keeps commencement words to their readers, and adding a helper to `LawStart.Clause` would stale the label and vocabulary versions, so it was reverted.
- Kept in `Extent.ReadCache` (`uncaught`, beside the classes), so warm runs cost nothing and the check can count it (todo 5). `ReadCache.held/0` is shared with `lat.extent_patterns`.
- `mix lat.extent_sweep [--family F | --laws A,B] [--out DIR]` (thin): writes `clusters.json` (shape, count, laws, nets, group, 5 examples) and `sentences.tsv`; prints totals by group and net and the 40 largest clusters. Default out `data/extent_sweep` (git-ignored).
- Tests: `extent/sweep_test.exs` (round 6's sentences caught, idioms not, own words only, shape/group). Suite 8,886.
