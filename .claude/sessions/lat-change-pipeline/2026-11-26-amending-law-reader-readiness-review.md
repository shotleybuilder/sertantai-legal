---
session: Amending-law reader readiness review
status: closed
opened: 2026-11-26
closed: 2026-11-26
outcome: success
summary: >
  The Commencement and Extent reader retrospectives' lessons asked of the Amending-law reader before its Waste, Water and Climate step. The spec (AMENDING-LAW-READER.md) and a gotchas file were written; the main cost found: every amending law (2,627) is stale through shared code the Commencement reader edited, and the build re-reads stale amenders from their text, so the build's stamp holds the whole reader.
  Decision 1: stamps and procedures as two pending sessions before the step. Decision 2: legislation.gov.uk's operation and level first where it speaks (95% of text changes).
decisions:
  - what: "Decision 1: exact stamps, shared code staling only its readers, the mixed modules split, the build's fallback dropped, and the procedures as tasks; two sessions before the step"
    why: "all 2,627 indexes on 7f3bd44a50c4 (2026-11-15) with three commits since, two of them the Commencement reader's lat_ref.ex; ChangeVocabulary.Version globs amendment/*.ex and reader/*.ex because Primary.fresh_rules reads stale amenders from text; --read takes no family"
    result: "2026-11-26-amending-law-reader-stamps.md and 2026-11-26-amending-law-reader-step-procedures.md (pending), in the round meta; the fallback's drop reverses the 2026-10-25 choice"
  - what: "Decision 2: legislation.gov.uk first where it speaks, for operation and level (as for dates and extent)"
    why: "it gives the operation on 95% of text changes and agrees with the law's text on 92.4% where both speak; the earlier steps' cost was chasing D groups in every family"
    result: "RULES amending-legislation-gov-uk-first-where-it-speaks; the build change parked with Evidence; the gate's split by coverage in the step procedures session"
metrics:
  reader_size: { files: 49, lines: 7140, largest_module_lines: 527 }
  stamps: { amendment_indexes: 2627, on_one_old_version: 2627, commits_since_last_write: 3, by_commencement_reader: 2 }
  feed_vs_law_all: { text_changes: 104935, law_states_op: 36091, gov_states_op: 99476, agree: 28293, differ: 2339, law_only: 5459, gov_only: 68844, level_agree: 30603, level_differ: 554 }
  feed_vs_law_round: { text_changes: 36362, law_states_op: 13312, agree: 10755, differ: 846, law_only: 1711 }
  parked_for_step: { open: 32, distinct: 26 }
lessons:
  - title: Another step's fix can stale this reader with no edit of its own
    detail: "Two Commencement reader commits to lat_ref.ex (2026-11-21) moved Amendment.ReaderVersion, so all 2,627 amending laws went stale after their last write on 2026-11-15; git log on a stamp's files tells it before any count."
    tag: tooling
  - title: The Amending-law reader still has the build-time fallback the Extent reader dropped
    detail: "Primary.fresh_rules reads stale amenders from their text on every build, on Index.fresh? not current?, and Store.Inputs gives no stale reason; it was chosen on 2026-10-25 as a speed cost only, but it is why the build's stamp holds the whole reader."
    tag: tooling
  - title: legislation.gov.uk's coverage is far higher for operation than for dates or extent
    detail: "95% of text changes against 68% for extent; the law's text speaks on only 34%. The two-way gate (D and L) was already the yardstick; the rule now limits fixes to L."
    tag: data
bugs:
  - pattern: "Evidence takes the law's text first for operation and level where legislation.gov.uk speaks; RULES amending-legislation-gov-uk-first-where-it-speaks needs its operation and level first unless the law's words prove it wrong"
    category: amending-legislation-gov-uk-first-not-built
    module: change_vocabulary/evidence
    affected: "2,339 differing changes store-wide (846 in the round), 2026-11-26"
    fix: "Evidence's tier order for operation and level on covered changes, with a legislation.gov.uk-error register for proven ones; designed as for #202"
    step: Evidence
    status: open
artifacts:
  - docs/lat-change-pipeline/AMENDING-LAW-READER.md
  - backend/lib/sertantai_legal/scraper/amendment/CLAUDE.md
  - backend/data/reports/amending-reader/readiness/
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/amending-reader-check/SKILL.md
  - .claude/sessions/lat-change-pipeline/2026-11-26-amending-law-reader-stamps.md
  - .claude/sessions/lat-change-pipeline/2026-11-26-amending-law-reader-step-procedures.md
depends_on:
  - 2026-11-23-extent-reader-readiness-review
  - 2026-11-23-commencement-reader-retrospective
  - 2026-11-26-waste-water-and-climate-extent-reader
