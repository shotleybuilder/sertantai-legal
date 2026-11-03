---
session: 'CV-S05c: Shape Mining'
status: closed
opened: '2026-10-27'
closed: '2026-10-27'
outcome: success
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md

summary: >
  The extent list wordings were treated as a long tail: a census of all 3,039 extent sentences
  (1,338 laws), masked to shapes, counted and ranked, then each list item was checked against the
  reader's stored lists. 33 laws have a drop (29 real, in classes A to E), 4 more hold excluded
  provisions (class F), and the unread tail (757 shapes, 714 in one law only) has one rule worth
  writing. All of it is handed to CV-S05 round 11, with run-01 committed as the baseline evidence.

decisions:
  - what: Treat the misreads as a long-tail problem and take a census, not a sample (shape mining)
    why: "Jason: 'I thought it was a long tail problem'; sampling 50 laws a round kept finding new wordings"
    result: "every shape is listed; about half of list items are in a one-law shape (Good-Turing unseen 0.39 if sampled)"
  - what: Store every run as evidence in backend/data/experiments/<session>/<run>/ (manifest, scripts, input, outputs), on GitHub and the NAS
    why: Jason wanted the experiment to be evidenced later
    result: run-01 is 5.5 MB; no effect ids
  - what: Check each item against the stored lists, and the over-reach rules, rather than reviewing shapes by eye
    why: misreads turned out to sit in common item shapes inside particular sentences, not in rare shapes
    result: 33 drop candidates (29 real) and 14 over-reach hits (5 real, 1 of them already known)

metrics:
  census: { sentences: 3039, laws: 1338, list_items: 1825, item_shapes: 884, one_law_item_shapes: 801 }
  item_verdicts: { items: 2271, read: 801, withheld: 34, not_held: 96 }
  confirmed: { drop_laws: 29, not_drops: 4, overreach_laws: 5, overreach_false: 4 }
  unread_tail: { occurrences: 920, shapes: 757, one_law: 714 }

lessons:
  - title: Drops hide in common item shapes, not in rare ones
    detail: >
      Shape counts at item level did not separate the misreads: "section N" was dropped inside
      particular sentences. The item-against-stored-lists check found them. The long tail matters
      for misreads of meaning (exceptions, scope), which need rule checks rather than a held/not-held check.
    tag: data
  - title: A census beats a sample for a long tail
    detail: >
      Agent checks found misreads 3 to 16 at a time. A census of every sentence (seconds to minutes
      from the read cache) found 33 laws of drops in one pass, and it re-found round 10's NEW.
    tag: tooling
  - title: The git index is shared with the other lane
    detail: >
      My staged run-01 files were swept into the other lane's commit 30cebd9a. Stage and commit
      in one command with a pathspec (`git add -f X && git commit -- X`), and check the index first.
    tag: tooling
bugs:
  - pattern: "Extent lists: \"In Part N— (a) X extends to P, (b) Y extends to Q\": only item (a) read; later items with their own statement dropped"
    category: extent
    module: Extent.Lists / Units
    affected: 6
    fix: "read every lettered item that states its own extent (2015/7 s.56, 2020/16 s.24, 2025/18 s.141, 2006/16 s.108, 1999/9 s.17, 2010/29 s.49); CV-S05 round 11"
    status: open
  - pattern: "Extent lists: an item with its own exception (\"X except Y\", \"X (except Y)\", \"(with the exception of Y)\") dropped whole; 2009/23 Part 2 'other than' read inverted"
    category: extent
    module: Extent.Lists / Excepting
    affected: 11
    fix: "read X less Y (as Excepting does for Part leads); CV-S05 round 11"
    status: open
  - pattern: "Extent lists: plain provisions with a qualified companion (\"Parts 1 and 2 of Sch 7 and section 73 so far as relating to those Parts\", \"…, and those paragraphs\") dropped with it"
    category: extent
    module: Extent.Lists / Credit
    affected: 5
    fix: "read the plain provisions; withhold only the qualified one; CV-S05 round 11"
    status: open
  - pattern: "Extent lists: a wholly qualified item (trailing \"so far as …\") dropped silently, so its provisions fall to the default; round 9 withholds only qualifier-led items"
    category: extent
    module: Extent.Lists
    affected: 6
    fix: "withhold as {:unread, nil, refs}; CV-S05 round 11"
    status: open
  - pattern: "Extent lists, one-offs: 1972/11 s.30 'that is to say,—' list dropped; 1980/34 'section 61 to 65'; 1989/15 'section 95'; 1994/21 item after 'za'; 2008/4 'section 113 (together with …)'; 2009/23 same-list Parts with brackets; 2000/19 s.82–83 both named NI and not NI"
    category: extent
    module: Extent.Lists
    affected: 7
    fix: "trace each; CV-S05 round 11"
    status: open
  - pattern: "Extent lists: an item's own exception not honoured, so excluded provisions are held ('but excluding', '(excluding …)', 'apart from', 'other than'): 2007/27 s.93, 2012/9 s.119, 2020/21 s.56, 2022/32 s.207 (+ 2009/23, R10 NEW-2)"
    category: extent
    module: Extent.Lists / Named
    affected: 5
    fix: "subtract the item's exceptions (same fix area as class B); CV-S05 round 11"
    status: open
  - pattern: "Extent: a Schedule paragraph's own extent ('This paragraph does not extend to Scotland', '… extends to Northern Ireland only') withheld as unread:provision_extent"
    category: extent
    module: Extent.Named / Units
    affected: 12
    fix: "own-extent rule for 'this paragraph' in Schedules (~36 sentences); CV-S05 round 11"
    status: open
