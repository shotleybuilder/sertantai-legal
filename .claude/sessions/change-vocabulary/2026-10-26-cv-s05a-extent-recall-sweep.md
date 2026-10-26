---
session: 'CV-S05a: Extent Recall Sweep'
status: closed
opened: '2026-10-26'
closed: '2026-10-26'
outcome: success
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md

summary: >
  The extent catalogue only saw wordings in its own vocabulary, so CV-S05's agent rounds kept finding silent drops by
  sampling. A recall sweep (Extent.Sweep, mix lat.extent_sweep) now collects every own-words sentence that may say where
  provisions extend or apply and that the catalogue misses: 551 in 305 of 3,358 laws, sorted by reviewed form
  (AmendingLaw.SweepForm) into 83 to read, 25 to count and the rest noise, and counted in the catalogue and lat.extent_check
  (OH&S: 29 to read, listed as misses).

decisions:
  - what: Two nets, the clause's neighbourhood (A) and strong signals anywhere (B), idioms excluded, prototyped by count before code
    why: one wide net gave 4,178 sentences, mostly idioms ("the extent to which", "extend the period"); each refinement was measured and checked against round 6's three known misses
    result: 191 on OH&S (84 laws), all three misses caught; 551 corpus-wide
  - what: Uncaught kept in Extent.ReadCache beside the classes; the forms in a separate module outside the reading's version
    why: warm runs cost nothing and the check counts per law; relabelling forms must never stale every reading
    result: lat.extent_sweep, lat.extent_patterns and lat.extent_check all report uncaught by form
  - what: Provision-level application ("Regulation 44 applies to Scotland only", "This paragraph applies in relation to England only") is read, not counted (Jason, "a")
    why: plain, few forms; leaving them unread would withhold territory from ~40 laws that state it
    result: read:application, 52 sentences in 33 laws, handed to CV-S05 round 7
  - what: No commencement guess by a new regex in the sweep; commencement noise through LawStart.Clause's own public readers
    why: the architecture test (CR-06) keeps commencement words to their readers; a helper in LawStart.Clause would stale the label and vocabulary versions
    result: the reverted helper; noise:commencement 80

metrics:
  sweep: { laws: 3358, uncaught: 551, laws_with: 305, shapes: 481, run: "6 min 58 s, 4 workers" }
  forms: { to_read: 83, read_application: 52, read_same_extent_of: 12, read_also_there: 7, read_exception: 6, read_same_extent: 5, read_lettered: 1, count_qualified: 17, count_outside_gb: 8, noise: 443 }
  ohs_check: { uncaught: 156, laws: 66, to_read: 29 }
  net_prototype_ohs: { v1: 4178, v2: 872, v3: 473, v4: 191 }

lessons:
  - title: A catalogue built from the reader's own vocabulary can't measure its recall
    detail: The extent catalogue classed only sentences its detector recognised, so wordings outside it were neither read nor counted, and five agent rounds found them one by one. Count the population with a wider, independent net first, then subtract what the catalogue classes.
    tag: data
  - title: Prototype a net by count before writing the module
    detail: Four scratch versions over the OH&S laws took 4,178 sentences to 191 with the known misses held as a test; each noise class was seen in the output before it was excluded.
    tag: tooling
  - title: Shapes are too fine to review; forms are the unit
    detail: 551 sentences gave 481 shapes, mostly singletons. Sorting by hand-checked rules into forms (read, count, noise), with a residual read one by one, made the review a table of counts.
    tag: data

artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/extent/sweep.ex
  - backend/lib/sertantai_legal/scraper/amending_law/sweep_form.ex
  - backend/lib/mix/tasks/lat.extent_sweep.ex
  - backend/lib/mix/tasks/lat.extent_check.ex
  - backend/lib/mix/tasks/lat.extent_patterns.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/read_cache.ex
  - backend/test/sertantai_legal/scraper/amending_law/extent/sweep_test.exs
  - backend/test/sertantai_legal/scraper/amending_law/sweep_form_test.exs
  - .claude/skills/extent-reader-check/SKILL.md

depends_on:
  - 2026-10-22-cv-s05-extent-reader

enables:
  - CV-S05 round 7 — read the read:* forms (83 corpus, 29 OH&S); pass needs none uncaught in a read form
---

# Session: CV-S05a: Extent Recall Sweep (CLOSED)

## Problem

The extent catalogue (`Extent.Patterns`) classes only sentences its own detector recognises as extent words, so a wording outside that vocabulary is never seen, counted or flagged. Since round 4 the agent checks have found these by sampling, one at a time; round 6's three NEW defects were all such silent drops ("Subsection (1) does not apply to section …", "The extent of … is the same as that of …"). Jason 2026-10-26: "are we using the agents to randomly find unmatched variation (smack a mole) rather than systematically seeding the patterns like in previous stages?"

Aim: count the whole population of extent-ish sentences in the held amending laws, so every wording is read, counted unread, or shown to be noise, before CV-S05 resumes.

## Todo

