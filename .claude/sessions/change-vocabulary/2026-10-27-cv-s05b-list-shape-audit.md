---
session: 'CV-S05b: List Shape Audit'
status: suspended
opened: '2026-10-27'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
---

# Session: CV-S05b: List Shape Audit (SUSPENDED)

> **Suspended 2026-10-27** for CV-S05c Shape Mining (`2026-10-27-cv-s05c-shape-mining.md`). Jason: the problem is a long tail, not a testing problem, so the research below was framed the wrong way (as the test oracle problem). Left as written, by Jason's choice. Resume once CV-S05c has listed the tail; the choice of technique is still open.

## Problem

CV-S05's agent check finds rare list wordings a few at a time. Each fresh 50-law sample turns up new ones, and the NEW counts by round are 16, 11, 5, 5, 8, 3, 6, 6, 1, 3. Round 10's examples:
- an unbracketed "Part 4 …, other than paragraph 1 of Schedule 8" read as an item;
- "in Chapter 1 of Part 6, sections 165, 166 and 186" read as the whole Chapter;
- "(v) this Chapter" dropped (ukpga 2009/23 s.323, ukpga 2017/3 s.182(2)).

CV-S05a's recall sweep fixed this for sentences the catalogue never saw. It does not cover sentences the catalogue does see and the reader reads only partly or wrongly.

Aim (Jason 2026-10-27: "find the technique/algorithm as the audit tool — a step back from researching our own data"): choose, from known methods, a technique that systematically finds the reader's misreads and partial reads of extent lists across the whole corpus. Build it as an audit tool that counts them by shape, so fixes go by count and the agent check becomes a final confirmation.

## Todo

- ✅ Research: candidate techniques, each with how it would find a misread here, what it misses, and its cost (see "Candidates" below)
- ⬜ Choose one (or a pairing) with Jason; write down what it counts and how a finding is confirmed
- ⬜ Prototype by count on OH&S, then the corpus, before writing modules (CV-S05a's lesson); check that it catches round 10's three NEW and round 9's
- ⬜ Build the audit (read-only mix task + pure modules + tests); shapes ranked by count, examples per shape
- ⬜ Hand the ranked shapes to CV-S05 round 11; record the baseline

## Candidates (to research; not yet chosen)

- **Differential reading (an independent second reader):** a deliberately simple extractor that takes every provision mentioned in an extent sentence. It is compared with what the reader stored for that sentence. A mention in neither a list nor an unread row is a drop; a stored ref the sentence doesn't mention is an over-reach. Disagreements are candidates, not verdicts. (Software testing: differential / N-version testing.)
- **Invariants checked on every sentence (metamorphic / property checks):** rules that must hold whatever the wording. Each provision named goes somewhere; nothing named after "other than" or "except" is read into the same list; a list never holds more provisions than the sentence names. A violation is a finding.
- **Shape mining (template clustering):** mask numbers and names so items reduce to shapes ("PART_REF, other than SCH_PARA_REF"). Then cluster them, count them and sort by frequency (log-template mining, e.g. Drain). Rare shapes are where misreads hide, and each shape is reviewed once.
- **A model as oracle on every list sentence:** the agent check's judgement applied to all list sentences, not a 50-law sample. It costs more, and it needs its own confirmation step.

## Research (2026-10-27)

**The problem has a name.** Software testing calls it the *test oracle problem*: there is no correct answer to compare each output with. Our agent check is a sampled oracle, so it finds misreads 50 laws at a time. The standard answers to the problem are the candidates above. Each one replaces the per-sentence correct answer with something cheaper that can be checked on every sentence.

Population: the catalogue's 3,039 extent sentences across 3,358 laws, held offline. All four techniques run read-only over it.

| Technique | Signal of a misread | Round 9–10 NEW it would catch | What it misses | Cost |
|---|---|---|---|---|
| Differential (second reader; McKeeman 1998) | the naive reader's mentions ≠ the stored lists | "(v) this Chapter" dropped; "Chapter 1 of Part 6, sections …" over-reach; SI 2014/1638 Sch.13 drop | wrong place or kind with the right refs; faults both readers share (so the naive one must not reuse `RefList`'s list logic) | seconds per run; the noise is mentions that aren't items (other Acts, "subject to subsection (7)"), and that needs a filter |
| Invariants (property / metamorphic; Chen 1998) | a rule broken: every mention lands; nothing after "other than / except" in the same list; list ⊆ mentions; places in list ⊆ places in sentence | all three round 10 list NEW, including the unbracketed "other than" | which clause is the default (round 9's 2002/30 s.108); meaning | seconds; each rule is a few lines, and a hit names the rule broken |
| Shape mining (template clustering; Drain, He et al. 2017) | a rare shape, or one shape read different ways | rare item shapes ("PART, other than SCH_PARA"); inconsistent reads in a shape | a common shape misread the same way every time, unless each shape is reviewed once | seconds; then review per shape (expect a few hundred), ranked by count |
| Model as oracle (LLM-as-judge) | the model's reading ≠ ours | in principle all, including meaning | it is unreliable itself, so it needs confirmation; it is not repeatable | tokens across ~3,000 sentences; needs Jason's OK; best kept for the residue |

**Overlap.** Differential and invariants are almost the same thing: "every mention lands somewhere" is the differential check written as a rule. Shape mining is a different axis. It does not find misreads; it groups them so fixes go by count, which is CV-S05b's aim.

**Recommendation: a pairing.**
1. Invariants find the misreads. They need a naive mention extractor, which is the differential reader.
2. Shape mining groups and ranks them. Each violation is filed under its item shape, and shapes are ranked by count. A shape whose members read differently is flagged even when no rule fails.
3. The agent check stays as the final confirmation. A model pass over the residue is optional later, by count.

What it won't catch: a wrong choice of default clause, and the wrong place on a correct ref. Both stay with the agent check.

## Dependencies

- ✅ CV-S05a recall sweep (closed): the population of extent sentences and their forms
- ✅ CV-S05 catalogue (`Extent.Patterns`, `Extent.Credit`) and stored `extent_rules`
