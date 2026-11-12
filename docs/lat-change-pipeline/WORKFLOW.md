# LAT Change Pipeline: Workflow

The pipeline has 14 steps, numbered from 0: Making laws (added 2026-11-04, before the second family) comes before Sources, so the later steps keep their numbers. Each step has one job and a check that says whether the job is done well enough to move on. A family of laws goes through the steps in order; a step trusts the steps before it. What the pipeline is for, and three changes traced end to end, are in the [README](README.md). Terms are in the [Glossary](GLOSSARY.md).

All commands run from `backend/`. `F` is the family name as the register spells it, e.g. `"OH&S: Occupational / Personal Safety"`.

**Pass rules below are as last used, on OH&S (October–November 2026); Maritime Safety (2026-11-04 to 11-07) ran each step under a pass rule fixed in its plan.** Several moved during that run: from "a clean agent sample", to "no new defect", to a statistical bound, and finally (at the switch-over) to a pass decided by code. Under the new process (see [How a step is run](#how-a-step-is-run)), each step's pass rule is fixed in its plan before work starts, and checked in code first.

## The steps at a glance

| # | Step | Writes | Check skill |
|---|---|---|---|
| 0 | Making laws | the making text verdict in `legal_register` (through `Making.record`); LAT rows for the laws decided making (a parse, with Jason's go) | none (`mix lat.making_laws`) |
| 1 | Sources | the CLML store (fetch, with Jason's go) | none (`mix lat.sources`) |
| 2 | Feed reader | feed claims (via the build) | `feed-reader-check` |
| 3 | Markup reader | markup claims (via the build) | `markup-reader-check` |
| 4 | Commencement reader | `commencement_rules`; commencement claims | none (recipe below) |
| 5 | Extent reader | `extent_rules`; law-text territory claims | `extent-reader-check` |
| 6 | Amending-law reader | `amendment_rules`; law-text claims | `amending-reader-check` |
| 7 | Merge | `provision_changes`, `provision_change_claims` (via the build) | `merge-check` |
| 8 | Evidence | chosen values in `provision_changes` (via the build) | `evidence-check` |
| 9 | Label fold | nothing (pure; read by steps 12–13) | `label-check` |
| 10 | Measures | verdict files; nothing in the database | `measures-check` |
| 11 | Store and build | `provision_changes`, `provision_change_claims`, `lat_events` | `store-build-check` |
| 12 | Labels side by side | nothing (computed beside the old labels) | none (`mix lat.label_check --strata`) |
| 13 | Switch-over | `lat_label_timeline` (through `LabelRefresh`) | `switch-over-check` |

Steps 2–8 all land in the change register through one build (`mix lat.vocabulary --check --family F`), so "writes" there means what the step contributes to it.

---

## 0. Making laws

**Aim.** Every live law in the family (in force or part revoked) is decided making or not from its own text, and each making law has LAT rows. LAT holds rows only for in-force making laws, and every later step places changes on those rows; a making law without rows drops out of every step and gets no labels.

**Why a step.** For a law without rows, `is_making` is an estimate: the metadata detector, legacy duty types, or a value set before the resolver. Fractalaw's DRRP reading is finer but slow to arrive. On Maritime Safety, 158 of 174 live laws had no rows and none of their estimates had been read from the text.

**Inputs.** The register (`legal_register`: family, live, the making fields), the CLML store (each law's body) and `legal_articles` (which laws have rows).

**Outputs.** A verdict per law (`making`, `not_making`, or none with a reason) in `making_text_verdict` and `making_text_reason`, recorded through `Making.record`. The resolver's `law_text` tier ranks below a human review and fractalaw's enrichment, and above every estimate. A report, `backend/data/reports/making-laws/<family>.csv`. Then LAT rows for the laws newly decided making.

**The rule.** A law is read provision by provision, outside quoted inserted text:
- **not making:** every operative provision is an amending instruction, a revocation, a commencement, or standard wording (citation, interpretation, extent, application, review, transitional);
- **making:** at least one own provision states a requirement ("shall" or "must") outside quoted text and outside a modification ("shall have effect as if");
- **no verdict, to Jason's list:** powers only ("may"), no XML upstream, or text not read.

**Check.** `mix lat.making_laws --family F` (read-only; `--fetch` fetches missing bodies, `--apply` records the verdicts; ask Jason first for both). The checked laws (human review and fractalaw verdicts in the family) are a fixture test.

**Pass rule (Maritime Safety, first use).** The rule is unit-tested by kind; the classifier agrees with every checked law, or each disagreement is decided by Jason; every live law has a verdict or is on the list, and the list is at most 10% of the family; two runs give the same report; every law decided making has LAT rows after the parse, or is named with a reason.

**Skill.** None.

## 1. Sources

**Aim.** Every document the later steps need for the family is held locally, or known to be absent upstream.

**Inputs.** The register (`uk_lrt`: each law's change statistics and validity date), the CLML store (`backend/data/cache/clml/`), and the stored changes (`provision_changes`), whose gaps say which further documents are needed.

**Outputs.** A report of needed against held, by need: own text, own feed, territory (each amending law's body; for an SI with no extent, its introduction and its enabling Acts), dates where the feed gives none, and the backlog the feed doesn't record. With `--fetch`, the missing documents.

**Check today.** `mix lat.sources --family F` (read-only). `--fetch` fetches; ask Jason first. The same gate re-runs at the end of every `mix lat.vocabulary --check`.

**Pass rule as last used.**
- Every needed document is held, or missing with a reason (no XML upstream, 404, fetch failed, out of scope).
- A held copy older than legislation.gov.uk's latest fails until refetched or explained.
- Each law's stored feed matches the register's change statistics, or the difference is explained.
- The counting rules are unit-tested; two runs give the same report.

On OH&S it passed on 2026-10-22. When later steps added needs, the gate failed again at Store and build (565 failures, deferred to the next pass): a passed step is not re-checked unless something re-runs its gate.

**Run the gate after one build (from Maritime Safety, 2026-11-04).** The territory, dates and backlog needs come from the stored changes, so a family with none built shows only own text and feeds. The order is:
1. fetch the feeds;
2. build the family's changes once (`mix lat.vocabulary --build --family F`, after a restore point of `provision_changes,provision_change_claims,lat_events`);
3. gate, and fetch what fails;
4. one more round for needs the fetch itself adds (an introduction naming enabling Acts).

On Maritime Safety, the build took the needs from 235 to 682, and three fetch rounds held them all. A feed whose register statistics are newer than it needs refetching and its law rebuilding; that added 4 needs. On Environmental Protection (2026-11-08), 306 → 1,422 needs, four rounds.

**Register differences.** Re-read the differing laws' statistics through the register's own stage first (`StagedParser` `:amended_by`, no write). That stage writes the feeds it reads to the store, so any law whose feed moves must be rebuilt. Apply the re-scrape after Jason's go, with a restore point of `legal_register`. It goes through `LiveStatus`, which can re-decide a law's live status from its feed: on Environmental Protection, two Aggregates Levy SIs became revoked, both whole revocations not yet applied to the text. A difference that remains, with its cause found, goes in `test/fixtures/sources/explained.json` (law → reason), which the gate reads. Example: the register reads one page of 1,000 effects, so EPA 1990 and the Environment Act 1995 are undercounted (parked: Register).

**A commencement order is held with its schedules** (Jason 2026-11-05). An order's article often brings in "the provisions specified in column 1 of the Schedule to this Order": the Schedule is the order's table, and without it the order reader reads nothing. Fetch orders with `mix clml.fetch --whole --laws …` (body and schedules); a plain `mix clml.fetch` fetches a LAT scope, the body only. An order counts as held when its schedules are stored, or stored as missing (legislation.gov.uk has none: its `ScheduleParagraphs` is 0). `mix lat.commencement --read-orders` lists the orders not held so in `data/reports/commencement-rules/orders_missing.txt`. On 2026-11-05, 31 orders' Schedules were missing (54 statements read as nothing, among them Maritime Safety's SI 1995/965), and 510 held orders had no schedules record.

**An SI's introduction is held only when it is stored** (Maritime Safety: Extent reader, 2026-11-05). The Extent reader reads an SI's enabling powers from its made introduction, through the enabling cache (`data/cache/enabling/<law>.json`).
- **Fixed 2026-11-08 (Environmental Protection: Sources).** `lat.sources` used to count the introduction held whenever that cache file existed, even as `[]`: a fetch that failed, or one from before the CLML store (12 Maritime amenders on 2026-11-05, `enabling-cache-empty-counts-held`). `Sources.introduction_status/2` now counts an empty cache as held only when the introduction is stored, and as absent when every introduction path is a stored 404 (SI 1992/682); otherwise not fetched, and `--fetch` retries it (`EnablingCache.get(law, retry_empty: true)`). Re-parse a held introduction offline with `EnablingCache.reparse/1`, which never fetches.

**Skill.** None. The `nas-data-sync` skill covers the store itself.

## 2. Feed reader

**Aim.** Each changes-feed effect becomes changes on the right provisions, carrying the effect's facts exactly as the feed gives them. Whether the feed is right is the Evidence step's question.

**Inputs.** The stored feed pages (`clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz`) and the family's LAT rows (`legal_articles`).

**Outputs.** Feed claims per effect and target: operation, level, date or dated stages (keyed `effect id@date`), `by`, effect extent, territorial application, savings, `commenced_by`, and the affecting provision as a pointer.

**Check today.**
1. Pattern catalogue: `mix lat.feed_patterns` over every stored feed (about 2½ min cold, after a catalogue or reader edit; about 4 s warm: #195); each new pattern accepted, fixed, or marked pending until `feed_patterns_test.exs` passes.
2. Gate and placement: `mix lat.feed_check --family F`; our faults must be 0.
3. Repeatability: the same seed twice into two sample files, compared with `cmp`.
4. Golden: `mix lat.vocabulary --golden`.
5. An agent judges 50 sampled effects against the feed and the law text.
6. Tell-tales (finer forms the feed names that we don't hold) are raised against the LAT parser.

**Pass rule as last used.** Sources held; our faults 0; repeatable; golden all-pass; the catalogue test passes; the agent finds nothing wrong outside the known patterns.

**Environmental Protection (2026-11-09).**
- **The check:** 11,674 effects in 122 laws; our faults 0; 6,386 placed.
- **Fixed in-step:**
  - an amendment to an earlier amending law written with the law named straight after "earlier amending" (`earlier-amendment-in-either-form`, Decision 2);
  - each stage of a staged removal named its first stage's order (`each-stage-its-own-order`, Decision 4);
  - a lettered Part numbered in Arabic by the feed and in Roman by the text ("Pt. 2A", row pt.IIA: 24 effects placed).
- **The sample:** `--sample` now writes each change's `commenced_by` and each in-force entry's `commencing` order, so the agent audits them.
- **A scoped law needs its body.** The build and the readers read the body, while Sources counted a scoped law's stored fragment as its own text. So the Aggregates Tax (Scotland) Act 2024 was built with 0 changes until its body was fetched (Decision 1). Parked against Sources: 82 scoped laws hold no body.
- **Reader fixes leave stored changes one reading behind** until the family's build, and a switched family's laws until their refresh.

**Skill.** `feed-reader-check`.

## 3. Markup reader

**Aim.** Each change element in the revised text becomes one change on the provision where it sits, carrying what the markup states.

**Inputs.** The stored law text (`clml/{type}/{year}/{number}/body/data.xml.gz`), the feed (to compare keys) and the LAT rows.

**Outputs.** Markup claims: operation, level, retained text, territory (`Extent`), and, for a legacy ChangeId, the note's cited law and amending provisions as identity pointers.

**Check today.**
1. Pattern catalogue: `mix lat.markup_patterns` (about 5½ min cold, about 5 s warm: #195); new patterns decided until `markup_patterns_test.exs` passes.
2. Gate and placement: `mix lat.markup_check --family F --all`; our faults 0. It also counts the markup's keys against the feed (in the feed, not in it, legacy), for the Merge step.
3. Repeatability, golden and an agent on 50 sampled changes, as for the feed.

**Pass rule as last used.** Sources held; our faults 0 for changes and for note placements (the check's PASS counts both since 2026-11-09); repeatable; golden all-pass; the agent finds nothing wrong outside the known patterns.

**Environmental Protection (2026-11-09).**
- **Check:** 3,251 changes in 72 laws, our faults 0; note placements 2,676, faults 0.
  - A scoped law is read for its scope: `outside_lat_scope`, 131 for the Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024 (Decision 1, rule `read-a-law-for-our-scope`).
- **Three reader-side fixes:**
  - a substitution's new words listed under the Repeal's key by the reader, the check and the catalogue (`Markup.substitutions/1`);
  - the catalogue's held examples kept first on regeneration;
  - a number inside quoted text is not the provision's own (Decision 3, rule `quoted-number-is-not-own`).
- **Catalogue:** 4,185 laws, 853 patterns, 55 new accepted.
  - Held readings moved: 0 at the first run, 2 at the second (Decision 4).
  - Each cold run took about 25 min, not #195's 329 s (#198).
- **Plan the catalogue's cost:** a reader fix moves the catalogue's code version, so each fix after the catalogue costs one more cold run. Batch the step's own fixes before the first run.
- **Agent:** seed 61, 152,593 tokens; placement 50/50, facts 49/50, one new class, fixed.

**Skill.** `markup-reader-check`.

## 4. Commencement reader

**Aim.** The law's own commencement clause and the orders made under it give each provision dated `commenced` changes (staged when it came in partly first), and give an otherwise undated change the date its amending provision came into force.

**Inputs.** The law's text, the commencement orders held (body and schedules: step 1), the amending laws' commencement provisions, and pointers (feed affecting provisions, notes) to the amending provision.

**Outputs.** `commencement_rules`; commencement claims (`date`, `partial`, `commenced_by`, and `via` when a pointer led to the date).

**Check today.**
1. Both catalogues: `mix lat.commencement_patterns` (own commencement sentences, about 4¼ min cold, under 2 min warm: #195) and `mix lat.order_patterns` (orders, about 30 s), until `CommencementPatternsTest` and `OrderPatternsTest` pass. Each also reports its **leftovers** (`Commencement.Leftovers`): the words of a statement that bear on a date (a date, a provision, an exception, a qualifier, a relative day) that no rule read from it uses, grouped and ranked by the rows they reach, every group reviewed in `leftovers.json` (`LeftoversReviewTest`). This replaces agent rounds as the way to find a family's new forms (2026-11-05).
2. The readers' re-read (ask first): `mix lat.commencement`, then the rebuild.
3. `mix lat.commencement_check --family F`: every row dated, left to an order, or undated with a reason; our faults 0. Its **leftovers gate** lists every leftover reaching the family (its laws' own clauses, the orders held for them, its held amending laws), each with its group's status; PASS needs every one `known:`.
4. Golden. At most one agent pass, and only to label leftover groups; never sample, fix, resample (Jason 2026-11-05).
5. Repeatable: two `--sample` runs on one seed, identical.

**Pass rule** (Decision 1 (c), Jason 2026-11-05). `lat.commencement_check --family F` prints PASS: our faults 0 and every leftover reaching the family named (`known:`); every leftover group reviewed (`LeftoversReviewTest`); the catalogue tests pass; repeatable; golden all-pass. No agent rounds. (Before: the stopping rule of 2026-10-24, on an agent sample.)

**Environmental Protection (2026-11-09).**
- **Check:** 35,518 rows in 122 laws; on stored rules after the re-read, rows' faults 0 (9,954 before: 55 laws never read); 27,880 dated, 4,595 left to orders; every leftover reaching the family named (23 not named before).
- **Reader fixes, each with a test:**
  - a Part, or a heading with every provision left to an order, takes its provisions' outcome;
  - a citation sentence's date (", shall come into force on …", "The title of these Regulations is …. They come into force …");
  - a statement's exceptions with brackets inside, and "apart from", subtracted;
  - a staged item opening with its purpose;
  - "These provisions …—" heads its list;
  - an item keeps its own provisions beside another Act's;
  - a "the following" order head's qualifier reaches its items (the parked class), but never a completing or place head;
  - an order's qualifier after a made-relative day;
  - an order's whole-Act form after "Subject to article N, the provisions of";
  - a law whose only text rules tie its Schedules keeps its outcome without them.
- **The check's own errors fixed:** another law's provisions split by a dash or commas; "in relation to England" taken for a qualifier.
- **The store:** an order listed for two laws kept only one law's rules, because its re-read replaced its rules by source alone. `Store.write/3` takes `commences:`.
- **Catalogues:** 24 new patterns (12 pending, none reaching the family); 36 held readings moved (Decision 2), after a dry run at the last commit's code over the same store separated this step's changes from the store's new laws.
- **Decision 1:** five one-law wordings named known limits.
- **Re-read:** 113 order-list title searches.
- **Lessons:**
  - Run a catalogue's dry run with `--out` to a scratch copy, because a run writes the generated fixture files even without `--accept`.
  - Give `--read-amending` only amending laws, never commencement orders.

**Skill.** `commencement-reader-check`. Background: [COMMENCEMENT-GUIDE.md](COMMENCEMENT-GUIDE.md).

## 5. Extent reader

**Aim.** Where each amending law's changes apply is read from its own words. A statement that can't be read fully gives no territory, never a default.

**Inputs.** The amending laws' text (body and schedules), SIs' introductions (the enabling cache) and their enabling Acts.

**Outputs.** `extent_rules` per amending law; law-text territory and extent claims on each change.

**Check.**
1. **Recall sweep.** `mix lat.extent_sweep --family F` finds sentences the catalogue doesn't class.
2. **Catalogue.** `mix lat.extent_patterns --accept`, then review the fixture diff.
3. **Extents.** `mix lat.amending --extents --amending <laws> --cached` writes `extent_rules`, reading the enabling parents first. Take a restore point of `extent_rules` before it.
4. **Rebuild.** `mix lat.vocabulary --build --family F`.
5. **The check and gate.** `mix lat.extent_check --family F` (seconds, read-only). It lists every family text change with no bound, by cause and amending law (`Extent.Withheld`). Each cause carries its words: the law's unread statements, or why it has no powers (introduction not held, no powers clause read, a parent not read, a provision placed nowhere). Each has a status in `test/fixtures/extent_patterns/withheld.json`: `fix:`, `known:` or `check:`, keyed `"<cause> @ <law>"` or by cause. The statuses work as the commencement gate's do.
6. **Golden:** `mix lat.vocabulary --golden`.
7. **Shapes**, when list items may be dropped: `mix lat.extent_shapes --out DIR` (about 2 minutes warm). Every catalogue sentence's lead and lettered items are masked into shapes and counted. Then come each list item's verdict against the reader's lists, each shape's review bucket, over-reach, and default sentences' unlisted items. These are CV-S05c's scripts as one task (#192), with outputs the same byte for byte as the Python run's.
8. **Census**, after a reader fix batch: `mix lat.extent_census --out DIR [--diff OLD.jsonl.gz]` (about 40 seconds, read-only but for DIR). An independent finder reads every catalogue and sweep sentence of every held law into statements, and judges each provision a statement names against the stored reading. It writes each sentence's worst verdict (`sentences.tsv`), apply statements of scope rather than place (`scope.tsv`), stored refs no statement names (`unnamed.tsv`), the counts (`stats.json`) and the recall bench (`bench.txt`); `--diff` writes per law how the reading changed since an older dump. The finder shares no code with the reader, and a test holds it to that. These are CV-S05d's scripts as one task (#192), byte for byte.

**Pass rule** (Decision 1, Jason 2026-11-05, Maritime Safety: Extent reader):
- `lat.extent_check --family F` prints PASS: our faults 0, no sweep miss in a `read:` form, and every no-bound cause named `known:`;
- the catalogue test passes (`ExtentPatternsTest`), and every form fixed has its unit test;
- golden all-pass.

No agent rounds. Before this, the rule was statistical (2026-10-28): pooled agent seeds, with 95% upper bounds under 2% of changes and 5% of laws.

**An SI's powers** (Maritime Safety, 2026-11-05). An SI that states no extent extends as far as its enabling provisions. Each provision is placed by its parent Act's extent clause; a parent stating no extent at all takes the extent legislation.gov.uk states on the provision (RULES.md `powers-of-an-act-stating-no-extent`). Whenever the powers parser (`EnactedBy.EnablingProvisions`) changes, diff its parse of every held introduction before and after, and check each change in its text.

**Environmental Protection** (2026-11-09/10). 553 amending laws, 249 never written before, so write 1 comes first: the real gate is only known after it and the rebuild (231 → 96 causes). Then the readers are fixed by cause, widest first, in two rounds. Each round ends with one cold catalogue dry run to a scratch copy (with `expected.json` copied in, so its comparison is real), the held moves put to Jason, then `--accept` and a write.
- **Don't edit `extent/` code between a dry run and `--accept`.** Any change stales `Extent.ReadVersion`, so the accept runs cold again (13 min, not 1).
- **A powers-parser change also covers `EnablingCache`'s register title lookup.** The diff over every held introduction and the offline re-parse of the changed SIs (`EnablingCache.reparse/1`) both apply: the powers lookup reads the cache, not the introduction.
- **Another family's check after a write:** its unnamed causes can be relabelled (no powers → provision not named) while its build is stale. Compare the causes by law against the reading before calling it worse.
- **Result:** our faults 0, causes 231 → 0 not named (139 known), bound by the law's text 45% → 74%, no powers 662 → 115 changes.

**Skill.** `extent-reader-check`.

## 6. Amending-law reader

**Aim.** Each amending provision's own words give the right amended law, target provisions, operation and level. The law's text wins where it speaks, so a misread here overrides a correct legislation.gov.uk record: precision is what matters.

**Inputs.** The amending laws' text, the amended law's rows, and the pointers (notes, feed) saying which amending provisions to read.

**Outputs.** `amendment_rules`; law-text claims (operation, level, `by`).

**Check.**
1. **The read pass current.** `ReadPass.stale?` for every family amending law with its text held. A law that points to it but was not read for (given LAT rows since) makes it stale. Read with `mix lat.amending --read --amending <laws>`, one law at a time, after a `--preview`. Take a restore point of `amendment_rules`, `extent_rules` and the amendment index first.
2. **Catalogue:** `mix lat.amendment_patterns --laws <every family's laws so far> --accept`. A `--family` run replaces the fixture, so the catalogue is run over every family's laws together (Decision 2, 2026-11-06). Every changed reading is reviewed.
3. **Pre-flight for a fix:** `mix lat.preflight --family F` (compile with warnings as errors, the architecture tests, golden from inputs, the checked rows), then `mix lat.amending --read --preview --amending <family laws> --diff FILE` and `--preview --regression --diff FILE`. The field diff (`Amendment.Review.RuleDiff`) groups old against new rules by the fields that differ; class every group before the read pass.
4. **Rebuild**, then golden from inputs: `mix lat.vocabulary --golden` (never only `--check`, which scores golden laws outside the family from stale stored changes).
5. **Strata:** `mix lat.amending_check --family F --strata` gives:
   - A, agreeing with legislation.gov.uk;
   - D, disagreeing;
   - L, law text only;
   - and the agreement rates.
6. **The gate:** `mix lat.amending_check --family F --gate [--all]` (seconds, read-only).
   - **Grouping.** Every D and L change is grouped by cause and amending law (`Amendment.Disagreement`):
     - `quote-new-number` and `quote-dropped-number`, by design;
     - `operation …` and `level …` conflicts;
     - `unjoined`;
     - `no operation from legislation.gov.uk: …`;
     - `law text only: …`.
   - **Review.** Each group is read in the amending law's text and rows. Its status goes in `test/fixtures/amendment_patterns/disagreements.json`: `fix:`, `known:` or `check:`, keyed `"<cause> @ <amending law>"`, else by cause.
   - **The review's tasks** (Amending-law reader: review tooling, 2026-11-12): `--gate --dump FILE` writes each group's changes with their provisions' words, rules and legislation.gov.uk's claims; `mix lat.amending --amending A --provision ID` probes one provision; `--gate --name-standard --review REPORT` proposes the standard wordings beside each group's words (a dry run; `--write` once Jason decides). The write sequence is in the `amending-reader-check` skill, step 6.

**Pass rule** (Decision 1, Jason 2026-11-06, Maritime Safety: Amending-law reader):
- the read pass is current (no stale family amending law);
- the gate prints PASS: every D and L group named `known:`;
- the catalogue test passes over every family's laws, with each fixed form unit-tested;
- golden all-pass;
- no regression in the families already through (their strata).

No agent rounds. A is not sampled: there the law's text and legislation.gov.uk agree, so an error needs both wrong together. Before this, D and L were checked in full by agents and A by pooled samples (2026-10-28).

**Environmental Protection** (2026-11-10). 304 of the family's 500 amending laws were stale, so write 1 (read pass and rebuild) comes first: 230 → 202 groups not named. The review finds most misreads hidden in the by-design groups (quote-dropped repeals of a Schedule's paragraphs, an Order's paragraphs read as articles). They are fixed together, then one write.
- **Batch every fix before write 2.** Field diff (then `rule_diff.exs`, now `--read --preview --diff FILE`: stored rules against a fresh reading, by source, law, operation, level, treatment and targets) over the family's amenders and the regression set. Read every class of change, and fix over-reaches before any write.
- **Review the field diff fully before the catalogue dry run.** Classes found in the catalogue afterwards (Decision 2) cost a second cold catalogue run.
- **Any edit under the reader's files moves `ReaderVersion` and stales every amending law**, a refactor or a compiler-warning fix included. Run `mix compile --warnings-as-errors` (the hook's check) before the read pass, never after. So too `mix test test/sertantai_legal/architecture` (a "come into force" pattern belongs to the commencement readers; version coverage).
- **Result:**
  - the read pass current;
  - the gate PASS, 240 groups named;
  - A 2,950 → 3,192, D 396 → 391, L 536 → 391;
  - Maritime's parked group named (PASS);
  - OH&S 91 → 88 not named.

**Skill.** `amending-reader-check`. Background: [AMENDMENT-GUIDE.md](AMENDMENT-GUIDE.md).

## 7. Merge

**Aim.** One change per real event, whichever sources state it.

**Inputs.** The claims from steps 2–6.

**Outputs.** Change records in `provision_changes` with their claims in `provision_change_claims`, each with its key and the aliases merged into it.

**Check today.** `mix lat.merge_check --family F --strata` gives J (joined: two or more sources; over-join risk), U (law text alone beside legislation.gov.uk's likely same event; split risk) and C (single-source changes beside another source's; split risk), the join rate, and the spread tell-tale (keys under more than three top provisions).

**The gate** (`--gate [--all]`, `ChangeVocabulary.MergeGate`; Decision 1, Maritime Safety: Merge, 2026-11-06). Every merge decision is grouped by a cause from code, by amending law:
- joined changes by how they joined: same effect id; the law's text naming legislation.gov.uk's own amending provision; a legacy note naming the feed's; or the weaker partner joins;
- with a `dates differ` suffix where legislation.gov.uk's date and the law's commencement differ;
- the over-join tell-tales: one source's several records, an operation conflict (inherited from the Amending-law reader's gate) and legislation.gov.uk's unlike operations;
- U, C and markup-only changes;
- each spread key.

Each group is reviewed once in the sources' records and named in `test/fixtures/merge/merges.json` (`known:`, `fix:` or `check:`). Causes named alone, never by law, are the by-design ones.

**Pass rule** (Decision 1, picked with Gemini):
- the gate prints PASS;
- **one agent pass**, of 50 changes drawn from the by-design groups only (`--stratum J --by-design --sample FILE --n 50 --seed N`, a new seed), to find a class the grouping hides; what it finds becomes a code group, and there is no resample;
- no regression in the families through (their U, C and spread);
- golden 27/27;
- the join rate and a quality statement published.

Before this, OH&S used agents over U and C in full and pooled J samples to the 95% bound (2026-10-28; 7 rounds).

**Environmental Protection** (2026-11-10). The changes were current after the Amending-law reader's last write, so no build comes first. The gate was at 99 groups not named (294 changes), and OH&S's at 83, parked. Both were reviewed in the sources' records together. Each change was checked by shape in code (one operation, and the note citing the change's law); each unjoined change and candidate was read with the changes beside it. That review found no Merge fault. Its splits were:
- an Act read as starting at Royal Assent, kept apart by the day rule (the Commencement reader's);
- list items read twice (the Amending-law reader's);
- the feed's `#made` maker records carrying the later law's affecting provisions (the Feed reader's);
- three merge forms of 1 to 3 changes, named known limits (Decision 1).

**The one agent pass** (seed 61, 50 by-design changes, 179,044 tokens): 48 OK, 2 new classes, which the grouping had hidden.
- **The Merge's own:** one instruction joined at one place lent that event's feed facts to places the feed records with effects of their own (SSI 2005/658 reg.2(2): key on 39 provisions). `joined_instruction` now lends nothing where another effect by the same law names the joined event's amending provision (Decision 3).
  - The in-memory preview of 7 laws caught two over-strict first rules before any write.
  - One restore point and one rebuild of the three families followed.
- **The gate gained two causes:** "a joined event lent to a provision its effect doesn't name" (268 left, each checked mechanically: the instruction is the feed effect's own amending provision) and "markup alone beside its joined twin".
- **Result:**
  - Strata: EP J 4,667 / U 33 / C 17; join rate law text 86.0%, markup 95.8%.
  - OH&S U 16 → 17: SI 2022/8 reg.6(a) at reg.10 is no longer lent another place's effect.
  - Maritime U 6, C 4.
  - All three gates PASS; golden 27/27.

**Skill.** `merge-check`. Design: [CHANGE-IDENTITY-DESIGN.md](CHANGE-IDENTITY-DESIGN.md).

## 8. Evidence

**Aim.** Each attribute of a merged change comes from the right source by the evidence table, and every disagreement between the law and legislation.gov.uk is reported like for like.

**Inputs.** Merged changes and their claims.

**Outputs.** The chosen value and winning source per attribute (stored on `provision_changes`); tiers and the conflict report are worked out on read.

**Check today.** `mix lat.evidence_check --family F --strata` gives V (value conflicts: the law against legislation.gov.uk), D (markup against feed with no primary claim, by pattern) and A (several sources agreeing), and the winning source per attribute.

**The gate.** `mix lat.evidence_check --family F --gate [--all]` (`ChangeVocabulary.Gate.Evidence`) groups every V conflict and D disagreement by its attribute, its sides and the amending law: `"operation: law_text inserted against feed substituted @ <law>"`. Each group is named in `test/fixtures/evidence/evidence.json` (`known:`, `fix:` or `check:`).
- An operation or level conflict of the law's text takes the Amending-law reader's status (`disagreements.json`), so nothing is reviewed twice.
- The gaps (a text change's value no source claims) are printed by cause. They are a published figure, never a failure.

**Pass rule** (Decision 1, Maritime Safety: Evidence, 2026-11-06; the shape picked for Merge):
- the gate prints PASS;
- **one agent pass** of 50 A changes on a new seed (`--stratum A --sample FILE --n 50 --seed N`), to find a class the grouping hides; what it finds becomes a code group, and there is no resample;
- no regression in the families through (their V and D);
- golden 27/27;
- the winners, the gaps and a quality statement published.

A wrong value chosen from a misread primary claim is the reader's: it is named `known:` with its parked bug. The table's order is judged, not the reading.

Before this, OH&S used agents over V in full and D by pattern, and pooled A samples to the 95% bound (2026-10-29; 5 rounds).

**Environmental Protection** (2026-11-10/11). The changes were current after Merge's rebuild. The gate was at 43 groups not named, OH&S's parked group at 14 and Maritime's at 3 (new date groups since later rebuilds). All 60 were read together in the sources' own records: the feed effect, the markup's note, the amending words, and the commencement rule through the evaluator in the build's own context. The evidence table's order was right throughout.
- **Wrong chosen values, 154, all another step's:** misread primary claims winning, as law-text-wins orders. Three new Commencement-reader classes were parked: an order's "in section 86— (i) …" read as the whole section (42); an order item's heading or a Welsh order read as partial (22); an own clause's excepted provisions left on the general date (22).
- **By design and legislation.gov.uk's own:**
  - the "as amended by" chain (105);
  - a Welsh SI cited by its UK S.I. number, one law under two names (29, Decision 2: never matched by year and number);
  - amendments made before the amended law's own start, and feed date slips.

**The one agent pass** (seed 62, 50 A changes, 155,068 tokens): 36 OK, 12 gaps, 2 wrong, one new class. legislation.gov.uk dates a stage "in accordance with" its law's own clause on the day that law was made: a placeholder.
- **Fixed in the table (Decision 4):** `Readers.AffectingMade` claims the affecting law's made or enactment day (`legal_register`) on such a stage, and `Evidence`'s `:not_made_day` never takes the feed's date on it (RULES `feed-placeholder-date-is-no-date`).
- **Reach:** of 145 such records in the three families, 15 fall on the made day (SI 2016/562: 12; Finance Act 2026 Sch.14: 3).
- **Checks:** the in-memory preview moved exactly those dates to gaps. Then a restore point and one rebuild.
- **Result:**
  - Strata: EP V 471 / D 182 / A 5,653; OH&S V 146 / D 38; Maritime V 195 / D 13.
  - Gaps: EP date 380 → 391 (the placeholders), commenced_by 4,128.
  - All three gates PASS; golden 27/27.
- **Build with the full family name:** `--family "OH&S"` matches four OH&S families (189 laws); the step's family is "OH&S: Occupational / Personal Safety" (149). The bare name built 40 laws of the other three families for the first time (kept, Jason 2026-11-11).

**Skill.** `evidence-check`.

## 9. Label fold

**Aim.** A provision's resolved changes fold into the right label periods under the agreed conventions.

**Inputs.** The stored changes (`provision_changes`), the LAT rows and their extents, and the law's start (stored with the build, `Store.start/1`).

**Outputs.** Label periods (status, territory, in force from, changed by, commenced by, a tier per field). Pure: nothing is written at this step.

**Check today.** `mix lat.label_check --family F --strata` gives S (rows each fold rule acts on, by shape), T (rows whose fold differs from today's label, by class; recorded only, it is Labels side by side's) and R (random rows). G is golden from inputs on `golden.exs`.

**The gate** (`--gate [--all]`, `ChangeVocabulary.Gate.Label`; Decision 1, Maritime Safety: Label fold, 2026-11-06). Every breach in the family's folded rows is grouped by rule and the row's law, `"<rule> @ <law>"`:
- the label rules (`LabelRules`: before_amender, before_insertion, windsor_ni, no_made_period, saved_not_saved; legacy_unconfirmed listed apart);
- the table's rules (`LabelPeriods.violations/1`);
- the agent pass's classes as code: an empty field carrying a tier (`tier: empty field`), and a row started by a Part's or Chapter's insertion later than its own (`start: a container's insertion after its own`).

Each group is named in `test/fixtures/label/labels.json` (`known:`, `fix:` or `check:`); OH&S's file-listed rows (`KnownLimits`) stay apart. The gaps (undated starts and changes) and the S shapes are printed, a published figure. `--laws L1,L2` folds only the laws named (a pre-flight in seconds; the family fold takes 6–13 minutes).

**Pass rule** (Decision 1, Maritime Safety: Label fold, 2026-11-06; the shape picked for Merge):
- the gate prints PASS;
- **one agent pass** of about 45 rows (`--stratum SR --per 2 --n 23 --seed N`: S by shape, the rest at random, a new seed) in 3 batches, to find a class the code doesn't catch; a fold class becomes a gate check and is fixed by reach, an upstream one is parked; there is no resample;
- no regression in the families through (their gate and current statuses);
- golden 27/27;
- the shapes, the gaps, the statuses and a quality statement published.

Before this, OH&S used G, S and T by shape and R pooled to the 95% bound (2026-10-29; 10 rounds). Golden is never grown during a pass: new provisions go to `golden_extended.exs` for the next pass.

**Environmental Protection** (2026-11-11). The stored changes were as rebuilt at Evidence; the fold is outside the build's version, so no fold fix needs a rebuild. The gate began at 13 groups not named (1,440 rows), with OH&S's parked 1. The review found five classes, and the decisions fixed four in the fold (Decisions 1, 2, 4 and 5). The fifth, Welsh SIs held under UK SI names (440 rows), is parked with the Register (Decision 3). Decision 7 followed (undated repeals), then the agent pass, then Decisions 8 and 9 (the parked J6 and J4).
- **Never before its maker (Decisions 1 and 7):** an undated insertion or repeal by a later law begins at that law's first dated record on the row or anything holding it, else its making (`made_of` from the register). EPA Part IIA by EA 1995: 674 rows had been labelled from 1990.
- **The agent pass** (seed 211, 41 rows, 3 batches, 427,919 tokens): 24 OK, 2 fold classes, 11 upstream. The fold classes became gate checks, measured and fixed by reach: an own commencement before the law's general start dropped (1,720 rows in 4 laws), and an ancestor insertion's territory lost (10 rows in 4 laws). The upstream classes are parked with the Commencement reader, the Amending-law reader, the Feed reader and the Register.
- **Caught by the checks, not the tests:**
  - a status diff of OH&S at HEAD and now found Decision 7's first cut repealing a row that still shows its text;
  - undated starts rising 1,227 beyond the measure showed Decision 8's first cut blanking dated starts;
  - golden found the early-start rule moving a row's own later start back (Forestry Act 1967 s.1(4)(a)).
- **Result:**
  - Gate PASS for all three families (EP 8 groups named).
  - Current statuses unchanged, except REACH Pt XI, now repealed as today's label has it.
  - EP periods 68,074 → 69,135; undated starts EP +22, OH&S +12, Maritime +77 (Decision 8's gaps).
  - Credo: `Label.fold` (13 → under 9) and `Start.period` (29 → under 9) split into named functions.

**Skill.** `label-check`.

## 10. Measures

**Aim.** Every figure a step publishes can be believed: one name and one meaning, computed by code, tested, and replicable.

**Inputs.** The stored changes and the agent verdict files (`backend/data/reports/change-vocabulary/verdicts/<step>/<family>/`).

**Outputs.** Printed figures; the register of figures in the `measures-check` skill.

**Check today.** The audit and the gates come first, then the samples:

1. **Audit:** every figure the family's step sessions publish (closing `metrics:`), against today's store. A figure is the same; or moved, with the later commit that moved it named; or a finding. Before/after history, days, commits and tokens are out of scope.
2. **Every step's gate, re-run:** `draws.sh FAMILY SEED` (in the skill) runs each step's check with its strata, gate and sample: Making laws, Sources, the five readers, Merge, Evidence, the label fold, and `lat.measures`. A gate that passed when its step closed can fail after a later rebuild. Such a gate is raised and parked with its step, never named here.
3. **Replicable:** two passes of `draws.sh` on one seed. Samples are byte-identical (`cmp`); printed figures are identical once log lines are filtered out. The first pass runs before any code change.
4. **Hand check:** one agent pass, 2 batches, or none (Environmental Protection, Jason 2026-11-11). Without an agent pass, the hand sample still replicates, the measure-fault classes already found stay tested, and a few items are read by hand.
   - The hand sample is `mix lat.measures --sample FILE --n 50 --seed S`: text changes with their classes (who states it, law-text coverage, dating, merge stratum).
   - Ten items come from the extent check's sample, one per outcome, for the territory group.
   - Save the VERDICTS blocks as verdict files when the agents hand back.
   - A measure fault is fixed by TDD over the family, with no resample. An upstream fault is parked with its step.

**Pass rule as last used** (Maritime Safety, 2026-11-06; OH&S's of 2026-10-30, fitted to one agent pass):
- every in-scope figure is in the register, printed by code and tested, or marked "hand tally, report only";
- samples and figures replicate;
- the hand check finds nothing classed wrong by a measure once its faults are fixed;
- no regression (`mix test`, golden).

**Environmental Protection (2026-11-11):**
- No agent pass.
- Four gates and verdicts had moved since their steps closed: Sources (feeds stale by age alone, Schedules needed since), Extent, Amending, and one Making laws verdict. Each is parked with its step.
- The parked inline reads in `lat.sources` and `lat.vocabulary` moved into `Sources.Held` and `ChangeVocabulary.Show`, with tests.

**Skill.** `measures-check`.

## 11. Store and build

**Aim.** The change register is repeatable, fast enough for a fix round, and shows which built laws are stale and why.

**Inputs.** Everything the build reads: LAT rows, law text, feed, and the three rules stores.

**Outputs.** `provision_changes`, `provision_change_claims`, and a `changes_built` event per law in `lat_events` with the code version, its inputs' fingerprints and its output's digest (`changes_digest`, #194).

**Check today** (from Maritime Safety, 2026-11-06).
1. Restore point: `./scripts/nas/nas-backup.sh --tables provision_changes,provision_change_claims,lat_events --tag <tag>`.
2. Build A:
   - first bring every other stale stage up to date with `mix lat.vocabulary --build --stale` (#194: the stale changes rebuilt, then the switched labels folded again where their changes' digest, the fold's code or its inputs moved), so golden scores fresh changes. Do this once per fix round (RULES `earlier-families-rebuild-once-per-round`);
   - then `mix lat.vocabulary --check --family F`: the build, conflict counts, golden from the store, and **every step's gate** (`mix lat.gates --family F`).
3. `mix lat.changes_digest --built --out A.tsv`; build B (the same builds with `--build`); digest again; `cmp`.
4. `mix lat.stale --strict --switched` exits 0: no built law stale (an input, the code or a reader's readings), and no switched-family law's labels stale (#193). A reader reason is fixed by re-reading in the mode that wrote the readings (`lat.stale` prints it), then building.
5. Golden from inputs, and one agent hand check of the staleness sample (`mix lat.stale --sample FILE --family F --seed S`, drawn twice and compared with `cmp`).

**The whole-store catalogues read only what moved** (#195, 2026-11-08). `lat.feed_patterns`, `lat.markup_patterns` and `lat.commencement_patterns` keep each law's result in `CatalogueCache` (`data/cache/catalogues/`). The key is the catalogue's code version (`FeedPatterns.Version`, `MarkupPatterns.Version`, `CommencementCatalogue.Version`, held by `VersionCoverageTest`) plus a digest of the law's inputs: its stored files and rows, or for commencement its rows and start input. A re-run reads only the laws whose inputs or catalogue code moved, and prints `cache: N hits, M read`. Laws are read several at once under `LawRunner.Guard`, then taken in law order, so the catalogue is the one a serial run gives, byte for byte. A reader or catalogue edit pays one cold run. `--no-cache` reads every law afresh, and `--workers N` overrides the guard. Each law's examples are chosen alone in its parallel read and cached with it, for all three catalogues (`LawScan`: a law alone always finds room, so the examples the whole run asks of it are among those). The serial pass only looks them up; for commencement it also merges and checks each law's examples into `laws.json` (about 30 s). Commencement's warm run takes 104 s (from 228 s), most of it gathering each law's rows and start input.

**Every step's gate.** A rebuild after a step closes can move that step's gate: on Maritime Safety, three gates that had passed failed unseen. So the build's check re-runs all nine. Each check task returns its result (`ChangeVocabulary.Gate.Step`), and `lat.gates` exits non-zero on any failure. A failure belongs to its step and is parked there, never fixed here. `--no-gates` skips the gates for a fix round; the label gate folds the family (about 12½ min).

**The digest is of what is stored.** Values `Store.for_law` derives on read (tiers, conflicts) are not digested. A list built by iterating a map with atom keys comes out in atom-table order, which moves between runs (OTP 26+): on Maritime Safety it made 18 laws' digests differ with nothing stored moving.

**Pass rule as last used** (Maritime Safety, 2026-11-06):
- all 285 built laws' digests are identical across two builds;
- build time accepted by Jason (Maritime: 117 laws in 39 s);
- 0 stale after the build;
- every failing gate is already parked with its owning step;
- the hand check finds no verdict wrong;
- golden all-pass.

**Environmental Protection (2026-11-11):**
- **No agent pass.** The staleness sample was drawn twice and compared with `cmp`, and 3 items were checked by SQL.
- **106 built laws were stale on a reader reason:** commencement readings made by older reader code. Each was re-read in the mode that wrote it (`--read`, `--read-amending`, and `--read-orders` with laws named and without), which took under 2 min. Then `--build --stale` ran.
- **The results:**
  - all 445 digests identical across builds;
  - 122 laws in about 5½ min with 1 worker while a VM ran, nearly 4 min of it EPA 1990 and the Environment Act 1995 (accepted, Decision 1);
  - 0 stale;
  - six gates pass, and the three that fail (Sources, Extent, Amending) were parked in Measures.
- **The parked bugs fixed:** in-database restore copies now go to the `restore` schema (`SertantaiLegal.Restore`, DATA-ARCHITECTURE (f)), and `--conflicts` prints its groups in a fixed order.

**Skill.** `store-build-check`.

## 12. Labels side by side

**Aim.** The new labels are built in the timeline's shape beside the old ones, without writing, so every difference can be counted and later explained.

**Inputs.** The fold's periods (`LabelSource.timeline/1`) and today's `lat_label_timeline`.

**Outputs.** Nothing written. A count of rows that agree, differ today, or differ only in history: the baseline for the switch-over. A retirement list for the old path (`backend/data/reports/change-vocabulary/cv-05-retirement-list.md`).

**Check today.** `mix lat.label_check --family F --strata` (about 90 seconds cold on Maritime Safety, seconds once the fold cache is filled; see "The label tools fold once" below), and golden from inputs. It prints:
- the S shapes and the T differences by field;
- "timeline rows", the periods breaking the table's rules (`LabelPeriods.violations/1`);
- "side by side", each row in one class (`LabelStrata.totals/1`): agree, differ today, differ only in history, or no stored timeline;
- the gaps by shape (`Gate.Label.gaps/1`), a value no source gives.

There is no agent check: the conversion is a fixed mapping under unit tests (`label_periods_test`, `label_strata_test`). Save the output as the switch-over's baseline, in `backend/data/reports/labels-side-by-side/<family>-strata.txt`.

**Pass rule as used** (Maritime Safety, 2026-11-06). Golden 27/27; 0 periods breaking the table's rules; the four side-by-side totals printed and adding up to the rows folded; gaps printed by shape.
- **On OH&S** (2026-10-31): 28,307 periods, 0 breaks; 16,487 of 20,371 rows differed from today's labels.
- **On Maritime Safety:** 46,976 periods, 0 breaks. Of 24,434 rows, 18,898 agree, 2,350 differ today, 874 differ only in history, and 2,312 have no stored timeline.
- **On Environmental Protection** (2026-11-12, no agent pass, two runs identical): 69,136 periods, 0 breaks. Of 35,766 rows, 13,229 agree, 17,872 differ today, 2,366 differ only in history, and 2,299 have no stored timeline. Territory alone is the largest class (7,736 rows), from the family's partial extents and territorial versions. The cold run took 7 min 53 s with 1 worker while a VM ran.

**The single `changed_by`** (decided here on 2026-11-06, Maritime Safety, Decision 1). Where several laws made the text, it is the principal maker, never an amender of the amending law, then the latest made (RULES `changed-by-one-law-for-compliance`). `label_periods.ex` was in the build's version, so a change to it marked every built law stale. That was Store and build's parked bug. It was fixed by #194: the fold has its own version (`FoldVersion`), and a fold-only edit rebuilds no change.

**Skill.** None.

## 13. Switch-over

**Aim.** Every difference between the new and old labels is explained, and the family's timeline is then written from the merged changes.

**Inputs.** The new and old labels; the checked rows; the known-limit lists.

**Outputs.**
- `lat_label_timeline` for the family, written by `LabelRefresh` (with `changed_by_all` and `commenced_by`);
- the family added, by its exact name, to `config :sertantai_legal, :label_families`;
- the family's known-limit list, if any (`backend/data/reports/switch-over/<family>-known-limits.md`, read by `KnownLimits`).

**Check today** (skill `switch-over-check`):
1. **Causes:** `mix lat.label_shadow --family F` sorts every differing row by its first difference and the evidence behind the new value. A cause that names no evidence is looked at by hand, 12 rows; a class over 100 rows goes to Jason.
2. **Rules:** `mix lat.label_rules` runs each fault class as a check over every row of the family (for example, a change dated before its amending law was made; a period before the row's insertion). A breach is fixed by its owner, or, below the triage size, named as a known limit.
3. **Checked rows:** `mix lat.label_checked` compares current labels with every row already judged (`test/fixtures/change_vocabulary/switch_checked.json`). A row changed by a decided rule is accepted with the rule as the why.
4. **Golden** from inputs.
5. **Dry run:** `mix lat.label_switch` (no write; its per-law csv goes to `data/reports/change-vocabulary/dry-run-<family>.csv`, or `--out PATH`) → Jason → restore point (`lat_label_timeline`, `lat_change_log`, `provision_changes`, `provision_change_claims`, `lat_events`) → the family added to `:label_families` → `mix lat.label_switch --apply`.
6. **After the apply:** `mix lat.label_switch --family F --stored` compares the stored timeline with what the switch writes, law by law, on every field it writes (0 rows differing). `--strata` can't show this: it compares the fold's own periods, and the timeline's conventions (a repeal's day and empty territory, the commencer as `changed_by`, no unknown period before an EU law's first dated day) always differ from them.

**The label tools fold once** (#191, 2026-11-07). `lat.label_shadow`, `lat.label_rules` (every `--list`) and `lat.label_check` fold a family's laws through one fold cache (`LabelTools.FoldCache`, `data/cache/label-fold/`), several at once under `LawRunner`'s guard (`LabelTools.FamilyFold`), with outputs in the laws' order. On Maritime Safety the first tool takes about 85 seconds and each one after it about 5 (each was about 12 minutes before). The cache key covers everything a fold reads: the code version, the law's latest build, its stored timeline, its rows, its register entry and its CLML body. So a rebuild, a relabel or a code change folds the law again. `--no-cache` folds each law afresh. The dry run (`lat.label_switch`) folds its laws in parallel, without the cache (about 80 seconds). Run heavy checks in a capped unit: `systemd-run --user --unit=NAME -p MemoryMax=14G -p MemorySwapMax=0 --working-directory=backend …`. A run that overruns is then killed alone, not the terminal (the OOM killer, 2026-11-07).

**Pass rule as used** (Maritime Safety, 2026-11-07):
- the causes saved;
- the rules show 0 breaches outside the named known limits;
- the checked rows match, apart from known and upstream rows and another family's parked regression;
- golden 27/27;
- the dry run folds every law with 0 rule breaks;
- after the apply, the stored timeline equals the switch's, every law it wrote.
- **On OH&S** (2026-11-02): 696 checked rows match, 47 known, 1 upstream.
- **On Maritime Safety** (2026-11-07):
  - **Part VI.** A hand look at one cause with no evidence (421 rows, "in force later, no change dated") found the feed reader taking "s. 130A-130E (Pt. 6) (Ch. 1A)" as the whole of MSA 1995 Part VI. It was fixed in the reader with leave (a bracketed Part is a locator), after a store scan (310 effects in 50 laws, 18 that move a label).
  - **Known limits.** 8 rows that break the rules are named, in three classes parked with the Label fold and the Commencement reader.
  - **Checked rows.** 51 of OH&S's checked rows changed `changed_by` by Decision 1 and were accepted. 6 HSWA rows show a parked repeals-table fault from the Mines Regulations 2014.
  - **The apply.** The first apply wrote 116 of 117 laws. The Merchant Shipping Act 1979 failed the old register's fidelity gate, which `LabelRefresh` then still ran for switched laws.
  - **The old register fix.** The start-from-old-register bug was fixed in this step (Jason's leave): the start is stored with the build, and a switched law's refresh no longer collects or reads the old register.
  - **After the re-apply:** all 117 written, and their stored timelines equal the switch's, row for row. No agent was used.
- **On Environmental Protection** (2026-11-12):
  - **The baseline.** 50% of rows differed today, against Maritime's 10%.
  - **Territory.** The largest class (7,736 rows, territory alone) is one rule: a devolved law applies where its type or title puts it (RULES `devolved-law-applies-in-its-territory`).
  - **A hand look** at each cause naming no evidence found:
    - a shadow gap: a container's change isn't named as the evidence (parked here);
    - the old path's false repeals (EA 1995 s.41);
    - one fault class: EPA 1990 Part IIA in force from 1995.
  - **Two fixes with leave:**
    - Welsh SIs held under their UK names keep their prospective period (Label fold, 440 rows);
    - an amending provision commenced territory by territory dates its changes from the first stage, partly in force, only where nothing else dates them (Amending-law reader, Decision 3 B; RULES `territorial-stages-date-only-the-undated`).
  - **The checks caught the fix's two over-reaches before the apply:**
    - golden: a one-territory order dating a Welsh Act's change;
    - the checked rows: the stage outranking the feed's dates.
  - **Known limits.** 15 rows in 2 classes are named.
  - **Checked rows.** 22 OH&S checked rows changed by the 2026-11-10 commencement re-reads (SI 2005/1909 on HSWA) are parked with the Commencement reader.
  - **The apply** wrote 122 of 122, and `mix lat.label_switch --stored` (new, replacing the scratch script) shows 0 rows differing.
  - **Parser-stale laws.** 59 now counted by `lat.stale --strict --switched` were text-diffed (0 rows) and re-parsed from the store.

**Skill.** `switch-over-check` (rewritten 2026-11-07 to the code-decided pass).

---

## How a step is run

This is the process drawn up in the retrospective after OH&S (2026-11-03). The `session-start` command (step session) and each check skill carry it.

**1. Plan mode first.** Before any work, the step is planned in plan mode and Jason approves the plan. The plan states:
- the **aim**, in one sentence tied to [AIMS.md](AIMS.md);
- the **inputs and outputs** (tables and files);
- the **pass rule**, fixed now;
- the **golden set and fixtures**, frozen for the step;
- what is **out of scope** (above all, other steps' code);
- a **time box**;
- **at most 8 todos**.

Changing the pass rule, golden or scope means a new plan, approved again, not an edit in the log.

**2. Checks in code first.** The pass is decided by code wherever possible:
- **table rules**: each fault class written as a check over every row of the family;
- **checked-row fixtures**: rows already judged, with their accepted labels;
- **pattern catalogues**: every form in the whole store, classed, with fixtures;
- **golden from inputs**: the golden set rebuilt from the sources, never only from the store;
- **store scans**: `mix lat.store_scan --form NAME [--list FILE]` runs one named form over every stored feed effect, each counted once (about 70 seconds). A new question about the store becomes a form under `Checks.StoreScan.Forms`, with tests, not a script written fresh in a session (#192). The first form is `bracketed_container`.

**3. Agents only to find new classes.** An agent check is small, on a seeded sample, used to find classes the code doesn't yet know, and its token cost is recorded in the session. It is not a repeated pass gate. One pass at most, never sample → fix → resample (2026-11-05, Maritime Safety's Commencement reader: two rounds, 274k tokens, each finding a few one-law forms). What an agent finds becomes a code check that finds the rest of its class over the corpus, as the commencement catalogues' **leftovers** do (step 4: every word of a statement that bears on a date and that no rule uses, ranked by reach). A plan never says "a fix is followed by a fresh sample".

**4. Bugs are parked by owning step.** A bug in another step's code is raised with the `bug-raise` skill (with a `step:` tag naming the owning step, a class slug, the rows affected) and parked. It is never fixed in the current step unless Jason says so for that bug. Each step's backlog is worked when that step is formally reopened. Single-law wordings and legislation.gov.uk's own data errors below the plan's triage size become named known limits, not fixes.

**5. New work goes to a parking list.** Work found mid-step goes to a `## Parking list` in the session, one line each with its owning step, never to the todos. Per-round logs go to report files; the session keeps decisions, results and pointers.

**6. Ask Jason before long runs.** Rebuilds, read passes, re-parses, fetches and full chains are asked for first, saying the purpose, the time and what they write. Prove a change alters a run before running it.

**7. Restore point before writes.** Before any run that writes, take a restore point of the tables it writes: `./scripts/nas/nas-backup.sh --tables <tables> --tag <tag>` (seconds). Then dry run → Jason → apply.

**8. Questions to Jason in plain words.** Written in the session doc first: the question, the aim it bears on, the options, a recommendation.

Session files: `.claude/sessions/lat-change-pipeline/<date>-<family>-<step-name>.md`, titled "<Family>: <Step name>".

## Running a new family

1. **Prerequisites.** The golden set for the pass is frozen.
2. **Making laws**: every live law decided from its text; the making laws parsed into LAT (fetch and parse with Jason's go).
3. **Sources** until the gate passes (fetches only with Jason's go).
4. **Feed reader**, then **Markup reader**: catalogues first, then the gates, then a small agent sample for new classes.
5. **Commencement reader**: both catalogues, the re-read, the check.
6. **Extent reader**: sweep and catalogue, the extents written, the check.
7. **Amending-law reader**: the read pass current, catalogue, pre-flight, one read pass, rebuild, golden from inputs, strata, the gate.
8. **Merge**, then **Evidence**: strata and their checks after a rebuild.
9. **Label fold**: the gate, one agent pass over S and R, golden from inputs.
10. **Measures**: every figure the family's steps publish, printed by code and replicated.
11. **Store and build**: two builds, digests compared, staleness, the sources gate re-run.
12. **Labels side by side**: the new timeline beside the old (`--strata`), 0 rule breaks, the side-by-side totals and gaps saved as the switch-over's baseline.
13. **Switch-over**: causes (a hand look at any cause with no evidence), rules to 0 outside named known limits, checked rows, golden; dry run → Jason → restore point → add the family to `:label_families` → `mix lat.label_switch --apply`; then the stored timeline compared with the switch's.
14. **Retrospective and housekeeping** (Maritime Safety, 2026-11-07): compare the family against the last one from the meta session's step-status table; a full NAS snapshot (`./scripts/nas/nas-backup.sh --archive`, then `import-snapshot.sh --verify-only`); every open bug owned by a step, with the index rebuilt and no YAML warnings; stale sessions closed; the meta session closed.

**The order after Environmental Protection** (its retrospective, Jason 2026-11-12):
1. the review tooling (`2026-11-10-amending-law-reader-review-tooling.md`);
2. a few families from the QQ legal register, one at a time: each step fixes its own parked bugs from the backlog first, to cut the backlog and make the steps reliable. **They end** (retrospectives review, Decision 1, C) when the last QQ family closes more bugs than it parks, its Measures re-run moves no gate, and no step reopens a bug it closed, or after 4 QQ families, whichever comes first;
3. production hardening: all the steps run as one process, only once they are reliable;
4. the rest of the register's families.

**The check on this order** (retrospectives review, Decision 5): each QQ family's retrospective measures days per family (at most 6, the backlog fixing included), new reader bugs per family (falling from EP's 26) and open bugs (falling from 123).

**Models per part** (the same retrospective, Decision 2; the step chosen by the retrospectives review, Decision 4): after the review tooling, the next family's **Label fold** (EP's costliest step, 428k agent tokens) is run as a scripted workflow, with code by Fable, the session and its pass/fail verdicts by Opus 5.5, and paperwork and report summaries by smaller models. It is measured against the last family's row for that step (tokens, time, anything missed) before any other step runs that way.

**Size a fix by its reach** (Environmental Protection retrospective): count every change the fix's claim reaches, by an in-memory diff against the stored changes, never only the cases it is meant for. Decision 3 of EP's Switch-over was sized at 74 undated changes and reached every change commenced by territory; the Label fold's Decision 8 was sized at 157 rows and moved 1,227.

**Gates run on the final code.** A gate passed early can fail once later steps change shared code (Measures found 3). Before a step closes, re-run the gates it depends on against the code being committed: `mix lat.step_close --family F --step S` (Tooling: step-close check). It re-runs every gate up to the step (the map is `ChangeVocabulary.Gate.Steps`; `mix lat.gates --through S` runs the gates alone), the switch-over's checked rows (`lat.label_checked`) and the family's stale laws (`lat.stale --family F`, `--switched` at Switch-over), and exits non-zero on any failure, naming who takes it. A failure is parked with that owner, never fixed in the closing step. Read-only; minutes, about 12½ min more from the Label fold on.

After a reader fix, rebuild (`mix lat.vocabulary --check --family F`, then `--golden`) so the change register reflects it before the next step looks at it. Each family's new forms extend the catalogues. Steps are batched across families only once families stop surfacing new defects.

A second pass over the steps for OH&S, on the extended golden set (`golden_extended.exs`, 23 more provisions), is still to run.
