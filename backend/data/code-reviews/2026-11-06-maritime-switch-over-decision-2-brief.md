# Decision brief: a feed effect read as a whole Part inserted (Merchant Shipping Act 1995 Part VI)

## Context

SertantAI holds UK legislation cut into provision rows. A pipeline reads legislation.gov.uk's changes feed, change markup and the law's text into one set of merged changes, and folds them into a label timeline per row: status, in force from, territory, changed by, as periods over time.

The single aim is the "time machine": for any date a user picks, the label says whether a provision binds them on that date, since when, where and by which law. Its principles, in order:
1. unknown beats guessed;
2. the law's text wins where we read it;
3. legislation.gov.uk for coverage;
4. one record per real change;
5. prove one family, then grow;
6. **fix a fault where its code lives**, by class, or name it a known limit. Nothing is patched downstream.

The pipeline runs in 14 steps per family of laws. The last step, the **switch-over**, writes the family's timeline from the new method instead of the old one. Every difference must first be explained. A row the new method can't yet label right can be put on a **known-limits list**, which keeps its old (current production) label at the switch until the owning step fixes it. A bug in an earlier step's code is normally parked with that step, not fixed in the switch-over, unless the owner (Jason) gives leave for that bug.

## The finding

The family is Maritime Safety: 117 laws, 24,434 rows. The second family after OH&S.

- legislation.gov.uk's feed has two effects on the Merchant Shipping Act 1995 by the Merchant Shipping and Maritime Security Act 1997:
  - `AffectedProvisions="s. 130A-130E (Pt. 6) (Ch. 1A)"`, type "added";
  - `"s. 182A-182C (Pt. 6) (Ch. 5)"`, type "added".

  In the first, the feed itself flags Chapter 1A "Section missing in legislation".
- The feed reader's refs for the first are `section-130A`, `section-130E` (a range), `part-VI` and `chapter-1A`.
  - Its rule "one path linked in pieces is one target, the deepest" drops a ref only when another ref extends it by prefix (`part-VI` → `part-VI-chapter-1`).
  - `part-VI` is not a prefix of `section-130A`, so it survives as a target. The change is stored as "Part VI inserted 1997-03-19 / 1997-07-17 by the 1997 Act".
- The fold then reads every row under Part VI as inserted in 1997.
  - 773 rows sit under Part VI. 529 of them have stored periods in force from 1996-01-01, the Act's start.
  - On the new labels those periods are gone, and the rows read as not in force (no period) until 1997, with "changed by" the 1997 Act.
- The other six Part insertions in the family are real new Parts (feed text "Pt. 9A", "Pt. 10A" …, with no section range beside them).

## Options

**A. Park and keep.** The bug is parked with the Feed reader step. Part VI's rows (or the 529) go on a Maritime known-limits list and keep their current labels at the switch. The rest of the family switches now. The rows move to the new labels when the Feed reader step is reopened.

**B. Fix the reader now** (Jason's leave for this bug).
- **The rule:** a Part, Chapter or Title ref that the effect's text gives in brackets beside a provision or range ("(Pt. 6) (Ch. 1A)") is a locator, not a target.
- **The reader's own method:**
  - a whole-store scan for the form, to find the class across all families;
  - the reader's check and regression run;
  - a rebuild of the laws whose changes move;
  - the switch-over's causes and rules re-run.

  About 1–2 hours. Part VI switches with correct labels.

**C. Hold the whole family's switch** until the Feed reader step is reopened.

## Recommendation asked

The author recommended A, as the switch-over's own mechanism, keeping the step in scope. Jason leans B.

## Review asked

1. Which option best serves the aim (the time machine) and the principles, above all "fix where owned" and "prove one family"? Pick one.
2. If B: is the locator rule right, and safe? Name forms it might wrongly drop, e.g. an effect that really inserts a Part and also names a section, or "Pt. 2 Ch. 3" written without brackets.
3. Any risk in A we've missed? For example, a known-limits list that hides 500+ rows, or the current labels themselves being wrong.
4. Answer in under 600 words, with a clear pick.
