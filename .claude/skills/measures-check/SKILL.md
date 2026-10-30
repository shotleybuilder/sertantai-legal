---
name: Measures Check
description: The change vocabulary's measures (CV-S10) for one family. It prints every published figure from code (coverage, dating, who states a change, the pass bounds from agent verdict files), proves the samples and printed figures replicable (draw twice, compare), and holds the register defining each figure. Use it when a step closes, for a quality statement, and for each new family.
---

# Measures Check (CV-S10, per family)

## Purpose

Every figure a step publishes (in a quality statement, a pass rule or a session's closing metrics) is:
1. **defined** in the register below: one name, one meaning;
2. **computed by code**, never by hand;
3. **tested** on hand-built data;
4. **replicable**: the same store and seed give the same sample and the same figures.

All steps here are read-only.

## Commands

| Figure | Command |
|---|---|
| Pass bounds, end to end, gaps, doubtful | `mix lat.verdicts --dir DIR [--limit 0.02 --group-limit 0.05]` |
| Who states a text change; law-text coverage; dating | `mix lat.measures --family "F"` or `--golden [--extended]` |
| Territory coverage | `mix lat.extent_check --family "F"` ("territory from", grouped by `Measures.Coverage.territory_groups/1`) |
| Strata, agreement, join rate | each step's `lat.*_check --strata` |
| Golden | `mix lat.vocabulary --golden` |

## Verdict files

Each check skill's agent prompt ends with a VERDICTS block: one JSON object per agent batch. Save each block as:

    backend/data/reports/change-vocabulary/verdicts/<step>/<family-slug>/round-<N>-<stratum>-seed-<S>[-b<k>].json

The directory is NAS-backed and not in git, since items may carry effect ids. Then pool the files since the step's last fix batch with `mix lat.verdicts --dir <that directory>`. Pass only the files since the last fix; an item checked twice counts once, the later round standing.

- **Counted against the bound:** wrong items whose fault is `own`. A group (law or pair) is wrong when any of its items counts.
- **End to end:** every wrong item, whoever's fault.
- **Gaps and doubtful items** are listed, never counted.

The bound is the exact one-sided 95% Clopper–Pearson upper bound (`Measures.Bound`). Under 2% needs at least 149 clean items.

## Replicability

Draw every check's sample twice with one seed and compare, using `draws.sh` (below). Samples must be byte-identical (`cmp`). Printed figures must be identical once log lines, compile lines and output paths are filtered out.

Every check's draw lives in `Measures.Draw`, with its seed tuple and algorithm unchanged since the round it was first used, so a recorded seed still draws its sample. A change to a draw invalidates every recorded seed for that step. Don't make one without Jason.

```bash
#!/bin/bash
# draws.sh OUTDIR: every check's sample at seed 901, with its printed figures and run time
O=$1; mkdir -p $O; cd backend; F="OH&S: Occupational"
run() { name=$1; shift; s=$(date +%s); mix "$@" > $O/$name.out 2> $O/$name.err; echo "$name exit=$? $(( $(date +%s) - s ))s" >> $O/times.txt; }
run feed lat.feed_check --family "$F" --sample $O/feed.json --n 50 --seed 901
run markup lat.markup_check --family "$F" --sample $O/markup.json --n 50 --seed 901
run commencement lat.commencement_check --family "$F" --sample $O/commencement.json --n 50 --seed 901
run extent lat.extent_check --family "$F" --sample $O/extent.json --n 50 --seed 901
run amending lat.amending_check --family "$F" --sample $O/amending.json --n 50 --seed 901 --stratum A
run merge lat.merge_check --family "$F" --stratum J --sample $O/merge.json --n 50 --seed 901
run evidence_a lat.evidence_check --family "$F" --stratum A --sample $O/evidence_a.json --n 50 --seed 901
run evidence_d lat.evidence_check --family "$F" --stratum D --sample $O/evidence_d.json --per 10 --seed 901
run label_r lat.label_check --family "$F" --stratum R --sample $O/label_r.json --n 30 --seed 901
run label_s lat.label_check --family "$F" --stratum S --sample $O/label_s.json --per 10 --seed 901
```

On OH&S (2026-10-30) a pass takes about 8 min: label about 3 min each, the rest 4–25 s each.

## Register

TO BE COMPLETED at CV-S10's close from the draft in the session doc (`2026-10-22-cv-s10-measures.md`, "Register of published figures").

## History

- OH&S (first family, 2026-10-30), session `.claude/sessions/change-vocabulary/2026-10-22-cv-s10-measures.md`.
