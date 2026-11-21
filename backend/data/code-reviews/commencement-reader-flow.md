# Commencement reader step: an improved flow (proposal, 2026-11-21)

From the code review (`commencement-reader-code-review.md`), the probes and the four step sessions. The step took one day for Maritime and Environmental Protection, both with no fixer calls. It took about 1.7M Fable tokens for Fire and OH&S, and about 1.9M for Waste, Water and Climate (not closed, two days). The waste has two sources: the loop repeats heavy runs after every fix, and each heavy run is slower than it needs to be.

## 1. Fix the code first (one session, before the step resumes)

| Fix | Measured or expected saving |
|---|---|
| Build the range position map once (`OwnClause.context/1`) | 2003 c.21: 86 s → about 1 s a check |
| One reading per law, order and amender, shared by the check and the leftovers gate | a third of each `--fresh` check |
| Parse each law's CLML once per run, keyed on the file's digest | 1991 c.56: 9.4 s → about 3 s; 2003 c.21: 15 s |
| One `OrderRead`, as `OwnRead`, so the `--fresh` dry run is what `--read-orders` writes | correctness: today the preview and the write differ |
| The catalogue: key CLML laws on file digests; move `Order`'s ref helpers out so an order fix does not empty the own-clause cache | a warm catalogue in seconds, not minutes |

Behaviour-preserving, proved by the catalogue fixtures, the check's output before and after on the round, and the suite.

## 2. The step's loop, in four parts

1. **Find, once.**
   - One `--fresh` check of the round and the switched families, both catalogues, and the feed gate.
   - Their groups make one work list, each class with every instance listed: leftovers, misreads, feed differences.
2. **Decide before fixing.** Every rule question the list raises goes to Jason in one Decision before any fix: purposes, EU words, what counts as partly in force. In Waste, Water and Climate, three decisions arrived mid-fix and reworked finished fixes.
3. **Fix by class, cheaply.**
   - Each class is fixed test first; the session does a one-form fix itself, and Fable takes a class with many instances.
   - After each fix: the class's tests, the commencement tests (34 s), and `lat.commencement_check --laws <the class's instances> --fresh` plus `lat.commencement_patterns --laws …` (seconds).
   - No full suite, no family checks, no full catalogue per fix.
4. **Settle and check, once per batch.**
   - After all the classes, or a batch of about five: one full `mix test` (about 4 min), Dialyzer (the pre-push hook runs it), the family checks for the round and switched families, the feed gate, and both catalogues.
   - A regression found there goes back as one class.

## 3. Briefs and agents

- **Decided (Jason, 2026-11-21): (a), with the code review's findings. "Fable is a fix option of last resort. If the standard session cannot land the fix and pass the tests it goes to Fable and only on Approval with reasons."** The session makes every fix itself.
- A fixer brief, when one is approved, names one class and lists its instances from the work list, nothing else; the fixer runs only the commands in part 3.
- Credo through `scripts/maintenance/credo-diff.sh`.

## 4. The pass rule (unchanged, plus the feed gate)

- Our faults 0;
- every leftover, misread and feed-difference group statused;
- held moves decided by Jason;
- switched families PASS;
- golden;
- the suite and Dialyzer green.
