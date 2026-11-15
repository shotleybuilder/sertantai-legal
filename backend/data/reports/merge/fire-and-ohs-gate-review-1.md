# Fire and OH&S: Merge, gate review 1 (2026-11-15)

The gate had 85 groups not named in the round (413 changes), plus 1 in Environmental Protection and 1 in Occupational. First a scratch script checked every change by shape (`dump_merge.exs`, `shape.py` and `show.py` in the session scratchpad). The checks:
- the sources name one operation family;
- the markup note cites the change's law;
- the feed's amending provision is related to the law text's.

Every U, C and markup-alone change was then read with the changes beside it, in the stored claims, the notes and the amending law's text.

## By shape: one event, joined right (67 groups, 341 changes)

- **A joined event lent to a provision its effect doesn't name** (14 groups, 142 changes). One instruction makes several provisions, and the feed records one effect: "insert sections 43A–43G" (asp 2012/8 s.119), FRSA 2004 ss.4A–4D and 5A–5M (2017 c.3 Sch.1), and the others.
  - In every change, the instruction is the feed effect's own amending provision.
  - The exception: SI 2020/641 names its articles "art." where the feed has "reg." (the partner rule's art./reg. equivalence).
  - SI 2016/315 reg.7 substitutes SI 2014/1638's Part 13 (69 changes). 40 of them carry the law text's `#dropped` repeal: rows numbered by later laws (reg.66(1), 68(1A), 73(3)–(6) and others). By `Dropped`'s rule these are one event with the substitution, and the fold gives them no repeal (the Amending-law reader's review, by design).
- **Related amending provision** (15 groups, 76 changes): a Schedule's Part named by the feed, the whole Schedule by the law's text (SI 2014/3248 Sch.3 Pt 1, 2004 c.20 Sch.23 Pt 1, 2005 c.14 Sch.13 Pt 1 in Occupational, and others). Some exceptions, each joined right:
  - a paragraph's sub-paragraph named by the law (2004 c.21 Sch.1 para.33(3), SI 2004/2043 Sch.3 para.3(a), (b));
  - a legacy markup Addition for a repeal (1984 c.60 Sch.7 Pt V, by design);
  - SI 1993/1897 Sch.3 Pt II, which the law's text reads as a repeal where the note says "substituted". That is the operation of the Amending-law reader, and the event is one.
