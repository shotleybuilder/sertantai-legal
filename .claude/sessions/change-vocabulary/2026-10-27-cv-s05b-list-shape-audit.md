---
session: 'CV-S05b: List Shape Audit'
status: pending
opened: '2026-10-27'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
---

# Session: CV-S05b: List Shape Audit (PENDING)

## Problem

CV-S05's agent check finds rare list wordings a few at a time. Each fresh 50-law sample turns up new ones, and the NEW counts by round are 16, 11, 5, 5, 8, 3, 6, 6, 1, 3. Round 10's examples:
- an unbracketed "Part 4 …, other than paragraph 1 of Schedule 8" read as an item;
- "in Chapter 1 of Part 6, sections 165, 166 and 186" read as the whole Chapter;
- "(v) this Chapter" dropped (ukpga 2009/23 s.323, ukpga 2017/3 s.182(2)).

CV-S05a's recall sweep fixed this for sentences the catalogue never saw. It does not cover sentences the catalogue does see and the reader reads only partly or wrongly.

Aim (Jason 2026-10-27: "find the technique/algorithm as the audit tool — a step back from researching our own data"): choose, from known methods, a technique that systematically finds the reader's misreads and partial reads of extent lists across the whole corpus. Build it as an audit tool that counts them by shape, so fixes go by count and the agent check becomes a final confirmation.

## Todo

- ⬜ Research: candidate techniques, each with how it would find a misread here, what it misses, and its cost (see "Candidates" below)
- ⬜ Choose one (or a pairing) with Jason; write down what it counts and how a finding is confirmed
- ⬜ Prototype by count on OH&S, then the corpus, before writing modules (CV-S05a's lesson); check that it catches round 10's three NEW and round 9's
- ⬜ Build the audit (read-only mix task + pure modules + tests); shapes ranked by count, examples per shape
- ⬜ Hand the ranked shapes to CV-S05 round 11; record the baseline

## Candidates (to research; not yet chosen)

- **Differential reading (an independent second reader):** a deliberately simple extractor that takes every provision mentioned in an extent sentence. It is compared with what the reader stored for that sentence. A mention in neither a list nor an unread row is a drop; a stored ref the sentence doesn't mention is an over-reach. Disagreements are candidates, not verdicts. (Software testing: differential / N-version testing.)
- **Invariants checked on every sentence (metamorphic / property checks):** rules that must hold whatever the wording. Each provision named goes somewhere; nothing named after "other than" or "except" is read into the same list; a list never holds more provisions than the sentence names. A violation is a finding.
- **Shape mining (template clustering):** mask numbers and names so items reduce to shapes ("PART_REF, other than SCH_PARA_REF"). Then cluster them, count them and sort by frequency (log-template mining, e.g. Drain). Rare shapes are where misreads hide, and each shape is reviewed once.
- **A model as oracle on every list sentence:** the agent check's judgement applied to all list sentences, not a 50-law sample. It costs more, and it needs its own confirmation step.

## Dependencies

- ✅ CV-S05a recall sweep (closed): the population of extent sentences and their forms
- ✅ CV-S05 catalogue (`Extent.Patterns`, `Extent.Credit`) and stored `extent_rules`
