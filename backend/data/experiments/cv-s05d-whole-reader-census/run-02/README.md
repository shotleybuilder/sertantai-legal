# CV-S05d census: run-02, the scope rule and the triage (2026-10-27)

**Reading:** the same as run-01 (input `../run-01/input.jsonl`).

**New this run:**
- **The KA rule (Jason 2026-10-27).** An "apply" statement is sorted three ways:
  - **territorial**, kept as a reader candidate: the place is what's said;
  - **scope**: which things, persons or conditions, not where. Examples: "do not apply in relation to any building in Wales other than …", "applies if …", "United Kingdom ships", "outside Great Britain". This is fitness scope, fractalaw's;
  - **both**: a place bound together with a scope, e.g. "apply to lessors of social homes in England".

  `out/scope.tsv` is the extract for the application scope hand-off: 44 scope and 19 both.
- **Recall:** 10/10. **Silent candidates:** 114 sentences.

## Triage (`out/triage.md`)

Every silent candidate was triaged by hand, and a sample of each wording was confirmed with `Extent.of` (`out/verify3.txt`). The real ones fall into 12 wordings plus one-offs, and form the round 13 fix list:

| # | Wording | Laws |
|---|---|---|
| S1 | Exception lists' items dropped. CV-S05c had wrongly labelled them KX. | 10 |
| S2 | Sub-letter runs lost in `RefList`, leaving garbage refs | 8 |
| S3 | "or"-lists, and "Part N of Schedule M", in same-extent subjects | 4 |
| S4 | Qualified companions dropped, not withheld | 8 |
| S5 | A provision's own subsections, self or Chapter | 6 |
| S6 | Two statements joined by "and" or "or" | 3 |
| S7 | Whole-law default misread or missing | 3 |
| S8 | Territorial application statements unread (noise bin) | 5 |
| S9 | Qualified subject read whole | 2 |
| S10 | Repealed words inside number lists | 3 |
| S11 | Schedule or regulation locator read whole | 2 |
| S12 | Same-extent item dropped | 1 |

About 30 candidates are finder misses, to be fixed in run-03. Two are known (KD, KX), and about 18 are doubtful.

The over-reach list (516 refs) has had a first pass only; it is roughly half real.
