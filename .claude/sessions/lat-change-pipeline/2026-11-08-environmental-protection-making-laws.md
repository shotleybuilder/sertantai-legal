---
session: 'Environmental Protection: Making laws'
status: closed
opened: '2026-11-08'
closed: '2026-11-08'
family: '💚 ENVIRONMENTAL PROTECTION'
step: Making laws
outcome: success
summary: >
  Step 0 for Family 3: each of the 395 live UK laws decided from its own text — 116 making (115 by text, one by
  review), 259 not making, 21 no verdict (5%); 239 bodies fetched, 63 making laws parsed into LAT (11,726 rows,
  0 errors), so every making law now has rows. Classifier forms added (the "day appointed" commencement, extent,
  evidence, asides, no provisions upstream); 61 of 63 checked laws agreed, the other two decided by Jason.
decisions:
  - what: Shellfish Water Protected Areas Designation (Scotland) Order 2026 — its review (making) stands (Decision 1, a)
    why: a designation has legal effect of its own that the shall/must rule cannot see
    result: making, rows kept; a known limit in RULES making-from-own-text
  - what: Radioactive Contaminated Land (Modification of Enactments) (Wales) Regulations 2006 reviewed to not making (Decision 2, b)
    why: its text is modifications of EPA 1990 Part 2A only (Jason, against the recommendation)
    result: is_making false by review; its rows parked as a LAT parser discard
  - what: the 21 no-verdict laws left as stored (Decision 3, a)
    why: unknown over guess, as Maritime Safety
    result: none given rows
  - what: only UK law read by lat.making_laws
    why: the register's family holds 23 Australian laws legislation.gov.uk does not publish
    result: counted once as out of scope
  - what: commencement words in the classifier only through SentencePatterns
    why: the one-commencement-path architecture test failed on a new "come into force" phrase
    result: EU "shall enter into force" raised against the Commencement reader; EU 2019/1010 making until then
metrics:
  laws: { live_uk: 395, australian_out_of_scope: 23, making: 116, not_making: 259, no_verdict: 21, is_making_changed: 32 }
  sources: { bodies_fetched: 239, fetch_failed: 0, no_provisions_upstream: 5 }
  parse: { laws: 63, rows: 11726, errors: 0 }
  checks: { checked_laws: 63, agree: 61, decided_by_jason: 2, report_runs_identical: true, tests: 10363, failures: 0 }
  cost: { days: 1, plan_changes: 0, agent_tokens: 0, commits: 2 }
lessons:
  - title: Run the architecture tests before applying, not after
    detail: a new standard phrase ("come into force") passed the step's own tests, and the report was applied and parsed on it; the full suite then failed the one-commencement-path test. The fix moved one verdict, so the step re-applied and parsed one more law. Run test/sertantai_legal/architecture/ with the step's tests before any write.
    tag: tooling
  - title: A new family's legal forms surface as no-verdict and one-requirement laws
    detail: Environmental Protection's new forms showed in two places in the report. Commencement orders wording it "the day appointed" read no verdict, and extension orders, evidence formulae and asides gave single false requirements. Read every law decided on one requirement before the apply.
    tag: data
  - title: legislation.gov.uk serves some laws as a scanned print only
    detail: NumberOfProvisions="0" bodies (the Cremation Regulations 1952–79, two EU directives) read as "no operative provision" until named. They are now "no provisions upstream", and none was guessed.
    tag: data