- **Two law-text records** (3 groups, 73 changes): the paragraph and its repeals Schedule, both named by the feed's one effect (NISR 2006/425 Sch.6 para.1 and Sch.7 Pt 1; 1998 c.17 Sch.4 para.33 and Sch.5 Pt 1; 2004 c.20 s.151(5)(b) and Sch.23). The by-design cause "the feed names together" misses them only because the feed names the Schedule's Part.
- **Several markup records** (6 groups, 11): a legacy note and a modern effect id, both for the one effect.
- **Legislation.gov.uk names no amending provision** (2 groups, 5): repeals tables of 2003 c.22 and NISR 2015/223.
- **Legislation.gov.uk's unlike operations:**
  - renumbered/substituted, SI 2016/315 regs 8–9 (6): the feed renumbers, and the markup shows the new number as a substitution (Maritime's renumbering, by design);
  - repealed/repealed in part (2).
- **Legacy markup id** (1), and **markup alone beside its joined twin** (SSI 2006/367, 1: the note cites reg.1(1), the commencement piece; the Markup reader's parked `note-citation-bracketed-list-read-short`).
- **Spread: joined across provisions** (9 groups): one instruction or repeals table over many provisions (SI 1974/1885 Sch.1 over 27 sections of the 1875 Act; SI 2019/696 Sch.16 para.28; SI 2020/852's one markup id over regs 69–77). Each is one event.
- **Law-text copy apart from its joined event** (SI 2000/1937, 1): Sch.1 para.3 on s.10(1)(b), the inserted words beside the substitution the markup placed. A copy only.
- **Environmental Protection, candidate @ EU 2019/1010** (4): one EU consolidation marker on Article 54 beside the feed's effects on 54, 54(1) and 54(2). Left apart by design (OH&S, Jason 2026-10-28).

## Markup alone, no partner (15 groups, 44 changes)

In 13 groups, legislation.gov.uk's legacy markup stands alone. The feed holds no effect there, and the law's text read gives no change of that kind on that provision. This covers:
- SI 2020/852 on SI 2014/1638 regs 69–77 (11);
- SI 2000/1937 Sch.1 para.9(e) (5);
- SI 1993/1897's old repeals (4);
- SI 1999/742, 1998 c.17, SI 1987/37, 1975 c.59 and others (1 to 3 each).

A legacy repeal shown as an Addition is by design. The other two groups are splits:
- **SI 1988/1729 on the Mines and Quarries Act 1954 ss.22–25 and 33–35** (7 markup plus 7 law text, under "unjoined" too). The note reads "by S.I. 1988/1729, regs. 1(1), 12(1)(a)". The markup reader keeps only reg.1(1), so the markup never meets the law's reg.12(1)(a): **one event split in 7 places.** This is the Markup reader's parked `note-citation-bracketed-list-read-short` (Environmental Protection: EPA s.153(1)(ee), "arts. 1, 2"). The Markup reader's plural fix of 2026-11-14 ("arts. 1, 2") doesn't reach bracketed pieces: a residual, raised as its own bug.
- **1984 c.12 on 1962 c.58 s.40(2)** (1): the note cites Sch.5 para.45 and the law's text Sch.4 para.41(b). Unrelated provisions, kept apart.

## Unjoined (14 groups, 37 changes)

| Amending law | Changes | Why left apart | Disposition |
|---|---|---|---|
| NISR 2007/247 | 8 | **Placed on the wrong law.** Sch.10 para.3 amends the Prevention of Fire and Explosion Regulations (NI) 1995 (NISR 1995/345). Its title is printed "(Northern Ireland)1995", with no space, so its records were placed on para.2's law, NISR 1995/340 (reg.2(1), and reg.17 once more). NISR 1995/345 holds para.3's feed effects alone. | The Amending-law reader's. One law, below triage: a known limit, or parked (Decision 2) |
| SI 1988/1729 | 7 | The note citation is read short (above) | The Markup reader's (parked) |
| 2003 c.39 | 4 | The law's commencement date (26.1.2004) is not the feed's (1.4.2005), so the day rule keeps them apart | The Commencement reader's date |
| 2017 c.3 | 3 | Dates again: s.12 is read as 17.7.2017, the feed has 31.1.2017; s.37 likewise | The Commencement reader's date |
| SI 2005/1082 | 3 | The repeals Schedule (Sch.6) names a section the feed records as several effects, one per paragraph, each naming Sch.6: several partners | Known, ambiguous |
| SI 2000/3097 | 2 | One feed effect "reg.2(b)" for three items (b)(i)–(iii); the second law-text record joins only where the feed names it apart (no snowball, by design) | Known limit (visible) |
| asp 2012/8 | 2 | s.45: substitution against the feed's repeal (other events). s.35(6): the markup cites SI 2013/602, not the law | Known |
| NISR 2006/425 | 2 | s.83 whole in the law's text; the feed has two effects, on s.83(a) and (b): several partners | Known, ambiguous |
| 2008 c.32, 2004 c.20 | 1 each | Several effects name the repeals Schedule (2008 c.32); the date differs (2004 c.20) | Known |
| SI 2005/3117 | 1 | Sch.9 para.5(a)(i)'s lead-in (the Amending-law reader's known limit "the parent's words after its list") | Known |
| SI 2000/1937, 1984 c.12, SI 2023/861 | 1 each | Two legacy notes on one place; unrelated provisions; the feed names reg.6(3) where the law's text has reg.6(4) | Known |

## A Merge class: the feed's compound amending provision (Decision 1)

legislation.gov.uk names two pieces of one amending provision in one string: "reg. 4(2)(a)(b)" for (a) and (b), and "reg. 10(1)(3)" for (1) and (3). The merge compares it whole. The first law-text record joins as related, and the second stays apart, since `named_apart?` finds no second piece.

- **In the round:**
  - NISR 2007/165 on NISR 1996/228 reg.2(1) and NISR 1995/340 reg.2(1) (3: "reg.2(2)(a)(b)", "(c)(d)", "reg.4(2)(a)(b)");
  - 1998 c.17 on 1992 c.15 (3: "sch.4.para.33(2)(3)", "(2)(4)");
  - SI 2000/3097 on SI 1994/232 (1: "reg.2(e)(f)").

  None is in a stratum, so the gate does not see them.
- **Corpus-wide** (a scan of feed claims against the law-text-only changes): 39 changes by 11 amending laws:
  - SI 1998/1420 on the Road Traffic Act 1988 (19);
  - 1995 c.25 on the Control of Pollution Act 1974 and EPA 1990 (3);
  - SI 1999/1820 (3), 1997 c.28 (2), SI 1996/1974 (2), and others.
- **Over the triage size** (two or more laws). It is the Merge's own comparison: the feed reader carries "(a)(b)" as written. The fix reads a compound's last brackets as sibling pieces when they are of one kind: letters, numbers, or roman numerals both (never "(a)(i)", a nesting).

## Parked bugs' reach in the round

1. **`Partner.same_day?`, a made record on the effect's day** (Road Traffic Act 1988): 0 in the round's gate.
2. **No tie-break between a maker's own effect and its made record** (SI 2014/1638 reg.68(1)): the change is joined, under "lent" by SI 2016/315. 1 instruction, below triage: a known limit.
3. **Markup lends a range's middle provisions the effect, never the `#made` key** (CLP): 0 in the round's gate.
4. **A legacy note's affecting pointers are only the piece marked operative:** the shape of SSI 2006/367's twin (1). The same shape as `note-citation-bracketed-list-read-short`, which also reaches SI 1988/1729 (14). Both are the Markup reader's: moved to it.
5. **Town and Country Planning's twin-apart:** recorded only.
