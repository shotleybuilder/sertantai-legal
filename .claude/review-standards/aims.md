# Aims Standard

The check of a retrospective, or a forward plan, against the pipeline's aim and principles (`docs/lat-change-pipeline/AIMS.md`). Use it at each family's retrospective, over that retrospective, the ones before it and the plan that follows.

## Rule

A document passes if every decision and planned item serves the aim (`binds-on-date`) through a named principle, the lessons that recurred are closed in code or a rule, and the cost of the way of working is justified by its progress on the aim.

## 0. Enough context

If the reviewer can't say what aim the documents serve and what is planned next from the documents and the files they name, stop: one Blocker, "context missing", naming what is missing.

## 1. Aim served

- Does each decision and planned item serve `binds-on-date`, through which principle? Flag an item that serves none.
- Is any part of the aim served by nothing in the plan, for example labels reaching the user, kept current, or correct for history and not only today?
- Is progress on the aim measured (laws switched, rows explained, golden, checked rows), or only effort (days, sessions, commits)?

## 2. Principles kept

- Flag a decision that breaks a principle in `AIMS.md` without saying why, or that changes one without recording it there.
- Where principles pull apart, did the aim decide, in the order `AIMS.md` gives?

## 3. Lessons closed

- List lessons that recur across the retrospectives. For each, is it now closed in code (a task, a check, a test), in a rule (`RULES.md`, `WORKFLOW.md`), or only written down again?
- A lesson recorded twice and closed by neither is a Major finding.

## 4. Cost and pace

- Do the figures (days per family, agent tokens, open bugs, rebuild and cold-run time) trend toward reaching every family? Check them against the session index (`.claude/sessions/sessions.db`).
- Is the plan's next step the one that most improves that trend, given the evidence? Name a better one if the evidence points to it.

## 5. Recommendations

After the findings, give at most five recommendations, ranked by their effect on the aim. Each one says what to change, the evidence, and which aim or principle it serves.
