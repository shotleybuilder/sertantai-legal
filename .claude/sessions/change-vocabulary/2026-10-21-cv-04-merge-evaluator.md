---
session: 'CV-04: Merge and Evaluator'
status: active
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
bugs:
  - pattern: "Merge leaves a primary change and its legislation.gov.uk twin apart (TCPA 1990: 335 of 548 primary-only text changes have a derived-only change by the same law on the same or parent/child provision); both fold into the label, no conflict seen"
    category: merge identity
    module: ChangeVocabulary.Merge
    affected: 335
    fix: ":unjoined" report as the worklist; join rules for undated primary and words-vs-provision levels
    status: open
  - pattern: "by overloaded: maker (feed) vs commencing order (commencement) compared as a conflict"
    category: vocabulary
    module: ChangeVocabulary.Readers.Feed / Evidence
    affected: 85
    fix: "split commenced_by from by"
    status: open
  - pattern: "Label period tier derived when any attribute of any change is derived (level/retained/saved), so almost every label reads derived"
    category: label tier
    module: ChangeVocabulary.Label.tiers/3
    affected: 2416
    fix: "per-field tier from the attributes that set the field; golden expected tiers"
    status: open
---

# Session: CV-04: Merge and Evaluator (ACTIVE)

## Problem

Part of the change-vocabulary architecture shift (CV-00): changes merged by identity; one evidence order per attribute; dates from the commencement ruleset; ranges reach only provisions that existed at their date (V1-05).

## Todo

