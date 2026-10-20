---
session: "AR-07: One-Word Caption Read as a Target"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
bugs:
  - pattern: 'A one-word caption ("(interpretation)") becomes a bracket target (s.336(interpretation)) that matches no row'
    category: amendment reader
    module: Amendment.Reader.brackets
    affected: '295 rules in 144 amending laws (3,904 targets); pilot: 2,995 removed from 3 laws'
    fix: 'a bracket is a number, a letter or two, or a roman numeral (AR-07)'
    status: fixed
  - pattern: 'Spurious targets from a quote''s own numbers and captions: s.99(99), s.47B(47C), s.88(c), s.i'
    category: amendment reader
    module: Amendment.Reader
    affected: 's.i: 1,493 rules / 367 laws; s.99(99): 366 rules / 155 laws (pre-fix counts)'
    fix: 'a quoted path is a provision only when it starts with a number; a whole section substituted or inserted has its quote''s numbers as sections. Skip-level combos (s.88(c) beside s.88(1)(c)) kept: the old matcher''s set semantics, never both real (AR-07)'
    status: fixed
---

# Session: AR-07: One-Word Caption Read as a Target (ACTIVE)

## Problem

A one-word caption ("(interpretation)") becomes a bracket target (`s.336(interpretation)`) that matches no row — harmless today, but a rule naming a row that cannot exist (AR-03 open bug; `Amendment.Reader.brackets`; 10+ rules).

## Todo

- ✅ With it: spurious targets from a quote's own numbers (s.99(99), s.47B(47C), s.88(c), s.i — AR-05 trace, EReA 1999 on ERA 1996)
- ✅ A bracket holding a word (not a number or letter) is never a target (reader test first)
- ✅ Count the rules it changes; batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)

## Fix and pilot (2026-10-20)

- **Count** (stored rules; the regex buckets overlap with real targets): word brackets 3,904 targets in 295 rules / 144 laws; `s.i`-style 2,655 targets in 1,493 rules / 367 laws; self-nested `s.99(99)` 3,253 targets in 366 rules / 155 laws. "Section nested in section" (29,551) and "skipped level" (13,773) include real subsections (`s.5(5A)`) and paragraphs, so they aren't a bug count.
- **Fix (`Reader`):**
  - A bracket is a number, a letter or two, or a roman numeral; a one-word caption is not one.
  - A quoted path is a provision of its own only when it starts with a number.
  - When the instruction substitutes or inserts whole sections ("For section 7", "after section 47B", not "for section 7(2)"), the quote's numbers are sections.
  - Skip-level combinations kept.
  - Tests first (4, one a guard that "after subsection (4) insert— (4A)" stays `s.7(4A)`); suite 2,903 pass.
- **Pilot:** re-read EReA 1999, CEMA 1979 (ukpga 1979/2) and ukpga 1988/1. Targets removed: 2,995 word brackets, 61 self-nested, 2 `s.i`; 0 real targets lost.
- **Preview** `ar07_pilot` (ERA 1996, 1967/8, 1968/27, 1976/72, 1986/31; no write): no losses. ERA 797 label changes (777 in `ar12_pilot`): 20 more rows get their own later changes dated (e.g. s.105(7BA) 2005-04-06, s.166(5)(a)/(b) 2020-12-31). 1986/31 s.63(8)[S] is AR-06's.
- The corpus re-read goes with the AR measure run.
