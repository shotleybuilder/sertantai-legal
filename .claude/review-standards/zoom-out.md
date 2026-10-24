# Zoom-Out Standard

The high-altitude check. Run it first on any design or plan, and again after big changes from other reviews.

## Rule

A document passes if it solves the root problem in the simplest way that works, reuses what the project already has, and puts new logic in the right layer.

## 0. Enough context

If the reviewer can't say **what** is being attempted and **why** from the document and the files it names, stop: one Blocker, "context missing", naming what is missing. Don't review further.

## 1. Root problem

- Does it fix the cause, or patch a symptom downstream?
- Is a mistake being designed around instead of corrected at source?

## 2. Simplicity

- Nothing built for a speculative future need (YAGNI).
- No caching, queues, parallel runs or new tables before a measured need.
- Data passes through as few steps as possible.
- No dead ends: interfaces leave room to grow without building the growth now.

## 3. Altitude

- A design talks about components, data flow and contracts. Helper names and loop details belong in the code.
- New logic goes in the right layer: pure logic (text, regex, transforms) in pure modules that take data as arguments; DB, files and HTTP in their own modules; a thin orchestrator on top.

## 4. Reuse

- Search the code before accepting a new module, task or helper. If something close exists, name it and say why it does or doesn't fit.
- Follow existing patterns: Ash resources and generated migrations, mix tasks, `defdelegate` when extracting, structs once a map shape appears in 3+ places.

## 5. Project principles

Flag a design that breaks one of these without saying why:

- Legal text is the primary source and wins where it speaks; the feed and markup set the coverage baseline.
- One vocabulary for all change sources, merged by identity, never pairwise reconciling rules between sources.
- Use legislation.gov.uk effects before pulling law text; fetch only one hop from domain rows, never a cascade.
- Notes on legislation.gov.uk are hints for where to look, never facts.
- A UK law is identified by type code + year + number, never year + number alone.
- Measure offline from the local CLML store; don't re-hit legislation.gov.uk for what's stored.
