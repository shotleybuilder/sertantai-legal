---
session: "AR-07: One-Word Caption Read as a Target"
status: closed
opened: '2026-10-20'
closed: '2026-10-20'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md
summary: >
  The reader no longer makes targets that can name no row: a one-word caption is no bracket, a quoted sub-paragraph is
  never a provision of its own (s.i), and a whole section substituted or inserted has its quote's numbers as sections
  (no s.99(99)) (1fa9cb6e). Pilot on 3 amending laws removed 2,995 word-bracket, 61 self-nested and 2 s.i targets with
  no real target lost; preview on 5 laws: no losses.
decisions:
  - what: Keep the skip-level combinations (s.88(c) beside s.88(1)(c))
    why: they are the old row matcher's set semantics ("In paragraph (a) of section 7(2)"); a section never has both forms, so they reach no wrong row
    result: unchanged
  - what: '"Whole sections" only when the instruction names a section with no bracket ("for section 7", not "for section 7(2)")'
    why: '"For section 7(2) substitute— (2)" quotes a subsection that must stay numbered from its section'
    result: guard test (s.7(4A))
  - what: Pilot on 3 amending laws, corpus re-read with the AR measure run
    why: ~500 amending laws carry one of the forms; prove the change on a few first
    result: 3,058 spurious targets removed, 0 real
metrics:
  stored_before: { word_bracket_targets: 3904, word_bracket_rules: 295, letter_provision_rules: 1493, self_nested_rules: 366 }
  pilot: { amending_laws: 3, removed_word: 2995, removed_nested: 61, removed_letter: 2, real_lost: 0 }
  preview_ar07: { laws: 5, losses: 0, era_label_changes: 797 }
lessons:
  - title: Regex counts of "bad" targets overstate; separate the never-real forms first
    detail: 'The "section nested in section" bucket (29,551) and "skipped level" (13,773) mostly matched real subsections (s.5(5A)) and paragraphs. Only forms that can never name a row (a word, a bare letter, a number nested in itself) were safe to remove.'
    tag: data
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
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader.ex
  - backend/test/sertantai_legal/scraper/amendment/reader_test.exs
  - backend/data/reports/lat-refactor/ar07_pilot.csv
depends_on:
  - 2026-10-20-ar-06-repeals-table-numeric-quote
enables:
  - the AR measure run
---

# Session: AR-07: One-Word Caption Read as a Target (CLOSED)

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