enables:
  - "Amending-law reader: stamps that follow what changed"
  - "Amending-law reader: step procedures"
  - "Waste, Water and Climate: Amending-law reader"
---

# Session: Amending-law reader readiness review (CLOSED)

## Problem

The Amending-law reader parses amending laws' text, as the Commencement and Extent readers do, and shares their document code (`amending_law/doc.ex`, `text.ex`). Their retrospectives found the same costs in each: no written spec, one version stamp over shared code (any fix stales every reading), step procedures as hand lists, fetch needs found late, and checks re-run per fix. Jason (2026-11-26): apply those lessons to the Amending-law reader before the Waste, Water and Climate step starts, as the Extent reader readiness review did.

## Todo

- ✅ 1. Measure: size, stamps, stale state, procedures, earlier steps, parked bugs (plan mode)
- ✅ 2. Find: the lessons of the Commencement and Extent retrospectives, each checked against the Amending-law reader (applies, already true, or not)
- ✅ 3. Find: the feed-coverage question in figures (operation and level: where the law's text and legislation.gov.uk agree, differ, or only one speaks)
- ✅ 4. `docs/lat-change-pipeline/AMENDING-LAW-READER.md`: aim, scope, boundary, substeps, loops, yardstick, open questions
- ✅ 5. `amendment/CLAUDE.md`: the gotchas file; WORKFLOW §6 and the skill point to it
- ✅ 6. Decision for Jason: what to change before the step (stamps, procedures as tasks, mixed modules, the feed-coverage answer, the parked bugs' duplicates)
- ✅ 7. Close: decided sessions as pending stubs in the round meta; rules in RULES; the report in the terminal

## Dependencies

- ✅ Waste, Water and Climate: Extent reader closed and pushed (2026-11-26)
- ✅ Extent reader readiness review, stamps and step procedures closed (2026-11-25): the template for this review
- ✅ Commencement reader retrospective and its five follow-on sessions closed (2026-11-23 to 2026-11-25)

## First look (2026-11-26, before the plan)

- **Code:** `amendment/` and `amending_law/` without `extent/`: 49 files, 7,140 lines.
- **Stamps:** `Amendment.ReaderVersion` globs `amendment/reader/*.ex` and names the shared document readers (`amending_law/doc.ex`, `doc/*.ex`, `text.ex`, …), so a shared edit stales amending, commencement and extent readings alike (parked: the shared-document-readers bug, 2026-11-12). `Amendment.CatalogueVersion` holds the whole reader too. The stamp is kept in the amendment index (a file cache), not on `amendment_rules`.
- **Procedures:** `lat.amending --read` has `--preview`, `--all`, `--regression`, `--diff`; no `--stale`. `lat.reread` has no amending substep; `lat.stale` names no amending reason.
- **Docs:** no reader spec (AMENDMENT-GUIDE.md is background), no gotchas file.
- **Parked:** 32 open bugs for the step in the index, 26 distinct (the 2026-11-03 entries listed again on 2026-11-10); no GitHub issues.

## 1. Measure (2026-11-26; plan approved)

- **Largest modules** (lines / functions): `Reader.Targets` 527/38, `Reader.RepealTable` 508/39, `Reader.Clauses` 380/26, `Reader` 347/15, `AmendingLaw.RefList` 343/19, `AmendingLaw.Text` 341/26, `Reader.LawNamed` 327/18.
- **Stale state:** all 2,627 amendment index files hold reader `7f3bd44a50c4`, written 2026-11-15 (the Fire and OH&S write). Since then three commits touched `ReaderVersion`'s files, two of them the Commencement reader's (`lat_ref.ex`, 2026-11-21) and one the shared document reader (`5d1c188d`, non-breaking space). So every amending law is likely stale on code it never changed for: the shared-document cascade, measured. (Confirmed by `ReadPass.stale?` count, todo 1, on Jason's go.)
- **A build-time fallback, as the Extent reader had:** `Amendment.Index` (`index.ex:13-17`) — the stored rules stand only when the index is current; "otherwise the collector reads the document". With every index stale, every build reads every amending law from text.
- **Earlier steps:** Maritime Safety 0.5 day, Environmental Protection 1 day (plus the parked-bugs day), Fire and OH&S 1 day. Repeated pains: every reader edit stales every amender (798 laws re-read twice, zero-diff, 25 min each; 2,627 per write, 16 min); by-design and "no record" groups hide misreads; the gate is real only after the rebuild; scratch scripts lost (now tasks); a build printing success with every law FAILED.
- **Stamps** (the code map, spot-checked at `primary.ex:164-206`, `store/inputs.ex:40-75`, `read_pass.ex:70-105`):
  - `ReaderVersion`: `reader.ex`, `reader/*.ex`, `rule.ex`, the shared `amending_law/` document files, `lat_parser/xml.ex`, `lat_ref.ex`, `territory.ex`. No exactness test (`version_coverage_test.exs` checks only that nothing reached is missing).
  - `CatalogueVersion`: the catalogue and the whole reader; keys `CatalogueCache`.
  - `ChangeVocabulary.Version` (the build) globs `amending_law/*.ex`, `doc/*.ex`, `amendment/*.ex`, `amendment/reader/*.ex` (with an except list), because the build re-reads stale amenders from their text (`Primary.fresh_rules`, on `Index.fresh?`, not `current?`).
  - The shared document files sit also in the Commencement (Orders, Clause), Extent (Document), Feed and Markup catalogue, Fold, Label and order-catalogue stamps.
  - `Store.Inputs` gives no amending stale reason (`inputs.ex:69-71`: "the build reads a stale one from its text").
- **Procedures:** `--read` takes `--amending` (with `@FILE`), `--all`, `--regression`, else every `ReadPass.stale?` law store-wide; `--stale`/`--family` are the extents write's only. `lat.reread` and `lat.stale` know commencement and extent only.
- **Mixed modules:** `ReadPass` (feed, DB, CLML, file IO and the read), `ReadLaw` (notes from the DB beside `rules/3`), `Index` (file IO, builds references from the doc), `LawDoc`, `CatalogueRead`.

## 2. Find: the lessons against this reader (2026-11-26)

| Lesson (from) | Here | Evidence |
|---|---|---|
| A written spec with the boundary (Commencement retro) | Applies: none | AMENDMENT-GUIDE is background on forms; now `AMENDING-LAW-READER.md` (draft) |
| Stamps that follow what changed, exact by a test (Commencement retro; Extent stamps) | Applies | `ReaderVersion` globs `reader/*.ex` and shared files; no exactness test; 3 commits since the last write, 2 the Commencement reader's |
| Shared document code staling other readers (parked 2026-11-12) | Applies, both ways | `lat_ref.ex` edits for commencement staled all 2,627 amenders |
| The build's stamp holds only what it calls; no build-time fallback (Extent stamps) | Applies | `Primary.fresh_rules` reads stale amenders from text; the build's stamp holds the whole reader. Kept on purpose 2026-10-25 ("speed, not correctness"; `scraper/CLAUDE.md`) |
| A re-read writes only changed rules (Commencement staleness) | Already true | `Store.write_changed` (`store.ex:337`); `read_at` kept on unchanged rules — to confirm in the stamps session |
| Procedures as tasks: `--stale [--family]`, `--preview --diff`, `@FILE`, a `lat.reread` substep, `lat.stale` naming laws (Extent procedures) | Partly: preview, diff, `@FILE`, regression exist | no family scope, no substep, no stale reason |
| Feed yardstick by coverage (Commencement feed differences; Extent Decision 2) | Partly: the gate is two-way already (D, L) | §3 below; the rule's question is open |
| Mixed modules split where they set a stamp's line (Extent readiness) | Applies | `ReadPass`, `ReadLaw` |
| A gotchas file next to the code | Applies: none | now `amendment/CLAUDE.md` (14) |
| Step running: write first; fetch list from Find; previous close's FAIL lines into the plan; check after every write; batch, one write; golden each Settle; `read_at` for old misreads; switched families' drift traced | Applies to the step's plan | WWC Extent and Commencement lessons; most are in WORKFLOW "How a step is run" already; the FAIL-lines one is not |
| Hash with `[:deterministic]` across VM runs (Extent stamps) | For the stamps session's proof | — |

## 3. Find: legislation.gov.uk against the law's text (2026-11-26)

Read-only SQL over every stored text change (`backend/data/reports/amending-reader/readiness/feed-vs-law.sql`, `.txt`; legislation.gov.uk = feed, else markup):

| | All families | The round |
|---|---|---|
| Text changes | 104,935 | 36,362 |
| The law's text states the operation | 36,091 (34%) | 13,312 (37%) |
| legislation.gov.uk states it | 99,476 (95%) | 34,651 (95%) |
| Both: agree / differ | 28,293 / 2,339 (92.4%) | 10,755 / 846 (92.7%) |
| The law's text only | 5,459 | 1,711 |
| Level, both: agree / differ | 30,603 / 554 | 11,564 / 234 |

The builds behind these are on old reader code (every index stale), so the figures are indicative until the step's write.

## 4–5. The spec and the gotchas (2026-11-26)

- `docs/lat-change-pipeline/AMENDING-LAW-READER.md` (DRAFT): aim, scope, boundary, substeps, loops, yardstick, open questions.
- `backend/lib/sertantai_legal/scraper/amendment/CLAUDE.md`: 14 gotchas (5 stamps, 7 running the step, 2 code). A `.md`, outside every stamp's `.ex` globs.

## Decision 1 for Jason: what to change before the Amending-law reader step

- **Aim:** `binds-on-date` at a cost a step can carry (`fix-where-owned`): a fix should cost its tests and one bounded write, not every amender, every other reader and every build.
- **(a) Stamps that follow what changed** (this reader's code): `ReaderVersion` by name, held exact both ways by a test; the shared document files and `lat_ref.ex` stamped by what each reader's reading uses, so a commencement-only edit doesn't stale amenders; `CatalogueVersion` keyed apart from the tools. About half a day. No extra cycle: every amender is stale already.
- **(b) Drop the build's fallback** (Store and build's code, so it needs your go; it reverses the 2026-10-25 choice): a stale or unread amender becomes an `:amending_reader` stale reason in `Store.Inputs`; `ChangeVocabulary.Version` drops `amendment/*.ex` and `reader/*.ex`. Effect: a reader fix stales the builds whose rules it changes, not every build; builds stop re-reading amenders silently. Cost small; its reach measured first.
- **(c) The step's procedures as tasks:** `--read --stale [--family F]`; an `amending` substep in `lat.reread`, first in the chain (the commencement and extent re-reads follow it); `lat.stale` naming the laws; the skill and WORKFLOW §6 rewritten as §4 and §5 were (write first, fetch list, golden at every Settle, the previous close's FAIL lines). About half a day.
- **(d) Split the mixed modules** `ReadPass` and `ReadLaw`, with (a), where they set the stamp's line.
- **Recommendation:** all four, as two sessions before the step, as for the Extent reader: "Amending-law reader: stamps that follow what changed" ((a) + (d), and (b) on your go), then "Amending-law reader: step procedures" ((c)).

## Decision 2 for Jason: legislation.gov.uk first where it speaks?

- **Aim:** `fix-where-owned` and `law-text-wins`.
- **Figures (§3):** legislation.gov.uk states the operation on 95% of text changes; where both speak they agree on 92.4% (the round 92.7%); they differ on 2,339 (846 in the round); the law's text alone speaks on 5,459 (1,711).
- **Options:**
  - **(a) The law's text first, as now** (RULES `primary-first-derived-fills`). The gate stays two-way over D and L; a misread is fixed wherever it is found.
  - **(b) legislation.gov.uk first where it speaks, as for dates and extent** (`feed-differences-are-patterns-by-feed-coverage`, `extent-feed-first-where-it-speaks`): its operation and level are used unless the amending law's words prove them wrong; the reader's fixes are limited to the changes it alone reads (L, and what legislation.gov.uk leaves out); a misread found only where legislation.gov.uk speaks is a known limit. Needs Evidence to change (raised as for #202); until then the label takes the law's text.
- **Recommendation: (b).** It is the rule you set for the other two readers; legislation.gov.uk's coverage is highest here (95%); and the earlier steps' cost came from chasing D groups across every family. The gate keeps D as the yardstick, so a pattern in L is still found by its D twin.

**Decided (Jason 2026-11-26):**
- **Decision 1: all four, as two sessions** (recommended): `2026-11-26-amending-law-reader-stamps.md` ((a) + (d) + (b); (b) is Store and build's code, done there on this go), then `2026-11-26-amending-law-reader-step-procedures.md` ((c)). Pending, placed in the round meta before step 6.
- **Decision 2: (b), legislation.gov.uk first where it speaks** (recommended). RULES `amending-legislation-gov-uk-first-where-it-speaks`. The build change is Evidence's, parked (frontmatter); the gate's split by coverage goes into the step procedures session.

## 7. Close (2026-11-26)

- **Docs changed:** `AMENDING-LAW-READER.md` (new, draft; README index), RULES (the new rule), WORKFLOW §6 and the skill (pointers), `amendment/CLAUDE.md` (new). No table or flow changed, so DATA-ARCHITECTURE waits for the stamps session.
- **Not run:** the `ReadPass.stale?` count and the strata (read-only, offered). The index files and `git log` already show every amender stale; the step's write gives the strata.
- **Parked bugs:** the 32 open (26 distinct) go to the step's plan as they stand; the 2026-11-03 entries repeated on 2026-11-10 are counted once there.
