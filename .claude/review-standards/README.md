# Review Standards

Written bars that a reviewer checks a document against. Each standard is one lens: a reviewer applies one standard per run, so findings stay focused and comparable between runs.

Adapted from Google's Elephant-Goldfish Model (`resources/document_standards/`), tuned to this project. Session: `.claude/sessions/2026-10-24-review-practices.md`.

| Standard | Use on | The one rule that fails it |
|---|---|---|
| [zoom-out](zoom-out.md) | Any design or plan, first | Solves a symptom, or builds what already exists or isn't needed yet |
| [design](design.md) | A design before building | Proposes one path without the rejected alternatives and why |
| [plan](plan.md) | An implementation plan or session Todo before building | Leaves a design choice to whoever builds it |
| [naive-reader](naive-reader.md) | Guides, skills, design docs, session docs handed on | A fresh reader must guess a term, a step or a default |

## Who uses them

- `gemini-review` with `--standard <name>`: document only, a different model.
- The fresh-context Claude reviewer: the document plus the files it names, and code search. Only this reviewer can check reuse and claims about the code.

## Saving

The caller saves each report to `backend/data/code-reviews/<YYYY-MM-DD>-<slug>-<standard>-<claude|gemini>.md`. Re-runs add `-r2`, `-r3`; never overwrite a report. The folder sits under the ignored `data/`, so commit reports with `git add -f`.

## Shared output format

Every reviewer reports each finding as:

```
### <short name> — <Blocker | Major | Nit>
- Where: <section heading or line range>
- Finding: <what is wrong or missing, with evidence>
- Fix: <what would make it pass>
```

- **Blocker**: the document fails the standard's rule; don't build on it yet.
- **Major**: a real gap that will cost rework if left.
- **Nit**: wording, layout, small clarity gains.

Report only findings. A document that passes says `PASS — no findings` and nothing else.

## Triage

The author answers each finding **Take** (fix it) or **Contest** (evidence that the finding is wrong: a file, a test, a decision with its date). Jason decides any Contest he disagrees with. Record the list in the session doc as before, under "Taken / Contested". One re-review per standard after fixes; anything still open after that is written down as an accepted trade-off.