- ✅ Expiry and continuation reader (primary; deferred from CV-03, Jason 2026-10-22; built 2026-10-22, golden 27 / 27): a law's own sunset clause and the orders continuing it, read as removals with their dates and territories — the last golden case (Coronavirus Act 2020 s.78) → 27 / 27
- ⬜ `Provision` facts complete: versions (done in CV-03: DocumentURI, shared history), `exists_from/to`, renumbering (C4: a renamed provision keeps its history; a target named by an old number resolves to the current one), kind words for NI Orders ("art. 10" in the feed = row reg.10)
- ⬜ Merge complete: the secondary key gains the source position (two same-day, same-type changes by one provision to one target don't collide); conflicts across changes (two sources placing one event on different provisions) reported
- ✅ Ranges expanded once, in document order, over provisions existing at the change's date (done in CV-03: `ChangeVocabulary.existing/1`, ranges at their own depth); V1-05 folded in (its fix reaches production at the CV-06 switch-over)
- ⬜ Evidence table complete: every attribute listed; the conflict report as an output (primary vs derived, per change), sized over the golden laws
- ⬜ Measure the CV-01 register bugs (records on the wrong provision) against the merged changes, over the golden laws
- ⬜ Storage: Ash resources for changes and change_claims (Ash-generated migrations), beside `lat_change_log` (deferred from CV-02); with it, a cache of each Act's extent clause (the scoreboard takes 5½ min reading them)
- ⬜ Golden set: 27 / 27 at the merge level; a Gemini review of the merge and evaluator

## Dependencies

- ✅ CV-03 closed 2026-10-22 (golden 26 / 27)

- ✅ CV-01 signed off by Jason (2026-10-21: "start small, prove, iterate and grow")

## Expiry and continuation reader (deferred from CV-03, 2026-10-22)

Jason 2026-10-22: "defer to pending session, pick the right one and put it there, don't drop". Placed here: CV-04's evidence table must rank an expiry as a removal, and its golden target (all cases passing) needs this one.

- **The case:** Coronavirus Act 2020 s.78. Expected, signed off:
  - E+W+NI from 2020-03-25;
  - W+NI from 2021-12-09 (England expiry, SI 2021/1399; already read);
  - NI from 2022-03-25;
  - repealed, "nowhere", from 2024-03-25, `changed_by` empty (the Act's own expiry).
- **What CV-03's vocabulary gives today:** the first two periods are right. From 2022-03-25 it reads `in_force_partial` W+NI, because the feed records that expiry as "expires in part" by the Act itself, with no territory.
- **The primary text to read:**
  - the Act's own sunset (s.89, with s.90's power to alter it, in the stored CLML);
  - and the NI continuation orders, the last being SR 2023/140. It was fetched into the store in CV-03 (2026-10-22) and its end date gives the 2024-03-25 lapse.
- **Scope:** temporary and emergency laws, where the law's own text (and the orders continuing it) fixes when, and where, a provision stops.

## Expiry reader built (2026-10-22): golden 27 / 27

- **`Readers.Expiry`:**
  - The sunset ("This Act expires at the end of the period of 2 years beginning with the day on which it is passed": Coronavirus Act 2020 s.89(1)) removes every section on the day after the period ends.
  - The exceptions listed in the next subsection are spared wholly, or only in part where they say "so far as".
  - A continuation order (SR 2023/140: "Section 78 … does not expire … and expires instead on 24th March 2024") moves its territory's expiry to the day after. The latest order for a section and territory governs; the sunset takes the other territories.
  - The passing date comes from the Act's own `EnactmentDate`.
- **`AmendingLaw.RefList`:** the one reader of a law's own provision lists, now shared by `Extent` and `Expiry`. Extracting it fixed a split ("this section" became "this" and "section").
- **Merge rules found on the way:**
  - A dated change from the law's text joins only a record of the same day. The sunset (2022) and the NI continuation (2024) are two removals of s.78 by the Act itself.
  - It joins only a feed or markup record, never another unjoined change.
  - The earlier NI continuation orders the feed names (SR 2022/108, 2022/226, 2023/48, 2023/51) are not held; only the latest is needed, since it fixes the expiry date.
- **`ChangeVocabulary.changes/5`:** the merged, resolved changes that `labels/5` folds. `mix lat.vocabulary` now prints these, from every reader; before, it showed the feed and markup only and so hid the primary readers.
- **Full suite:** 3,001 passing.

## Storage plan (2026-10-22; Jason: "Store next. The review and plan should include existing abstractions")

### What exists

| Store | Holds | Written | Size | Fate |
|---|---|---|---|---|
| `amendment_rules` (`Amendment.Store`) | each amending provision read: targets, operation, level, source | per source law, delete + insert (`mix lat.amending --read`) | 18,918 | input; kept |
| `commencement_rules` (`Commencement.Store`) | each commencement statement read (clause, orders, feed) | per source law, delete + insert (`mix lat.commencement`) | 38,040 | input; kept |
| `Amendment.Index` (JSON per amending law, `data/cache/amendment-index/`, 1,872) | the read pass's per-document facts: element ids, each repeals table's introducing section (`references`), Schedule paragraph Parts; `ReaderVersion`; laws read for | with the rules, same pass | 1,872 files | input; **home for the extent clause** |
| `ClmlStore` (`data/cache/clml/`) | CLML and feed pages, gzipped, `dct:valid` freshness | on fetch | — | input; kept |
| `legal_register.geo_extent`, `application_clause` | law-level extent and application (`ExtentResolver`, `ExtentBackfill`, `ApplicationClause.parse`) | extent resolve / LAT persist | — | input; kept |
| `lat_change_log` (`ChangeCollector`) + view `lat_change_log_rows` | the old change register: one record per source per run of rows, joins (`via`), no merge | per law per collector, delete + insert | 137,289 | **replaced** by the merged store; retired at CV-06 |
| `lat_label_timeline` (`LabelProjection`) | label periods; read by compliance | per law, delete + insert | 583,946 | kept; at CV-06 the fold writes it |
| `SourceVersion` → `ParserVersion`, `LabelVersion`; `lat_events` `labels_refreshed`; `LabelStaleness`, `mix lat.stale` / `lat.relabel` | code versions and staleness | per build | — | reused |
| `amendment_annotations` | notes (pointers only) | parse | 89,679 | untouched |

### Where the time goes (measured 2026-10-22, TCPA 1990: 4,187 effects, 584 affecting laws, 51 Acts held)

- Affecting Acts' extent clauses: 44 s (`Doc.new` 25 s, `Extent.read` 19 s), every run, from CLML.
- `Markup.provisions`: 11 s, computed twice (`labels/5` and `changes/5` each call it).
- `Markup.read` 10 s; feed effects 5 s; commencement rules for 584 laws 0.5 s; amendment rules 12 ms.
- HSWA 1974: primary inputs 26 s of ~40 s. SI 2010/404: under 0.5 s in all.

### Proposal

1. *(Revised after review: an `extent_rules` table instead, below.)* **The extent clause is a read fact of the amending Act's document, stored with the others in `Amendment.Index`** — not a new cache. The read pass already opens each amending Act's document; it adds `"extent"` (the `AmendingLaw.Extent` struct as JSON) and `ReaderVersion` covers `Extent` and `RefList`. The vocabulary reads it from the index, else reads the document (the index's existing "no silent loss" fallback). Check first: `Extent.introductions` (a Schedule's "has effect" section) and `Reader.references` (a repeals table's introducing section) may be one fact read twice; if so, one reader.
2. **The merged changes in two Ash resources** (Ash-generated migrations), beside `lat_change_log` during the shadow (CV-01), which retires it:
   - `law_changes`: `law_name`, `key`, `target`, `aliases[]`, the resolved attributes (`operation`, `level`, `territory`, `date`, `by`, `retained`, `partial`, `saved`), `sources` and `tiers` (map), `conflicts` (array of maps), `code_version` (a `VocabularyVersion` by `SourceVersion`), `built_at`. Identity `(law_name, key, target)`.
   - `law_change_claims`: `change_id`, `source`, `attribute`, `value` (jsonb, type-tagged so Dates and atoms round-trip), `ref`.
   - `ChangeVocabulary.Store.write(law, changes)`: delete + insert per law in one transaction (as `ChangeCollector`, `Amendment.Store`); `for_law/1` reads back `Change` structs. Whatever `changes/5` returns is stored, the parent-commencement changes included (source `:parts`, no claims), so the fold reads exactly what was stored.
   - The conflict report is a query (`conflicts` non-empty).
3. **One computation per run:** `labels/5` folds changes it is given (or computes them once); `Markup.provisions` once.
4. **The scoreboard:** `--golden` keeps building from inputs (it tests the code); `--golden --stored` folds stored changes (tests the fold alone, seconds). `mix lat.vocabulary --build --law X` writes a law.
5. **The vocabulary stops reading the old register:** `--law` takes the law's start from `lat_change_log`; it moves to the commencement rules (`LawStart`).

**Not now:** `LabelStaleness` learning `:changes_version` (CV-06, when the store feeds labels); input-change detection (rules re-read after a build) beyond the version stamp; storing the expiry and continuation reads (one law, cheap).

**Order (TDD):** codec round-trip test (red) → resources and migrations → `Store` → build golden laws → `--stored` scoreboard equals the built one (27 / 27) → extent in the index → time measured. Writes only new tables and index files: no restore point needed; a backup after the golden laws are built.

**Questions for review:** (a) extent in the JSON index vs a DB table beside the rules; (b) claim values as tagged jsonb vs typed columns; (c) storing the derived `:parts` changes vs deriving at the fold; (d) table names in a DB shared with compliance; (e) is the version stamp enough for staleness until CV-06.

### Gemini review of the storage plan (2026-10-22)

`backend/data/code-reviews/2026-10-22-cv-04-storage-plan-gemini.md` (gemini-2.5-pro). Taken, adjusted or declined:

- **Taken: the extent clause isn't the index's.** The index holds a reader's working facts; an extent clause is a statement in the law's text, the same kind as the amendment and commencement rules. Revised: **`extent_rules`**, a third ruleset table that follows the pattern of those two. It has one row per statement (the default, each "also", "only" or "same extent" list, the "corresponds" sentence, each Schedule's introducing section), with `source_law`, `source_ref`, `source_text` and `read_at`. It is written per source law by delete + insert, in the same read pass. This is better than Gemini's one JSON blob per law, because the rows can be queried like the other rules.
- **Taken: input staleness.** A code version alone misses re-read rules or a refetched feed. Revised: each build records a `changes_built` lat_event (reusing `lat_events`), whose `provenance` holds the input fingerprints: the latest `read_at` of the rules read, the feed's fetch time, the CLML `dct:valid` and the code version. A law is stale when any of these moves.
- **Taken: store the `:parts` changes, and use tagged jsonb for claim values.** Both were already in the plan.
- **Taken in part: names.** `law_changes` is too near the existing `law_change_snapshots`. Gemini's `cv_` prefix is opaque, so I'd use **`provision_changes`** and `provision_change_claims` instead (no collision).
- **Taken: identity collisions.** One event that two sources place on different provisions is the "conflicts across changes" item already in this session's merge todo. The store records which provision the merge chose and the conflict; it doesn't fork the change.
- **Declined: cutting `tiers` and `conflicts`.** They are Jason's decision (2026-10-21: labels carry a tier; conflicts reported) and are the conflict report's data.
- **Declined: "delete + insert is not idempotent" and production locking.** One transaction rolls back whole. This is the local dev DB; production gets only `lat_label_timeline` by delta sync. Runs are one law at a time.
- **CV-06's concern: a reversible switch-over mechanism.** Noted there.

### Tiers and conflicts examined (2026-10-22; Jason: "dig into tiers and conflicts … Is this the right move to get what's wanted")

**What's wanted** (Jason 2026-10-21):
- each label field says whether the law's text backs it;
- a list of where the law's text and legislation.gov.uk disagree, the worklist for reader errors and for errors in legislation.gov.uk's records.

**What the code gives.** Measured over all LAT rows of three golden laws:

| | SI 2010/404 | HSWA 1974 | TCPA 1990 |
|---|---|---|---|
| changes | 286 | 2,432 | 14,850 |
| with any derived attribute | 128 | 2,416 | 7,148 |
| conflicts (changes) | 0 | 4 (2) | 173 (167) |
| primary only, text operations | 2 | 11 | 548 |
| … with a derived-only change by the same law on the same or a parent/child provision | — | 7 | 335 |
| derived only, though the amending law's text was read | 5 | 435 | 2,233 |

**Missing:**
1. **The disagreements the report misses.** A conflict is found only inside one merged change. When the merge leaves a primary change and its legislation.gov.uk twin apart, the report never sees them, and both act on the label (HSWA s.53(1): text "repealed" and markup "inserted", as two changes). On TCPA, 335 of the 548 primary-only text changes have a likely twin. These unjoined pairs are the largest class of disagreement, and none of them is reported.
2. **Noise in what it does report.**
   - `by` means two things. The feed's is the law that made the change; the commencement's is the order that commenced it. That gives 85 of TCPA's 173 conflicts (anaw 2015/4 inserted, wsi 2016/52 commenced), and they are two facts, not a disagreement.
   - The markup shows a substitution as an insertion: 19 more.
   - A repeal in part beside a whole repeal is a real disagreement.
3. **A label tier that is almost always "derived".** A period's tier is derived when any attribute of any change behind it comes from a derived source, including `level`, `retained` and `saved`. Only the markup and the feed state those last two, so 2,416 of HSWA's 2,432 changes count as derived. The tier is meant to be per field: `in_force_from` from the date's source, `changed_by` from `by`'s, `territory` from the territory's, and `status` from operation, date and partial. No test checks tiers: the golden scoreboard strips them.
4. **Stored tiers would duplicate sources.** A tier is a function of its source (`Evidence.tier/1`). Conflicts are a function of the stored claims. Storing either copies what the claims already hold, and fixes the conflict rule at build time.
5. **The label table has nowhere for tiers.** `lat_label_timeline`, which compliance reads, has no tier column. "Labels carry tier" reaches compliance only through a schema change to a synced table, which is CV-06 and needs compliance's agreement.

**Revised plan:**
- Store the claims and `sources`, not `tiers` or `conflicts`. Tiers and conflicts are derived when read, so the rule can change without a rebuild.
- `ChangeVocabulary.Conflicts`, a pure function over the merged changes, reports three kinds:
  - `:value`: like-for-like attributes only.
  - `:unjoined`: a primary-only change beside a derived-only change by the same law, on the same or a parent/child provision.
  - `:uncovered`: derived only although the amending law's text was read, or primary only with no record from legislation.gov.uk.
  - It is run over the stored changes, so the report is a query.
- Vocabulary fixes:
  - `commenced_by` split from `by`;
  - operation equivalences (substituted ≈ inserted in the markup) before a value counts as a conflict;
  - label tier per field;
  - golden cases gain expected tiers.
- The `:unjoined` list is the worklist for the merge item above; joining those pairs is what makes the remaining value conflicts visible.
