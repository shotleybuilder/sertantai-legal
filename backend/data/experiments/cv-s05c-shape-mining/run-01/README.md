# CV-S05c shape mining: run-01 (prototype, 2026-10-27)

The whole population of extent sentences, reduced to shapes and counted. It was read-only over the extent read cache. To rerun, follow `manifest.json`'s commands and checksums.

## Method

1. **Input:** `dump.exs` writes every extent sentence the catalogue holds, with the reader's class, to `sentences.tsv`. That is 3,039 sentences from 1,338 laws, out of 3,358 laws held.
2. **Split:** `mine.py` splits each sentence into a lead and its lettered items ("—a …;b …; andc …"). A sentence with no lettered items stays whole.
3. **Mask:** references become kind tokens (SEC, SECS, PARA of SCH, CHAPTER of PART …). Also masked:
   - places → PLACE;
   - another law's title → OTHER_LAW;
   - "this Part" → THIS_PART;
   - a bracket of words → (DESC);
   - ". . ." → GAP.
4. **Coarsen:** keyword words are kept (of, other than, so far as, extend, apply, same extent …). Any other run of words becomes WORDS.
5. **Count:** shapes are counted and ranked. An item that names no provision and says nothing about extent goes under `other_item`, which is mostly amendment text and conditions.

## Files

| File | What it holds |
|---|---|
| `items.tsv` | One row per lead, item or sentence, with its shape, its finer masked form and its text |
| `shapes.tsv` | The shapes ranked by count, each with its law count, the reader's classes and up to 3 examples |
| `stats.json` | Long-tail measures per kind: shapes, singletons, Chao1 estimate, Good–Turing unseen mass |

## Results

The stats cover sentences not classed `none`. "One law" means shapes seen in one law only.

| Kind | Occurrences | Shapes | Shapes in one law | Occurrences in one-law shapes | Good–Turing unseen | Chao1 est. shapes |
|---|---|---|---|---|---|---|
| sentence | 2,264 | 1,257 | 1,070 | 1,124 (50%) | 0.46 | ~5,600 |
| lead | 510 | 294 | 250 | 279 (55%) | 0.46 | ~1,050 |
| list item | 1,825 | 884 | 801 | 939 (51%) | 0.39 | ~3,900 |

- **The tail is long and real.** About half of all list items are in a shape that only one law uses. That is why each 50-law agent sample keeps finding new wordings.
- **The unseen estimates assume sampling, and this run is a census.** Within the held corpus nothing is unseen: every shape is listed here. Chao1 and Good–Turing describe what a sample would keep missing, and how much new law would still bring.

## Check against rounds 9 and 10

| Agent finding | Shape found | Tail? |
|---|---|---|
| R10 NEW-2: "Part 4 (…), other than paragraph 1 of Schedule 8" | `PART (DESC), other than PARA of SCH` | 1 law |
| R10 NEW-2: "in Chapter 1 of Part 6, sections 165, 166 and 186" | `in CHAPTER of PART, SECS (DESC)` | 1 law |
| R10 NEW-2: "in Part 8, Chapters 1 to 5 of Part 8 and section 295" | `in PART, CHAPTERS of PART and SEC` | 1 law |
| R10 NEW-2: "this Part (other than …, except as …)" | `THIS_PART (other than SEC and SCH, except as WORDS by SUBSECS)` | 1 law |
| R10 NEW-3: "(v) this Chapter" (ukpga 2017/3 s.182) | `THIS_CHAPTER` | 2 laws |
| R10 NEW-1: SI 2014/1638 reg.3, "In Schedule 13— …" | an **empty lead** (`—a …`): the lead is lost before the reader sees it | 9 laws share it |
| R9 NEW: Police Reform Act 2002 s.108 default | `subject to SUBSECS, THIS_LAW extends to PLACE only` | common (11 laws): not a wording fault, so shape mining can't find it, as expected |

All the round 10 list wordings show up as tail shapes. The empty lead is a finding in its own right: 9 laws have a list sentence that has lost its lead (ukpga 2006/51 s.34, 2017/30 s.119, 2020/22 s.53, …).

## Prototype limits

- Splitting relies on flattened CLML letters. An item list joined without a letter is missed, and "; a person" can split falsely.
- Masking is regex. Some descriptions survive as WORDS, and some instructions count as items.
- A shape's reader classes are per sentence, not per item, so they can't yet say which item was read.

## Step 2: per-item verdicts (same day, same input)

`verdicts.exs` gives each list item `mine.py` split a verdict on whether the reader holds what the item names. It uses the reader's own subject parse (`Credit.own_refs/3`) and the stored lists of the item's kind and place. Its kind and place come from the item's own "extend to …", else its sentence's.

**Verdicts:**
- `read`;
- `partial`, `missing` or `unread` (not held);
- `withheld` (deliberately in an unread list);
- `other_law`, `no_refs`, `unparsed`, `no_list_statement`.

**Refinements during the step (2b, 2c):**
- an item's own "extend to" is read as its own statement;
- provisions the item excludes are not counted as named;
- another law's provisions are `other_law`;
- `withheld` was added.

**Outputs:**
- `verdicts.tsv`: one row per item, keyed by line in `items.tsv`.
- `review.tsv` / `review.json`: each item shape's bucket (`review.py`):
  - `skip`: a plain shape, all read;
  - `read_qualified`: all read, but the shape qualifies;
  - `misread_plain` / `misread_qualified`;
  - `in_unread`;
  - `not_list`.
- `dropped.tsv`: every not-held item in a sentence the reader classes as a list. These are candidates, not verdicts.

**Results:**
- Of 2,271 items in lettered sentences, 801 are read, 34 withheld and 96 not held. The rest name another law, name nothing parseable, or have no list statement.
- 33 provisions in 33 laws have a sentence read as a list with an item dropped. In 17 of them a plain item (no qualifier) is dropped. The rest are items qualified by "so far as", "other than", "except" or "excluding".
- The drops are not concentrated in rare item shapes. They come in common shapes ("SEC", "SECS", "PART (DESC)") inside particular sentences, so here the unit to review is the sentence.

**Spot-checked against the stored lists:**
- ukpga 2015/7 s.56, 2020/16 s.24, 2025/18 s.141, 1972/11 s.30, 1989/15 s.194 and 1994/21 s.68: the named items are absent from every list.
- uksi 2019/696 reg.3 is a doubtful candidate: the items are held as `not NI` while the sentence is read as named UK-wide.
