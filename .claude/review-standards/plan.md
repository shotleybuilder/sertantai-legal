# Plan Standard

For an implementation plan, or a session's Todo plus its build notes, before building starts.

**Session docs grow as work goes** (`session-start.md`: lean at creation). So for a session, check the Todo as a whole only for scope and order. Hold each item to the full standard before that item is built: its design section, files and done check must exist by then. Items not yet reached that are only named are not findings.

## Rule

A plan passes if a fresh Claude session that has never seen the conversation could carry it out and get it right first time, without guessing, asking, or making a design choice of its own.

## The zero-decision rule

The plan fails if the builder has to choose anything that shapes the result: a table or column, a module boundary, a mix task's name or options, which source wins, how an edge case is handled, which laws are in scope. Each such choice is made in the plan, or listed as an open question for Jason **before** building.

## Steps

- Work is split into steps that each leave the code compiling and the tests passing.
- Each step names the files it creates or changes.
- Steps follow the agreed order; none is dropped or merged without saying so.

## Tests and checks

- Named test cases: the normal case and the edge cases, with the law or fixture each uses.
- The pass measure for the step (golden set, pattern catalogue, sample check) and its threshold.
- For a structural refactor: the tests are written against the new module names first, and pass unchanged after extraction.

## Runs and data

- Every run is listed with its purpose, rough time and what it writes. Long runs (rebuilds, re-parses, fetches, read passes, scoreboards) are marked "ask Jason first".
- Runs go one law at a time where they parse CLML; never wide parallel runs.
- Before an apply: a restore point of the tables it writes.
- A repair touches only the changed rows: dry run, then Jason, then apply.
- Who else needs telling (fractalaw, sertantai-compliance).

## Also flag

- A step whose done-state can't be checked.
- Work outside the session's scope that should be a pending session.
