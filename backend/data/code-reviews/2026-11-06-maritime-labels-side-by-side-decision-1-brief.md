# Decision brief: which law the single `changed_by` names where several laws made the text

## Context

SertantAI holds UK legislation, cut into provision rows (a section, regulation or article, and its sub-paragraphs). A pipeline turns legislation.gov.uk's change data into a label timeline per row. Each period gives:
- `status`, `in_force_from` and `territory`;
- `changed_by_all`, every law that made the row's current text;
- `commenced_by`;
- `changed_by`, a single law, because the production compliance app reads one value: "which law last changed this text".

The aim it serves is that a user can see whether a provision binds them on a date they pick, and which law made it so.

## The question

Where `changed_by_all` holds several laws, which one goes in the single `changed_by`?

**Today's code** takes the last of `changed_by_all`, which is sorted by name, e.g. `UK_uksi_2019_758` < `UK_uksi_2020_1577`. That is close to "the latest-numbered law", but by accident:
- the comparison is of strings, so `UK_uksi_2019_858` sorts after `UK_uksi_2019_1144`;
- the type prefix decides between series, so `uksi` beats `ssi` and `asp` whatever the year.

## What the data shows

The whole timeline table holds 656,605 periods; 375 have more than one maker, in 24 laws, 8 of them repealed periods.

- **327 of the 375 start on 2020-12-31,** the day EU law became UK law. Most are in REACH (`UK_eur_2006_1907`, 230) and CLP (`UK_eur_2008_1272`, 47).
  - The typical case is REACH Article 127E(10): `changed_by_all` = SI 2019/758, SI 2019/858, SI 2020/1577.
  - SI 2019/758 is the exit SI that made the text.
  - SI 2019/858 and SI 2020/1577 amended SI 2019/758 itself before it took effect. legislation.gov.uk's feed marks these as "in earlier amending provision", and the pipeline credits them deliberately (rule `earlier-amendment-credited`, Jason 2026-10-30).
  - Every maker's change takes effect the same day, so "the latest dated change" cannot tell them apart.
  - Today's single `changed_by` is SI 2020/1577.
- **The rest are parallel changes on one day,** from laws of different series or extents:
  - SI 1999/3242 reg.10(1)(c) on 2006-10-01: SSI 2006/457 (Scotland) and SI 2005/1541 (E+W);
  - Corporate Manslaughter Act 2007 s.6(2)(b) on 2013-04-01: ASP 2012/8 and SI 2013/602;
  - SI 2013/1471 reg.15(5)(b)(i) on 2017-04-06: SI 2017/238 and SI 2017/304.

  Today the single value is the UK SI in each.
- **The rulings so far** (RULES.md open decision 1):
  - 2026-10-31: "the law that made the text, else the law that commenced it — the old labels' meaning".
  - The open decision's own recommendation: "the maker of the latest dated change, and never an earlier-amendment credit"; compliance reads `changed_by_all` for the full answer.
  - A repealed period names the repealer, as today.
- **Golden test** checks `changed_by_all` (the full list), not the single value.
- **The cost** is small whichever way. The fold knows, for each change, whether it is an earlier-amendment credit (a flag from the feed), so the single value can be chosen in the fold. The change is a few lines and a unit test; `changed_by_all` is untouched.

## Options

**A. The principal maker, then the latest made.**
- Drop earlier-amendment credits, the amenders of the amender. Among the laws left, take the latest made: by year, then number as an integer, with the series ignored.
- If every maker is a credit, fall back to the latest made of all.
- REACH Article 127E(10) → SI 2019/758, the exit SI that made the text.
- A parallel UK/Scottish pair → the later-made law, whatever its series.

**B. The latest made of all makers** (year, then number as an integer).
- REACH Article 127E(10) → SI 2020/1577, as today.
- It fixes only the string and series accidents. The amender of the amender stays the headline law.

**C. Keep alphabetical.** RULES records it as a known difference, and compliance is pointed at `changed_by_all`.

**D. Leave the single value empty where several laws made the text** (unknown over guess).
- Compliance must read `changed_by_all` for these 375.
- This risks blank cells in a column that users expect filled.

## Recommendation

**A.**
- It follows both earlier rulings: the law that made the text, never an earlier-amendment credit.
- It gives the law a user would look up for REACH's exit-day text: the exit SI, not a correction to it.
- It makes the parallel cases deterministic on a meaningful key, the latest made, rather than on how the names sort.
- `changed_by_all` still lists every maker, so nothing is lost.

## Review asked

1. Is A right for a compliance user? Is there a better rule for exit-day chains or for parallel GB/Scottish changes? For example, choosing by the row's territory version.
2. Name any risk in A that we have missed. For example, a principal maker that is itself later revoked, or a credit that is the only maker in a later period.
3. Answer in under 600 words, with a clear pick.
