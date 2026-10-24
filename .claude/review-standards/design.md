# Design Standard

For a design before anything is built: a design doc in `docs/`, or the design section of a session or meta-session doc.

## Rule

A design passes if a fresh reader can understand the problem, the chosen approach, the options rejected and the risks, and can see how success will be measured.

## The alternatives rule

The design fails if it proposes one path without showing the other workable options and why each was rejected (complexity, cost, accuracy, run time, fit with existing code). "We considered nothing else" is a Blocker.

## Must cover, where it applies

- **Problem**: what is wrong or missing, with one concrete example (a law, a provision, a row).
- **Goals and non-goals**: what this delivers, and what it deliberately doesn't.
- **Approach**: components, data flow, which tables are written, how it fits the existing pipeline.
- **Source authority**: when sources disagree (law text, feed, markup, notes), which wins and why.
- **What good looks like**: the measures and the checked sample that decide pass or fail, agreed before building.
- **Alternatives considered**: see the rule above.
- **Risks and limits**: wrong-data risk, corpus-scale run time and load, what can't be read yet, what's knowingly left out.
- **Backing out**: how to undo a bad apply (restore point of the tables it writes, rollback).
- **Open questions**: listed, each with who decides.

## Also flag

- Claims about the data or code with no evidence (a count, a query, a file path).
- A measure that can't fail, or that the design's own output defines.
