---
name: Store Build Check
description: The change register's acceptance check (CV-S11) for one family. It proves the build repeatable (two builds, digests compared), times it, shows what is stale (mix lat.stale, with an agent hand check of a seeded sample), and re-runs the sources gate after the build. Use it when a family reaches step 11, and after any change to the build or the store.
---

# Store Build Check (CV-S11, per family)

## Purpose

The change register (`provision_changes`, `provision_change_claims`, the `changes_built` events) is:
1. **repeatable**: the same inputs give the same stored changes;
2. **fast enough**: the family build fits a fix round;
3. **honest about staleness**: every built law whose code or inputs moved since its build shows as stale, with the reason.

## Steps

Ask Jason before the builds: they write the three tables. Say how long they take.

1. **Restore point** (seconds): `./scripts/nas/nas-backup.sh --tables provision_changes,provision_change_claims,lat_events --tag <tag>`.
2. **Build A with the check:** `mix lat.vocabulary --check --laws <the family's laws and the golden laws>`. This builds, prints the conflict counts and golden from the store, then re-runs the sources gate (`lat.sources`) on the laws built. The build prints its wall time (`build_time`).
3. **Digest:** `mix lat.changes_digest --family "F" --golden --out A.tsv` (about 6 s).
4. **Build B:** `mix lat.vocabulary --build --laws <the same>`, then digest to `B.tsv`. `cmp A.tsv B.tsv` must be identical (`build_repeatable`).
5. **Staleness:** `mix lat.stale` (about 2 s). It must show 0 of the built laws stale; laws holding LAT with no build are counted apart. `--list` names each stale law with its reasons.
6. **Golden from inputs:** `mix lat.vocabulary --golden` (about 3 min): all pass.
7. **Hand check:** draw 20 built laws and 10 unbuilt ones with `Measures.Draw.shuffled` on a new seed, each with its latest build event, current code version, inputs taken now and verdict. Then run the agent below on that file. Save its VERDICTS block under `backend/data/reports/change-vocabulary/verdicts/s11/<family>/` and pool it with `mix lat.verdicts --dir`.

**Pass:** digests identical; build time accepted by Jason; 0 built laws stale after the build; the hand check finds no verdict wrong; golden all-pass. The sources gate's result is the S01 step's, printed here so a later step's new needs show up.

**Reasons** (`ChangeStaleness`): `no_build`, `code_version` (`ChangeVocabulary.Version`), or an input moved: `lat_rows`, `law_text`, `feed`, `amendment_rules`, `commencement_rules`, `extent_rules` (`Store.Inputs`). An input the build didn't record counts as moved.

## Agent prompt

Fill in FILE.

```
You are checking the staleness report of a legal-data service's change register (CV-S11
acceptance hand check). READ-ONLY: do not edit any file, do not fetch from the internet,
do not write to the database, do not run mix tasks. You may read files, run read-only psql
SELECTs, stat files, and use /usr/bin/python3.

Input: FILE — laws, each with `law`, `built` and `verdict` (the code's staleness reasons;
[] = fresh); built items also with `event_at`, `event` (the latest changes_built provenance:
code_version, changes, claims, inputs), `current_code_version` and `inputs_now`.

DB: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc "..."
Tables: provision_changes (law_name, code_version, built_at, id), provision_change_claims
(change_id), lat_events (law_name, event, at, provenance), legal_articles, amendment_rules
(amends, read_at), commencement_rules (commences, source_law, read_at), extent_rules
(source_law, read_at). Files under backend/data/cache/clml (follow the symlink): law text
{type}/{year}/{num}/body|schedules/…data.xml.gz; feed changes/affected/{type}/{year}/{num}/data.feed.page-N.gz.

Rule: a built law is stale when its changes were built by code other than
current_code_version, or an input moved since the build: its LAT rows, stored law text,
stored feed, or the latest read_at of the amendment rules (amends = law), commencement
rules (commences = law, or source_law among inputs.commencement_sources) or extent rules
(source_law among inputs.affecting). No build: [no_build].

For each built item check independently: the event is the latest; stored row and claim
counts and code_version match it, built_at near event_at; code version current; no
text/feed file modified after event_at; your own max(read_at) per rules kind equals the
recorded value; every input key recorded. For each unbuilt item: LAT rows held, no stored
changes, no changes_built event. Is the verdict right?

Output: a compact table (#, law, OK/WRONG/doubtful, note with evidence when not OK),
counts, then a VERDICTS block (one JSON object, no code fence):
VERDICTS
{"step":"s11","family":"<slug>","stratum":"staleness","seed":N,"round":N,"items":[{"id":"<law>","group":"<law>","verdict":"ok|wrong|doubtful|gap","fault":"own|upstream|known","pattern":""}]}
Be rigorous and skeptical; WRONG needs evidence. Under 700 words.
```

## History

- OH&S (first family, 2026-10-31): 168 laws, digests identical, family build 51 s (family + golden 204 s, EPA 1990 alone 156 s; accepted, no cache), 0 stale after, hand check seed 1101 30/30. Session `.claude/sessions/change-vocabulary/2026-10-22-cv-s11-store-build.md`.