---

# Session: CV-S05c: Shape Mining (CLOSED)

## Problem

Extent list wordings form a long tail: a few common shapes and many rare ones. CV-S05's agent check samples 50 laws at a time, so each round turns up a few rare wordings it hadn't seen. NEW counts by round: 16, 11, 5, 5, 8, 3, 6, 6, 1, 3. That is a discovery curve, and it won't reach zero quickly.

Aim (Jason 2026-10-27: "I thought it was a long tail problem"): stop sampling and list the whole tail. Reduce every list item in the corpus's extent sentences to a shape by masking numbers and names, for example "PART_REF, other than SCH_PARA_REF". Then count and rank the shapes, and review each shape once, so fixes go by count.

## Todo

- ✅ Prototype (script, read-only): mask and split the items of the 3,039 extent sentences, count and rank the shapes, and show the rare ones with examples. Ask Jason before running it.
- ✅ Store each run as evidence (run-01 committed, but inside the other lane's 30cebd9a "fix(frontend): clear 32 ESLint errors": it swept up my staged files; with Jason) (Jason 2026-10-27): `backend/data/experiments/cv-s05c-shape-mining/<run>/` holds a manifest (commit, ReadVersion, input counts and digests, command, date), the script as run, the input sentences and the ranked shapes with examples. Commit with `git add -f`, scanning for effect ids first
- ✅ Check that the round 9 and round 10 NEW wordings appear in the tail the prototype finds
- ✅ Measure the tail: the shape counts, the singletons, and an unseen-shape estimate (Good–Turing / Chao1)
- ✅ Mark the shapes the reader already reads, so review skips them (step 2: per-item verdicts)
- ✅ Confirm the 33 drops (`run-01/dropped.tsv`) against the law text; hand the confirmed ones to CV-S05 round 11
- ✅ Shape review of the qualified tail (steps 3–4: over-reach rules; the unread tail ranked) (`run-01/review.tsv` buckets `read_qualified`, `misread_qualified`, then `in_unread`), most common first, with Jason; hand the ranked shapes to CV-S05 round 11
- ⏸️ If it earns its place, build it as a read-only mix task with pure modules and tests (deferred: decide after CV-S05 round 11's re-run census)

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

## The 33 drops confirmed (2026-10-27)

Each was judged against its whole sentence and the stored lists; full table in `run-01/confirmed.md`. **29 laws are real misreads** in five classes, logged as open bugs for CV-S05 round 11:

| Class | Laws | What |
|---|---|---|
| A | 6 | "In Part N— (a) X extends …, (b) Y extends …": only (a) read |
| B | 8 (+3) | an item with its own exception ("X except Y") dropped whole; one inverted |
| C | 4 (+1) | plain provisions dropped with a qualified companion ("… and section 73 so far as relating to those Parts") |
| D | 4 (+2) | a wholly qualified item dropped silently, not withheld (falls to the default) |
| E | 7 | one-offs (1972/11 "that is to say,—", "section 61 to 65", "za", "together with", 2000/19 contradiction …) |

**4 are not drops:**
- 1975/21 and 2012/9: sub-lists of amendments, grouped by the Act amended;
- 2017/1012: sub-items of a qualified item;
- 2019/696: exceptions held as `not NI`, which is a separate question.

**Lesson:** classes A–D are *recurring* shapes at the sentence level, but invisible at item level. The agent check met them only by chance: R10 NEW-2 was 2009/23.

## Shape review (2026-10-27, steps 3–4)

- **Read but qualified items (step 3).** Reviewing 90 shapes by eye was replaced by three rules checked on every list item: excluded, qualified, scope (`run-01/overreach.exs`; 100 laws, about 2 min). There were 14 hits.
  - **Class F:** 5 laws hold provisions their item excludes: 2007/27, 2012/9, 2020/21 and 2022/32, plus 2009/23, which was R10 NEW-2. So the check re-finds what the agent found.
  - **Not misreads:** 4 laws, all from the check's own limits. It looks at one item at a time, and bare numbers cut into the wrong chunks.
  - Details are in `run-01/overreach.md`.
- **Unread tail (step 4).** 920 withheld sentences and leads fall into 757 shapes, 714 of them in one law only. It is a true long tail, and withholding keeps it safe.
  - The one rule worth writing is a Schedule paragraph's own extent ("This paragraph does not extend to Scotland"): about 12 laws and 36 sentences, logged as a bug.
  - Details are in `run-01/unread_tail.md`.

**Summary for CV-S05 round 11:**
- **Drops:** classes A–E, 29 laws.
- **Over-reach:** class F, 4 new laws.
- **One unread rule:** about 12 laws.

Each comes with its laws as fixtures. This census is the baseline: after round 11, rerunning `run-01`'s commands gives a new run to compare against it.

## Dependencies

- ✅ CV-S05a recall sweep (closed): the population of extent sentences
- ✅ CV-S05 catalogue (`Extent.Patterns`, `Extent.Credit`) and stored `extent_rules`
