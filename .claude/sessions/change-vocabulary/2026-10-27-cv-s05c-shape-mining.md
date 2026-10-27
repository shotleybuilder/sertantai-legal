---
session: 'CV-S05c: Shape Mining'
status: active
opened: '2026-10-27'
parent: change-vocabulary/2026-10-27-cv-s05b-list-shape-audit.md
---

# Session: CV-S05c: Shape Mining (ACTIVE)

## Problem

Extent list wordings form a long tail: a few common shapes and many rare ones. CV-S05's agent check samples 50 laws at a time, so each round turns up a few rare wordings it hadn't seen. NEW counts by round: 16, 11, 5, 5, 8, 3, 6, 6, 1, 3. That is a discovery curve, and it won't reach zero quickly.

Aim (Jason 2026-10-27: "I thought it was a long tail problem"): stop sampling and list the whole tail. Reduce every list item in the corpus's extent sentences to a shape by masking numbers and names, for example "PART_REF, other than SCH_PARA_REF". Then count and rank the shapes, and review each shape once, so fixes go by count.

## Todo

- ✅ Prototype (script, read-only): mask and split the items of the 3,039 extent sentences, count and rank the shapes, and show the rare ones with examples. Ask Jason before running it.
- ✅ Store each run as evidence (run-01 committed, but inside the other lane's 30cebd9a "fix(frontend): clear 32 ESLint errors": it swept up my staged files; with Jason) (Jason 2026-10-27): `backend/data/experiments/cv-s05c-shape-mining/<run>/` holds a manifest (commit, ReadVersion, input counts and digests, command, date), the script as run, the input sentences and the ranked shapes with examples. Commit with `git add -f`, scanning for effect ids first
- ✅ Check that the round 9 and round 10 NEW wordings appear in the tail the prototype finds
- ✅ Measure the tail: the shape counts, the singletons, and an unseen-shape estimate (Good–Turing / Chao1)
- ✅ Mark the shapes the reader already reads, so review skips them (step 2: per-item verdicts)
- ⬜ Confirm the 33 drops (`run-01/dropped.tsv`) against the law text; hand the confirmed ones to CV-S05 round 11
- ⬜ STAGED for later: shape review of the qualified tail (`run-01/review.tsv` buckets `read_qualified`, `misread_qualified`, then `in_unread`), most common first, with Jason; hand the ranked shapes to CV-S05 round 11
- ⬜ If it earns its place, build it as a read-only mix task with pure modules and tests

## Run-01 (2026-10-27)

The evidence is in `backend/data/experiments/cv-s05c-shape-mining/run-01/`: manifest, scripts, input, outputs and README (4.6 MB, no effect ids). It is not committed yet. The dump took 3 s from the read cache, and mining took seconds.

- **Population:** 3,039 extent sentences from 1,338 laws. They hold 1,825 list items, 510 list leads and 2,264 whole sentences (all excluding class `none`).
- **The tail is long and real:**
  - list items: 884 shapes, 801 of them in one law only; 51% of items are in a one-law shape;
  - sentences: 1,257 shapes, 1,070 in one law only.

  This is why each 50-law sample finds new wordings. The run is a census, so within the corpus every shape is listed.
- **Round 10's list wordings all show up as one-law tail shapes:**
  - `PART (DESC), other than PARA of SCH`
  - `in CHAPTER of PART, SECS (DESC)`
  - `in PART, CHAPTERS of PART and SEC`
  - `THIS_PART (other than …, except as …)`
  - `THIS_CHAPTER` (2 laws)
- **R10 NEW-1 (SI 2014/1638) is a lost lead:** 9 laws have a list sentence beginning "—a …", with the lead dropped before the reader sees it. This is a new finding, not yet traced.
- **Round 9's default-clause misread** sits in a common shape (11 laws). It is not a wording fault, so shape mining can't find it, as expected.
- **Limits:** splitting relies on flattened letters, masking is regex, and the reader's class is per sentence, not per item.

## Run-01 step 2: per-item verdicts (2026-10-27)

`verdicts.exs` checks each item against the stored lists, using the reader's own subject parse; `review.py` buckets the shapes; `dropped.tsv` holds the candidates. Details are in the run README.
- Items in lettered sentences: 2,271. Of those, 801 are read, 34 withheld and 96 not held. The rest name another law or nothing parseable, or have no list statement.
- **Skippable:** 67 plain shapes (355 items) are read every time.
- **Drops:** 33 provisions in 33 laws have a sentence the reader classes as a list with an item dropped. In 17 a plain item is dropped; in 16 it is a qualified one ("so far as", "other than", …).
- **Finding:** the drops are **not** in rare item shapes. They are common items ("SEC", "SECS") dropped inside particular sentences, so for drops the unit to review is the sentence. The tail matters for misreads of meaning (round 10's "other than" or "in Chapter 1 of Part 6, sections …"), which a "held or not" check can't see.
- **Spot-checked as real drops:** ukpga 2015/7 s.56, 2020/16 s.24, 2025/18 s.141, 1972/11 s.30, 1989/15 s.194 and 1994/21 s.68. uksi 2019/696 reg.3 is doubtful.

## Dependencies

- ✅ CV-S05a recall sweep (closed): the population of extent sentences
- ✅ CV-S05 catalogue (`Extent.Patterns`, `Extent.Credit`) and stored `extent_rules`
- ⏸️ CV-S05b List Shape Audit (suspended): resumes once this session has listed the tail
