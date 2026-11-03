# LAT Change Pipeline: the aim and its principles

Confirmed by Jason 2026-11-03 (retrospective): **there is one aim, `binds-today`.** The six items after it are not aims. They are principles for how the pipeline delivers it.

Every rule in `RULES.md` serves the aim through one or more principles. A rule that serves none is a smell. When two rules pull apart, the aim decides, then the principles in the order below. Each item has a short name, and `RULES.md` cites rules by it.

## The aim — `binds-today`: tell the user whether a provision binds them

The label tells a compliance user whether a provision binds them today, since when, where, and which law made it so. Its periods show the same for any past date.
- **Why:** this is what the labels are for. Compliance reads `lat_label_timeline`, and nothing else matters if that is wrong.
- **From:** `notes-are-hints` memory ("Purpose: high-quality provision labels", 2026-10-12); the label fold's aim (`2026-10-22-cv-s09-label-fold.md`); the consumers step (`2026-10-21-cv-05-consumers.md`, 2026-10-31).

## Principles for delivering it

### 1. `unknown-over-guess`: unknown beats guessed

Where no source gives a value, the label leaves it empty and says why. It never fills it with a default: no Royal Assent date for an Act commenced by order, no "UK" territory.
- **Why:** a visible gap sends the user to the law. A wrong date or place misleads them silently.
- **From:** golden convention C10 (`2026-10-21-cv-01-architecture-review.md`, 2026-10-21); the reply to Gemini's "default UK" ("No claim stays unknown, never assumed", `2026-10-21-cv-00-meta.md`); the gap rule (`2026-10-22-cv-s08-evidence.md`, 2026-10-29); "Named gap" (`2026-10-21-cv-06-switch-over.md`, 2026-11-01).

### 2. `law-text-wins`: the law is the authority when we use it

When we read the law itself, it is the authority. That covers the amending instruction, extent and application clauses, and commencement clauses and orders. Where it speaks, it outranks legislation.gov.uk's markup, which outranks the changes feed. This states a truth about authority; it is not a mandate to read every law. Where legislation.gov.uk's coverage is sufficient (`coverage-from-lgu`), the law's text isn't needed (Jason 2026-11-03). Notes are pointers only. A disagreement is reported, never silently reconciled. Each value says which kind of source it rests on.
- **Why:** the law is the authority. Editorial sources lag and err.
- **From:** Jason 2026-10-21 ("The actual legal text is primary. These other sources are derived and secondary", `2026-10-21-cv-00-meta.md`); notes are not law (memory `notes-are-hints`, 2026-10-09 and 2026-10-12).

### 3. `coverage-from-lgu`: legislation.gov.uk for coverage, the law for what it lacks

The feed and the markup are the coverage baseline. The law's text is read where they are weak or silent: territory, commencement dates, the law's own clauses, and changes not yet in the feed. Fetches go one hop from the family's laws, counted, and only with a go-ahead.
- **Why:** legislation.gov.uk has already done most of the reading. Matching its coverage with our own reader would take a long time and gain little.
- **From:** Jason 2026-10-22 ("is there a balanced approach?", `2026-10-22-cv-07-primary-coverage.md`); effects first, scoped fetch (memory, 2026-10-18).

### 4. `one-record-per-change`: one record per real change, one rule per attribute

Every source is read into one vocabulary and merged by identity, so each real change is one record. Each attribute is chosen by one stated evidence order. No rule exists only to make two sources agree.
- **Why:** rules added pairwise at the edges conflicted and multiplied ("chasing edges in code rather than abstracting").
- **From:** Jason 2026-10-21 ("Abstracting all change sources into a common vocabulary … is the only way to do the labelling reliably"; "Stopping all this duplication"), `2026-10-21-cv-00-meta.md`.

### 5. `prove-one-family`: prove it on one family, then grow

v0.1 is the OH&S core family (149 laws). Each step passes a check fixed before it starts. A new family extends the catalogues and goes through the same checks.
- **Why:** this bounds the work and makes "done" testable. Other families have their own peculiarities.
- **From:** Jason 2026-10-21 ("start small, prove, iterate and grow"); 2026-10-22 ("cap to oh&s family"; "know what good looks like"); 2026-10-31 ("OH&S only, by family"); see `2026-10-21-cv-00-meta.md` and `2026-10-21-cv-06-switch-over.md`.

### 6. `fix-where-owned`: fix a fault where its code lives, or name it

A fault is fixed in the step whose code owns it, at its source, by class. A one-law wording or a legislation.gov.uk error below the step's threshold becomes a named known limit. Nothing is patched downstream to hide it.
- **Why:** fixes made in later steps sprawled and blurred who owns what ("boiling the ocean").
- **From:** Jason 2026-11-02 (`2026-11-02-cv-06b-routed-fixes.md`); memory `fix-mistakes-properly` and `session-scope`; the retrospective (`2026-10-30-cv-s12-retrospective.md`, 2026-11-03).

## When principles pull apart

`binds-today` is the purpose and decides first.
- `unknown-over-guess` and `law-text-wins` decide how a value is chosen.
- `coverage-from-lgu` and `one-record-per-change` decide how the pipeline is built. In practice `coverage-from-lgu` decides *whether* we read the law, and `law-text-wins` decides *what happens when we do*.
- `prove-one-family` and `fix-where-owned` decide how the work is run.
