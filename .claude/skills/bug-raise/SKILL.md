---
name: Bug Raise
description: Raise a bug against the step (or area) whose code owns it — in the current session's frontmatter, and on GitHub when it must outlive the workflow. Park it; never chase it across the codebase. Use whenever a fault is found, above all one outside the current step.
---

# Bug Raise

**Purpose:** every bug is found again by the step that owns it, so none is lost and none is fixed out of place. From the 2026-11-03 retrospective: bugs were chased across the codebase, and earlier steps' code was fixed inside later steps ("boiling the ocean").

## The rule

- **A bug in the current step's own code**, in the step's scope and over the plan's triage size: fix it in-step and log it `status: fixed`.
- **A bug in another step's code**: raise it here and park it. Never fix it in-step unless Jason says so for that bug.
- **A single-law wording, or an error in legislation.gov.uk's own data**, below the triage size: a named known limit (`docs/lat-change-pipeline/RULES.md`, Known limits), not a fix.

## Owning steps

LAT Change Pipeline steps (`docs/lat-change-pipeline/WORKFLOW.md`):

| Step | GitHub label |
|---|---|
| Making laws | `step:making-laws` |
| Sources | `step:sources` |
| Feed reader | `step:feed-reader` |
| Markup reader | `step:markup-reader` |
| Commencement reader | `step:commencement-reader` |
| Extent reader | `step:extent-reader` |
| Amending-law reader | `step:amending-law-reader` |
| Merge | `step:merge` |
| Evidence | `step:evidence` |
| Label fold | `step:label-fold` |
| Measures | `step:measures` |
| Store and build | `step:store-and-build` |
| Labels side by side | `step:labels-side-by-side` |
| Switch-over | `step:switch-over` |

Outside the pipeline, use the area as the step: "LAT parser", "Definitions", "Register", "Sync", "Frontend".

## Steps

1. **Find the owning step.** Ask which module must change to fix it, then map it:

   | Module | Owning step |
   |---|---|
   | `making_laws*`, `legal/making.ex`, `taxa/making_resolver.ex` | Making laws |
   | `sources*` | Sources |
   | `change_vocabulary/readers/feed*` | Feed reader |
   | `readers/markup*` | Markup reader |
   | `commencement/`, `readers/*commencement*` | Commencement reader |
   | `amending_law/extent*` | Extent reader |
   | `amendment/`, `amending_law/` | Amending-law reader |
   | `merge*` | Merge |
   | `evidence*` | Evidence |
   | `label/`, `label_*.ex` | Label fold |
   | `measures*` | Measures |
   | `store*`, `build.ex` | Store and build |
   | `label_switch*`, `known_limits*` | Switch-over |
   | LAT parse (`lat_parser/`) | "LAT parser" |
2. **Name the class.** Give a descriptive slug, unique and readable: `repeal-table-continuation`, not "U12". Check `docs/lat-change-pipeline/GLOSSARY.md` for an existing class first.
3. **Count.** Record the rows or laws affected (a number, or "unknown") and one example (law and provision).
4. **Write the entry** in the current session's frontmatter `bugs:`:
   ```yaml
   - pattern: "<one sentence: what goes wrong, in plain words> (e.g. <law> <provision>)"
     category: <class slug>
     module: <module that must change>
     affected: <rows or laws>
     fix: "<suggested fix, one line>"
     step: <owning step name>
     status: open
   ```
   If the session has a `## Parking list`, add one line there too: `<step>: <class slug> — <one line>`.
5. **GitHub, only when** the bug must outlive the workflow, needs someone outside it, or Jason asks:
   ```bash
   gh issue create --title "<step>: <one-line pattern>" --label bug --label "step:<label>" --body "<pattern, example, affected, fix; session path>"
   ```
   Then add `issue: <n>` to the frontmatter entry.
6. **Rebuild the index:** `/usr/bin/python3 scripts/maintenance/session_index.py --root .`. Bugs by step:
   ```bash
   sqlite3 .claude/sessions/sessions.db "SELECT step, count(*) FROM open_bugs GROUP BY step ORDER BY 2 DESC;"
   ```

## When the owning step reopens

The step session's plan starts from its parked bugs:

```bash
sqlite3 .claude/sessions/sessions.db "SELECT pattern, affected, session_id FROM open_bugs WHERE step='<step>';"
```

It fixes each bug or names it a known limit. The original entry is then marked `fixed`, or `moved` with a pointer.