bugs:
  - pattern: "EU wording 'shall enter into force' is not commencement words for SentencePatterns (@cif reads come/came/coming/brought into force or operation only), so a retained EU Regulation's own entry-into-force article reads as a requirement (e.g. UK_eur_2019_1010 art. 11, its only one: decided making)"
    category: eu-enter-into-force
    module: Commencement.SentencePatterns (@cif)
    affected: "1 law decided on it (Environmental Protection); every retained EU instrument's entry-into-force article"
    fix: "read 'enter(s|ed) into force' as commencement words, with catalogue and leftovers re-run; then the Making laws report re-run"
    step: Commencement reader
    status: open
  - pattern: "mix lat.reparse again left lat_reparse_<tag> snapshot tables in public (lat_reparse_making_environmental_protection[_2][_cm], 4 tables) for laws with no rows"
    category: restore-points
    module: Scraper.LatReparse.snapshot!/2
    affected: 4
    fix: "as issue #189; Jason to drop the four tables"
    step: LAT parser
    status: open
    issue: 189
  - pattern: "Making-laws classifier missed 'the day appointed for the coming into force' commencements and read extent, evidence and aside-after-shall wording as requirements (6 commencement orders without a verdict, 6 false making)"
    category: making-classifier-forms
    module: Scraper.MakingLaws
    affected: 12
    fix: "@appointed_day both orders; standard phrases for extent, remain in force, conclusive/received evidence, an aside; commencement words via SentencePatterns"
    step: Making laws
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/making_laws.ex
  - backend/lib/mix/tasks/lat.making_laws.ex
  - backend/test/sertantai_legal/scraper/making_laws_test.exs
  - backend/test/sertantai_legal/scraper/making_laws_checked_test.exs
  - backend/data/reports/making-laws/environmental-protection.csv
  - backend/data/reports/lat-reparse/making_environmental_protection.csv
  - docs/lat-change-pipeline/RULES.md (section 0)
depends_on:
  - 2026-11-08-environmental-protection-meta.md
  - 2026-11-04-maritime-safety-making-laws.md
enables:
  - "Environmental Protection: Sources, on 116 making laws with LAT rows"
---

# Session: Environmental Protection: Making laws (CLOSED)

## Problem

Step 0 for Family 3. Environmental Protection has 395 live UK laws, and only 59 of them have LAT rows. Each live law is decided making or not from its own text, and the making ones are parsed into LAT, so the later steps have rows to label.

Plan (approved 2026-11-08): `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`. Principles: law-text-wins and unknown-over-guess.
- **Time box:** 1½ days.
- **Meta:** `2026-11-08-environmental-protection-meta.md`.

## Todo