- ✅ Define the wide net (signals of extent or application, the law's own words) and what counts as caught (classed by the catalogue)
- ✅ Build the sweep (pure module + test + thin mix task): every own-words sentence matching the net, minus those the catalogue classes; normalise numbers, places and lists, and cluster by shape with counts and examples
- ✅ Run it over every held amending law (read-only, ~5 min; ask Jason)
- ✅ Review the clusters with Jason, by count: each a wording to read, a counted unread class, or noise
- ✅ "Uncaught" as a counted outcome in the catalogue and in `lat.extent_check`
- ✅ Hand back to CV-S05: the clusters to read (round 6's D1–D3 folded in), and the skill (`extent-reader-check`) updated with the sweep step

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

## The run (2026-10-26, Jason: "VM is closed. Use the cores for the full run")

- `mix lat.extent_sweep`: 3,358 laws, **6 min 58 s** (4 workers: the guard's memory limit at ~1.8 GB a law with 6 GB kept, not the core count).
- **Uncaught: 551 sentences in 305 laws, 481 shapes.** Shapes are too fine (mostly one sentence each), so every sentence was sorted by hand-checked rules into forms (scratch `forms.py`; 111 residual read one by one).

## The forms, by count (for review with Jason)

| # | Form | Sentences | Laws | Proposed |
|---|---|---|---|---|
| 1 | "The extent of any amendment/repeal … is the same as that of the enactment …" (ukpga 2000/6, 2002/17, 2004/5, 2007/28 s.244(3), SI 2002/3135, SI 2008/912 …) | 12 | 11 | **read**: same (the provisions named, else `*`) |
| 2 | "has the same extent (in the UK / and application) as" variants (ukpga 2018/12 s.214, 2020/17 s.414 lettered, SI 2018/942 "a provision that amends …") | 3 | 3 | **read**: same |
| 3 | an exception to an extent subsection: "Subsection (1) does not apply to section 59(3), 90 …" (Courts Act 2003 s.111(2), SOCPA s.179, 2000/43, 2013/22, 2016/19, 2020/22) | 7 | 7 | **read** as unread for the provisions excepted (bound withheld) |
| 4 | amendments "also extend there" / "to any place to which the enactments they amend extend" (ukpga 1999/24 s.7 ×2, SI 2007/1843) | 3 | 2 | **read**: same (+ "except Scotland": not S) |
| 5 | lettered places after "only": "This Act extends only to— (a) England and Wales, and (b) Scotland" (ukpga 2006/3 s.94) | 1 | 1 | **read** (`unlettered` misses "only") |
| 6 | a provision's own application to a place: "Regulation 44 applies to Scotland only", "This paragraph applies in relation to England only", "Subsection (7) applies to Scotland only", "does not apply in relation to Wales", "Paragraph 20 … extends and applies to England and Wales only" | ~55 | ~38 | **decision for Jason**: read as provision-level application (a bound on the territory of the changes those provisions make), or count unread |
| 7 | lists of provisions applying to a place: "The following provisions apply in relation to England only— (a) articles 6, 7 and 11; …" (SI 2009/462, 2018/942, 2025/361) | 3 | 3 | with 6 |
| 8 | the amendments made by … apply to a place (SI 2013/235 sch.2 para 28, SI 2014/1638 reg.3(?)) | 2 | 2 | with 6 |
| 9 | qualified: "Section 158 extends— (a) to Scotland, so far as …"; "Nothing in subsection (1) affects the extent of …"; "Section 119(1), so far as it relates to …, extends to any place to which that provision extends" | ~8 | ~6 | **count** unread (provisions named withheld) |
| 10 | application outside Great Britain (the HSWA 1974 Application outside GB Order) | 8 | 8 | **count** (no UK territory effect) |
| N1 | commencement sentences in the extent clause's section | 105 | 96 | noise |
| N2 | the Isle of Man, Channel Islands, overseas territories, "any other jurisdiction" | 77 | 49 | noise (outside the UK) |
| N3 | words of an amending instruction ("as it extends to", "as it has effect in", "for … substitute") | 56 | 32 | noise (another law's territorial versions) |
| N4 | procedure, definitions, powers, the Crown, territorial waters, NI Act 1974 Orders in Council | ~50 | ~41 | noise |
| N5 | application to cases or persons, not places ("These Regulations do not apply to water which …") | ~30 | ~24 | noise |
| N6 | modifications ("… has effect in relation to Wales as if …", "applies to Scotland with the substitution …") | ~10 | ~9 | noise (modification, not territory) |
| N7 | other laws' amendments having effect in a place (WSI 2002/3188 GMO), pointers ("Subsection (1) is subject to subsections (3) to (6)"), the rest | ~110 | ~70 | noise |

- Readable statements total about 26 sentences (forms 1–5), plus about 60 of provision-level application (6–8). About 16 are to count (9–10); about 430 are noise.
- Round 6's three are in forms 1 and 3.

## Decision (2026-10-26, Jason: "a, read them as provision-level application")

- Form 6–8, a provision's own application to a place (~60 sentences, ~40 laws), will be **read as provision-level application**: the changes those provisions make take that territory, as the law-level application clause does now. To be implemented in CV-S05's next round, with forms 1–5.

## Uncaught counted, and the hand-back (2026-10-26), code `0513c276`

- `AmendingLaw.SweepForm`: the reviewed forms as rules, tested with a real sentence each. It is kept outside the reading's version, so relabelling never stales a reading. Commencement noise goes through `LawStart.Clause.general?/mention?`.
- Fixes after the first labelling: "does not apply to regulations which apply only in relation to England" is procedure, not an exception or application; conditional applications ("where", "if", "as follows", "on Sundays") are counted, not read; an exception list after a dash ("does not apply to— (a) …") is read.
- Counted in `lat.extent_sweep` (to read: 83), `lat.extent_patterns` (a line after the catalogue) and `lat.extent_check` (OH&S: 156 uncaught in 66 laws; **29 in a read form, each listed as a miss**).
- Re-run: the same 551; by form, read:application 52, same_extent_of 12, also_there 7, exception 6, same_extent 5, lettered 1; count 25; noise 443.
- One doubtful label to settle in round 7: ukpga 2014/22 s.76 (a power-extension rider) as `read:also_there`.
- The skill `extent-reader-check` has the sweep as step 0, and the pass needs no uncaught sentence in a `read:` form.
- Hand-back to CV-S05: round 7 reads the `read:*` forms (provision-level application per Jason's "a"), folding in round 6's D1–D3 (all in these forms).
