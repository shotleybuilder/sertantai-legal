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

- ⬜ Define the wide net (signals of extent or application, the law's own words) and what counts as caught (classed by the catalogue)
- ⬜ Build the sweep (pure module + test + thin mix task): every own-words sentence matching the net, minus those the catalogue classes; normalise numbers, places and lists, and cluster by shape with counts and examples
- ⬜ Run it over every held amending law (read-only, ~5 min; ask Jason)
- ⬜ Review the clusters with Jason, by count: each a wording to read, a counted unread class, or noise
- ⬜ "Uncaught" as a counted outcome in the catalogue and in `lat.extent_check`
- ⬜ Hand back to CV-S05: the clusters to read (round 6's D1–D3 folded in), and the skill (`extent-reader-check`) updated with the sweep step

## Dependencies

- ✅ CV-S05 round 6 steps 1–3 (`Extent.Unread`: an unread statement withholds its bound), pushed `5e284141`
- ✅ `Extent.ReadCache` (a law's reading and classes kept between runs)
- ✅ `extent-reader-check` skill (`e5a59faf`)