- ✅ Open the step session; the meta session's step row
- ✅ Classifier: "day appointed" commencements; standard wording for extent, entry into force, "remain in force", evidence and an aside after "shall"; "no provisions upstream" (tests by kind); the task takes UK laws only
- ✅ Fetch the missing bodies: 239 laws, 0 failed (Jason's go)
- ✅ Report: two runs byte-identical; 61 of 63 checked laws agree, added to the fixture; decisions written
- ✅ Jason's decisions: SSI 2026/57 review stands; SI 2006/2988 reviewed to not making; the 21 left as stored; go
- ✅ Restore point `making-laws-environmental-protection`; `--apply` (374 verdicts, 0 errors); 63 laws parsed from the store (11,726 rows, 0 errors)
- ✅ Rows: all 116 making laws hold rows; 3 not-making laws with rows parked (LAT parser)
- ✅ Close: pass rule re-run (10,363 tests pass), RULES section 0, the meta status row, commits

## Pass rule (fixed)

1. The rule is unit-tested by kind, including "the day appointed for the coming into force of", with the date first or last.
2. The classifier agrees with every checked law held: the family's 63 review and enrichment verdicts, added to `making_laws_checked_test.exs`. Each disagreement is decided by Jason.
3. All 395 live UK laws are accounted for; the no-verdict list is at most 10%.
4. Two runs give a byte-identical CSV.
5. Every law decided making has LAT rows after the parse, or is named with a reason.
6. `mix test` 0 failures; the ratchet and credo clean; hooks pass.

Golden (27) is untouched. The Maritime checked laws are frozen.

## Dependencies

- ✅ The Making laws step, its classifier and task (Maritime Safety, 2026-11-04)
- ✅ The parked owner bugs closed before the family (e2cbf9f5)

## Parking list

- LAT parser: three laws decided not making still hold LAT rows: `UK_uksi_2006_2988` (Decision 2), `UK_uksi_2020_594` (Waste (Prescribed Enactments) (Wales) Regulations) and `UK_uksi_2021_1309` (Environmental Authorisations (Scotland) Regulations 2018 (Transitional …)). LAT holds rows only for making laws, so these rows look wrong. Removing them is a LAT parser discard, not this step.
- Making laws (known class): a prohibition stated only as an offence ("A person who supplies … is guilty of an offence") counts as standard wording. The NI Single-use Vapes Regulations 2024 read making on a weaker provision; counting offences would move one more law (SSI 2014/319). This is below the triage size, so there is no rule change.

## Probe (read-only, 2026-11-08, before any fetch)

- **418 laws are live:** 395 UK and 23 Australian. The Australian laws are out of scope, but the task took them anyway.
- **239 UK laws have no text held.**
- **The 156 held:** 57 making, 88 not making, 11 with no verdict; 10 disagree with the stored `is_making`.
- **No verdict from a classifier gap:** six commencement orders word it "the day appointed for the coming into force of …" or "… is the day appointed for …", and `@appointed_day` matches only "appointed day".
- **Two checked laws disagree with the text:**
  - SSI 2026/57: a designation of areas, plus one amendment;
  - SI 2006/2988: modifications of enactments only.

## Results (2026-11-08)

Report: `backend/data/reports/making-laws/environmental-protection.csv` (395 rows, byte-identical across two runs). The log is beside it.

| Verdict | Laws |
|---|---|
| making | 115 by text (52 with LAT rows, 63 without), plus SSI 2026/57 by its review (Decision 1): 116 |
| not making: changes only | 259 by text, SI 2006/2988 among them (Decision 2) |
| no verdict | 21 (5%; the bound is 10%) |

- **Against the stored `is_making`:** 33 disagree.
  - **9 would become making:**
    - 4 EU directives and regulations;
    - the Climate Change and Waste Act (NI) 2011 (`nia_2011_23`);
    - Senedd Act 2026/4 (`asc_2026_4`);
    - the NI vapes regulations;
    - Quality Parish Councils 2006 (`uksi_2006_1334`).

    All were stored as `default` or `legacy_is_making` false.
  - **22 would become not making.** All are amending-only, and all were stored making by old duty types (`legacy_drrp`).
  - **The other 2 are the checked laws** in Decisions 1 and 2.
- **Checked laws:** 61 of 63 agree.
- **Classifier fixes, each a general form with a test:**
  - "the day appointed for the coming into force of": 6 commencement orders, which had no verdict, now read not making;
  - standard wording:
    - "shall extend (and apply) to";
    - "shall enter into / come into force or operation";
    - "shall remain in force";
    - "shall be conclusive evidence" and "be received in evidence";
    - an aside between "shall" and its verb.

    These moved 5 laws off a false making: SI 1994/1096, SI 1994/2012, SI 1997/1870, and the Guernsey and Jersey extension orders of 1987. With the SI 1988/1084 territories order, 7 in all.
  - "no provisions upstream": 5 laws that legislation.gov.uk holds as a scanned print only (`NumberOfProvisions="0"`): the Cremation Regulations 1952, 1965 and 1979, and Directives 2001/42 and 2002/49.
- **Four laws decided not making hold LAT rows:** the two in Decisions 1 and 2, and two more on the parking list.

## Decisions for Jason

### 1. SSI 2026/57, Shellfish Water Protected Areas Designation (Scotland) Order 2026: review "making", text "not making" — DECIDED (a), 2026-11-08: the review stands

- **Question.** Its text designates 15 areas as shellfish water protected areas (art. 2) and amends the 2013 Order (art. 3). It states no "shall" or "must", so the rule reads it changes only. Its human review says making, and it already has LAT rows. Which stands?
- **Aim:** `binds-on-date`. A designation decides where the Water Environment Act's duties apply, and it is written in no other law's text.
- **Options:**
  - (a) the review stands: making, rows kept. The tiers already rank a review above the text, so nothing changes. The fixture records the text's verdict with a note that the review holds.
  - (b) correct the review to not making (`mix making.review`). The rows become a LAT parser discard.
- **Recommendation:** (a). A designation has legal effect of its own, which the "shall/must" rule cannot see. This is the first one met; it is a known limit of the rule, not a reason to change the rule.

### 2. SI 2006/2988, Radioactive Contaminated Land (Modification of Enactments) (Wales) Regulations 2006: enrichment "making", text "not making" — DECIDED (b), 2026-11-08: reviewed to not making (`mix making.review`); its rows a LAT parser discard (parked)

- **Question.** Its text applies Part 2A of the EPA 1990 to radioactive contamination and modifies the Act for it ("has effect as if"). Under the rule, modifications are changes, so it reads not making. Fractalaw's enrichment says making, and it has LAT rows. Which stands?
- **Aim:** `binds-on-date`. The modified regime is not applied into the EPA 1990's text, so this law is the only place it is written.
- **Options:**
  - (a) the enrichment stands: making, rows kept. Nothing changes, and the fixture notes it.
  - (b) review it to not making. The rows become a discard.
- **Recommendation:** (a), for the reason in Decision 1: a law whose regime lives only in its own modifications binds through them.

### 3. The 21 laws with no verdict — DECIDED (a), 2026-11-08: left as stored

- **Question.** What becomes of them?
- **The laws:**
  - 8 with changes and powers;
  - 8 with no operative provision: designations of directives and enactments, halon derogations, and two extension orders;
  - 5 with no provisions upstream.

  All 21 are stored not making; two have rows (Aggregates Tax (Scotland) Act 2024, and the 2021 halon derogation).
- **Aim:** unknown-over-guess.
- **Options:**
  - (a) leave all 21 with no text verdict and their stored values; none is given rows;
  - (b) rule each now.
- **Recommendation:** (a), as Maritime Safety's Decision 2.

### 4. Go for the apply and the parse — DECIDED go, 2026-11-08

- **Apply:** `--apply` records 374 text verdicts through `Making.record` and changes `is_making` on 31 laws (33 less the 2 above, which their higher tier holds). First, a restore point: `nas-backup.sh --tables legal_register,legal_articles --tag making-laws-environmental-protection`.
- **Parse:** the 62 making laws without rows, from the store (31 uksi, 9 ssi, 8 nisr, 6 wsi, 4 EU, 2 nia, 1 asc, 1 nisi). About 5–10 min. Writes `legal_articles` and the LAT tables.
- **Recommendation:** go, once Decisions 1–3 are settled.

## Apply and parse (2026-11-08)

- **Restore point:** `making-laws-environmental-protection` (`legal_register`, `legal_articles`).
- **Review:** `mix making.review UK_uksi_2006_2988 --verdict not_making` (Decision 2).
- **Apply:** `--apply` recorded 374 verdicts, 0 errors.
- **Parse:** `lat.reparse --store only`, 62 laws, 11,681 rows, 0 errors; none came out empty. Report: `backend/data/reports/lat-reparse/making_environmental_protection.csv`.
- **A late fix.** The full suite failed one architecture test: commencement words may be read only by the commencement readers. My "come into force" phrase is gone, and a provision whose commencement words `SentencePatterns` reads as no statement now counts as standard wording.
  - "Shall enter into force" is not among the reader's words, so EU 2019/1010 reads making again on its art. 11. That is raised against the Commencement reader (frontmatter).
  - The report was re-run (byte-identical twice); only that law's verdict moved. Re-applied, and the law parsed (45 rows).
- **Result:** 116 making laws, every one with LAT rows.
