---
session: 'CV-04: Merge and Evaluator'
status: closed
release: v0.1
opened: '2026-10-21'
closed: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
outcome: partial

summary: >
  Built the expiry and continuation reader (golden 27 / 27), the change store (provision_changes, claims,
  extent_rules; tiers and conflicts derived on read), the conflict report, and reworked the merge
  (unjoined 1,104 → 184 on the golden laws). Closed partial with CV-07 (Jason 2026-10-22): its open items
  move to the workflow step sessions, each closing only when its results pass.

decisions:
  - what: Store claims and sources; derive tiers and conflicts on read
    why: tiers follow from sources and conflicts from claims; storing them duplicates and freezes the rule (Gemini review, then Jason's "dig into tiers and conflicts")
    result: 46d2b13a
  - what: commenced_by apart from by; label tier per field
    why: the maker and the commencing order are two facts; a tier from any attribute read almost everything as derived
    result: 46d2b13a
  - what: One record from each source per event in the merge; legacy markup joins first; the note's amending provision a pointer for identity
    why: joins snowballed (RTA 1988 s.89); Jason — "decision - yes" to note pointers for identity
    result: unjoined 1,104 → 184
  - what: Leave the merge as it is and analyse with more examples
    why: Jason — "we leave the merge/join as it currently is and analyse the data when we have more examples"
    result: suspended 2026-10-22, closed 2026-10-22

metrics:
  golden: {provisions: 27, passing: 27}
  merge_golden_laws: {unjoined_before: 1104, unjoined_after: 184}

lessons:
  - title: A merge that joins into an already-joined change snowballs
    detail: Each join made the next record look like the same event; one change on RTA 1988 s.89 took 12 markup records and 18 instructions. One record from each source per event stopped it.
    tag: data
  - title: A foreign key cascade with no index makes every rebuild scan the child table
    detail: provision_change_claims had no index on change_id; rebuilds ran about 5× slower than into empty tables.
    tag: schema

bugs:
  - pattern: "Merge leaves a primary change and its legislation.gov.uk twin apart (TCPA 1990: 335 of 548 primary-only text changes have a derived-only change by the same law on the same or parent/child provision); both fold into the label, no conflict seen"
    category: merge identity
    module: ChangeVocabulary.Merge
    affected: 184
    fix: "1,104 → 184 on the golden laws; the rest in CV-S07"
    status: open
  - pattern: "Extent reader reads only 'this Act extends to X'; 110 of 176 Acts changing golden laws read as no clause (does not extend to NI; Parts … extend to; The following provisions extend to …)"
    category: reader coverage
    module: AmendingLaw.Extent
    affected: 110
    fix: "SI forms, does/do/shall not extend, except-lists, Part lists, enabling powers, competence (CV-07); residue in CV-S05"
    status: fixed
  - pattern: "by overloaded: maker (feed) vs commencing order (commencement) compared as a conflict"
    category: vocabulary
    module: ChangeVocabulary.Readers.Feed / Evidence
    affected: 85
    fix: "split commenced_by from by"
    status: fixed
  - pattern: "Label period tier derived when any attribute of any change is derived (level/retained/saved), so almost every label reads derived"
    category: label tier
    module: ChangeVocabulary.Label.tiers/3
    affected: 2416
    fix: "per-field tier from the attributes that set the field (done); golden expected tiers (CV-S09)"
    status: fixed
  - pattern: "provision_change_claims had no index on change_id: a rebuild's cascading delete scanned every claim"
    category: schema
    module: Legal.ProvisionChangeClaim
    affected: 1
    fix: "index (migration 20261022074039)"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/expiry.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/store.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/conflicts.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge.ex
  - backend/lib/sertantai_legal/legal/provision_change.ex
  - backend/lib/sertantai_legal/legal/provision_change_claim.ex
  - backend/lib/sertantai_legal/legal/extent_rule.ex
  - backend/priv/repo/migrations/20261022055656_change_vocabulary_store.exs

depends_on:
  - 2026-10-21-cv-03-readers

enables:
  - 2026-10-22-cv-07-primary-coverage
  - CV-S01 … CV-S11
---

# Session: CV-04: Merge and Evaluator (CLOSED)

## Problem

Part of the change-vocabulary architecture shift (CV-00): changes merged by identity; one evidence order per attribute; dates from the commencement ruleset; ranges reach only provisions that existed at their date (V1-05).

**Suspended 2026-10-22** (Jason: "we leave the merge/join as it currently is and analyse the data when we have more examples"). CV-07 widens primary coverage first; the open items here gain from more law text read. The merge stands at 184 unjoined, left as is.

## Todo

- ✅ Expiry and continuation reader (primary; deferred from CV-03, Jason 2026-10-22; built 2026-10-22, golden 27 / 27): a law's own sunset clause and the orders continuing it, read as removals with their dates and territories — the last golden case (Coronavirus Act 2020 s.78) → 27 / 27
- ⏸️ (deferred → CV-S02 NI kind words, CV-S06 renumbering, CV-S07 exists_from/to) `Provision` facts complete: versions (done in CV-03: DocumentURI, shared history), `exists_from/to`, renumbering (C4: a renamed provision keeps its history; a target named by an old number resolves to the current one), kind words for NI Orders ("art. 10" in the feed = row reg.10)
- ⏸️ (deferred → CV-S07) Merge complete: the secondary key gains the source position (two same-day, same-type changes by one provision to one target don't collide); conflicts across changes (two sources placing one event on different provisions) reported
- ✅ Ranges expanded once, in document order, over provisions existing at the change's date (done in CV-03: `ChangeVocabulary.existing/1`, ranges at their own depth); V1-05 folded in (its fix reaches production at the CV-06 switch-over)
- ⏸️ (deferred → CV-S08) Evidence table complete: every attribute listed; the conflict report as an output (primary vs derived, per change), sized over the golden laws
- ⏸️ (deferred → CV-S07) Measure the CV-01 register bugs (records on the wrong provision) against the merged changes, over the golden laws
- ✅ Storage (2026-10-22, `46d2b13a`): `provision_changes` and `provision_change_claims` (tiers and conflicts derived on read), `extent_rules` (a third ruleset), `changes_built` events with input fingerprints; golden 27 / 27 from inputs (3 min 13 s) and from the store (51 s)
- ✅ Conflict report (`ChangeVocabulary.Conflicts`; `mix lat.vocabulary --conflicts`): value, unjoined, uncovered, unread; `commenced_by` apart from `by`; label tier per field
- ✅ Merge the unjoined pairs: 1,104 → 184 (`75d11be6`, `22e8c56b`, `63204804`); the rest are left as is until there are more examples (Jason 2026-10-22)
- ⏸️ Golden expected tiers per period, judged; the start's tier from its source (deferred — Jason 2026-10-22: "later", once primary coverage is wider)
- ⏸️ Primary coverage: moved to CV-07 (Jason 2026-10-22: its own session, after the merge work here)
- ⏸️ (deferred → CV-S07, CV-S08) Golden set: 27 / 27 at the merge level; a Gemini review of the merge and evaluator

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

### Storage built (2026-10-22; Jason: "That's better, build and then we can judge the results")

- **`extent_rules`** (`Legal.ExtentRule`; `AmendingLaw.Extent.to_rows/2`, `from_rows/1`; `AmendingLaw.Extent.Store`). One row per statement; `none` when an Act was read with no clause.
  - Written in the amending read pass (`mix lat.amending --read`).
  - Also written alone: `mix lat.amending --extents --law X | --amending A,B`.
  - `mix lat.vocabulary` reads it, else reads the Act from its document and names it.
- **One reader for a Schedule's introducing section.** `Amendment.Reader.references/1` now takes the Schedule's own reference where the schedules are held, else the section saying it "has effect" where only the body is held. `Extent` uses it; its own copy is gone. On TCPA's 51 Acts the two had never overlapped: the store holds only the body for most Acts, so the reference reader found nothing there.
- **`provision_changes` and `provision_change_claims`** (`Legal.ProvisionChange`, `Legal.ProvisionChangeClaim`, Ash migration `20261022055656_change_vocabulary_store`).
  - `ChangeVocabulary.Store.write/3` deletes and inserts a law's changes in one transaction, bulk inserted.
  - Each build records a `changes_built` lat_event. Its provenance holds the code version (`ChangeVocabulary.Version`) and the inputs read: `clml_valid`, `feed_fetched`, the latest `read_at` of the amendment, commencement and extent rules, and `extents_unread`.
  - `for_law/1` reads the changes back; tiers and conflicts are derived on read (`Evidence.derive/1`).
  - Claim values are stored as tagged JSON (`Store.Codec`).
- **`ChangeVocabulary.Conflicts`:** `values/1` (like for like; `@agree`: a substitution shown as an insertion) and `report/1` (`:value`, `:unjoined`, `:uncovered`). Printed by `mix lat.vocabulary --conflicts --law X | --golden [--all]`.
- **`by` split.** The law making a change is `by`; the law bringing it into force is `commenced_by` (evidence row `commenced_by: [{:commencement, :commenced_by}]`). `Change.credit/1` is what a label's `changed_by` credits: the commencing law for a commencement, else the maker.
- **Label tier per field** (`Label.tiers/3`): status from operation, date and partial; territory; `in_force_from` from the date; `changed_by` from `by` and `commenced_by`. Nil when no source states it. Shown by `mix lat.vocabulary --golden --stored --tiers`.
- **`labels/5` takes `:changes`** (read back from the store) and reads the markup facts once.
- **Found: the extent reader's coverage.** Of the 176 Acts changing the golden laws, 66 have a clause read and 110 have none read. Scottish and NI Acts rightly have none (no clause). Many UK Acts word extent in forms not read:
  - "This Act does not extend to Northern Ireland" (2005/14; 1991/34: "This Act, apart from sections 82 and 83, does not extend to Northern Ireland");
  - "Parts I and III … extend to England and Wales only" (1991/34);
  - "The following provisions of this Act extend to England and Wales only—" (2005/14);
  - "Part 1 … extends to England and Wales only, save that—" (2015/7);
  - "this Act shall not extend to Northern Ireland" (1982/49).
  Logged as a reader item below.
- **Not done:** `--law` (the debug print) still takes the law's start from `lat_change_log`. A build doesn't need the start; only the debug label print does.

### Results (2026-10-22, code `46d2b13a`)

**Scoreboards:**
- From inputs: golden 27 / 27 in 3 min 13 s (was about 6 min).
- From the store: 27 / 27 in 51 s. These changes are built for every LAT row, so the whole-law build gives the same labels as the 27-provision one.
- Build: 21 golden laws, 48,900 changes (only 279 more with the TCPA's whole rows), about 5 min; TCPA 1990 takes 79 s.

**The conflict report over the 21 golden laws.** The first report counted 4,000 conflicts, and most were noise. After the fixes:

| kind | count | what it is |
|---|---|---|
| `:unread` | 2,461 | legislation.gov.uk only, and the amending provision it names was not read (the read pass reads what our notes point to): coverage |
| `:unjoined` | 1,104 | a law-text-only change beside a legislation.gov.uk-only twin: the merge worklist |
| `:uncovered`, missing derived | 399 | the law's text only, with no legislation.gov.uk record |
| `:uncovered`, missing primary | 80 | legislation.gov.uk only, though its amending provision was read: the reader found no rule |
| `:value` | 67 | level 35, date 16 (commencement vs feed), operation 16 |

The noise removed:
- `by` (85 on TCPA): `commenced_by` is now apart.
- Primary territory against our own affecting-law inference (50): `:law` isn't legislation.gov.uk.
- "Read" meaning the law was read rather than its provision (about 3,100 moved to `:unread`).

**Coverage: how much the law's text backs.**
- Of the golden laws' 16,578 text changes:
  - 1,928 (12%) have both sources;
  - 1,329 (8%) only the law's text;
  - 13,321 (80%) only legislation.gov.uk.
- Five laws have no law-text claims at all: SI 2010/2215, EU 2016/2031, SI 2017/544, the Environment Act 2021 and the Building Safety Act 2022. Their amending laws haven't been read, so their "0 conflicts" means unread, not agreement.

**Tiers (golden periods, per field):**
- `status`: P 8, D 23, none 37.
- `territory`: P 3, D 24, none 41.
- `in_force_from`: P 8, D 21, none 39.
- `changed_by`: P 10, D 18, none 40.

"None" is mostly a start period: the law's own start carries no tier, because the golden set supplies the start, not its source. Primary tiers are few because primary coverage is: the tier now reports coverage honestly instead of always saying derived.

**What this says for "get what's wanted":**
1. **The conflict report is now a usable worklist.** Its 67 value conflicts are real disagreements to inspect. Its 1,104 unjoined pairs are the merge's work, and until they are joined their real conflicts stay hidden.
2. **Primary coverage is the limit.** 80% of text changes rest on legislation.gov.uk alone. Labels that carry the law's text need:
   - the read pass to read every provision legislation.gov.uk names, not only those our notes point to (the 2,461 unread);
   - the extent reader to read the other wordings (110 of 176 Acts unread).
3. **The golden set doesn't check tiers.** Expected tiers per period need judging, and the start's tier needs its source.

### Merging the unjoined pairs (2026-10-22; Jason: "join/merge first … before item 3")

Jason's questions answered (2026-10-22):
- **Sources.** A conflict is between the law's text (primary) and legislation.gov.uk's feed and markup (secondary). Notes are never a source, and our own inference (`:law`) is left out.
- **Value conflict.** Two sources joined as one event that disagree on one attribute.
- **Unjoined.** Not compared yet: once joined, a pair either agrees or becomes a value conflict.
- **Law text only.** legislation.gov.uk not yet updated, our misread, or a missed twin.
- **legislation.gov.uk only, read.** Our reader, or their false positive.
- **legislation.gov.uk only, unread.** The XML is held (all 70 laws behind the 2,461); the provision wasn't read, because the read pass follows notes only. Also, 641 of the 1,081 laws amending the golden laws aren't in the store at all, and their changes appear in no kind. CV-07 covers this.

**First pass:** 1,104 unjoined → 657, and 514 pairs joined. Changes in `Merge.join`:
1. **An event is its key.** One effect placed at two levels counts as one candidate (RTA 1988 s.48 and s.48(4A)).
2. **Records below the law's text are candidates.** The join used to look only at the provision and those above it.
3. **The source position (the open merge item).** Same-day events by one law are told apart by the amending provision the feed names: the feed reader's new `:affecting` claim (SI 2019/696 Sch.12 para.21(a) vs (d)).

Value conflicts rose from 67 to 112 as joined pairs were compared.

**Second pass, on the 657 left:** 1,394 of their 1,651 candidate twins were legacy markup changes (`d29p…`, `M_F_…`; no effect id, no feed record). The law's text was joined before those changes existed as candidates, so they never met. Changes:
- legacy markup joins first;
- `by` falls back to the note's citation (a pointer for identity);
- a `:law_text, :placed` claim keeps where the law's text named the change when the join moves it below;
- the conflicts treat "words in s.28(3)(c)" against "provision s.28(3)(c)(ii)" as agreement.

**Found: the claims table had no index on `change_id`.** A rebuild's cascading delete scanned every claim, so builds ran about 5 times slower than into empty tables. Index added (migration `20261022074039`): SI 2017/544 went from 17 s to 1 s, HSWA from 78 s to 21 s.

**Third pass: the second pass over-joined.** One change on RTA 1988 s.89 had taken 12 legacy markup records and 18 of the law's instructions. Each join made the next record look like the same single event, and legacy markup records joined each other. New rule: **one record from each source per event.** The law's text joins a change holding none of the law's text yet; legacy markup joins a feed record holding no legacy markup yet. The largest change now holds three records (an effect, one legacy markup record, one instruction).

**Result (code `75d11be6`; golden 27 / 27 from inputs, 3 min 9 s, and from the store; build 4.6 min):**

| | start | now |
|---|---|---|
| unjoined | 1,104 | 254 |
| value conflicts | 67 | 120 (level vs markup 47, level vs feed 30, operation vs feed 23, date 19, operation vs markup 1) |
| law text only (missing derived) | 399 | 464 |
| legislation.gov.uk only, provision read | 80 | 86 |
| legislation.gov.uk only, provision not read | 2,461 | 1,878 |

**The 254 left.** 1,079 candidate twins, about 4 each; 815 of those are legacy markup with no effect id and no feed record, mostly undated. Several records by one law on one provision and below can't be told apart: legacy markup carries no amending provision. Its note names one ("Words substituted by Highways Act 1980 (c. 66), Sch. 2 para. 10(2)(a)"). `AmendingLaw.Pointer` reads that as a pointer for identity, never a fact, the same use as the note's citation. That is the next lever, and needs Jason's agreement because it reads note text.

**The level conflicts with the markup (47) look real.** For example, SI 1995/889 art.2 substitutes RTA 1988 s.157(2), while the markup's insertion covers only part of the text under it ("words"). That is a disagreement between the two sources' reading of level; the law wins.

**Fourth pass: the note's amending provision as a pointer for identity** (Jason 2026-10-22: "decision - yes"). Code `22e8c56b`, `63204804`.
- The markup reader reads each change's note with `AmendingLaw.Pointer`, giving `:markup :affecting` ("Sch. 2 para. 10(2)(a)"). The merge uses it only to tell same-day events by one law apart; it is never stored as a fact or labelled.
- `Pointer.to_refs/1`: a run of same-kind brackets is a list ("para. 9(b)(c)(d)"), and a path stays a path ("4(4)(a)"). Words in brackets end the run ("(with s. 84(5))").
- The merge's "look below" index now includes legacy markup and the law's text. It was built from feed records only and missed TCPA s.248(3).
- One instruction naming several provisions (2016/22 Sch.12 para.9 → s.65(1)(a), (b)) is the event's placement at each, borrowing its feed facts only. It is placed only where the event has feed facts: a legacy-markup-only event lends none.
- A placement where the event already sits merges into it. The store's unique key `(law, key, target)` caught the duplicate on TCPA s.97(1).
- Mistakes on the way, both fixed: copying the markup's claims onto other placements (level conflicts went to 109); placements under a markup key with no feed facts.

**Now (golden 27 / 27 from inputs, 3 min 22 s, and from the store):**

| | start of CV-04 merge | now |
|---|---|---|
| unjoined | 1,104 | 184 |
| value conflicts | 67 | 147 (level vs markup 62, level vs feed 41, operation vs feed 24, date 19, operation vs markup 1) |
| law text only | 399 | 421 |
| legislation.gov.uk only, provision read | 80 | 156 |
| legislation.gov.uk only, provision not read | 2,461 | 2,290 |

More changes now count as "read" or "unread" because legacy markup names its amending provision.

**The 184 left:**
- 103: several records name the same provision. Typically several legacy markup records share one note, one instruction marked at several places.
- 40: the twins name other provisions.
- 31: one names it, but another rule blocks the join (one record per source, family, or day).
- 10: the law's own element id doesn't map to a ref.

Next lever for the 103: legacy markup records sharing one note are one event.
