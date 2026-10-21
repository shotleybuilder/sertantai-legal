---
session: 'LR-09: QA Run 4'
status: pending
release: v0.1
opened: 2026-10-11
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-09 QA Run 4 (PENDING)

## Problem

Wave 4 (LR-06) wrote LR-02–LR-07 into the dev DB, and the DB equals a fresh parse. That does not show the parser reads the law right: the last independent QA (3b) said not ready. QA run 4 is the agent-led randomised sample against the spec updated to Jason's signed guide (LR-12), judged by the pass mark agreed before the run. (Plan step 5, LR-00 meta, 2026-10-12. The guide moved to LR-11, the fractalaw message to LH-05.)

## Todo

- ⬜ Two samples, new seeds (`mix lat.qa_sample`), read-only agents per `docs/LAT-QA-SAMPLE-SPEC.md`
- ⬜ Findings classified against the known-limits list (compiled in LR-12); verdict against the agreed pass mark (LR-12)
- ⬜ If fail: fix test-first → targeted wave (dry run → Jason → apply) → new seeds; repeat
- ⬜ Jason accepts the verdict → LH-05

## Decisions for Jason

- **D1 — Verdict**: accept the readiness verdict (against LR-12's pass mark)
- **D2 — Any fix wave** after a failed run: dry run → approve

## Dependencies

- ✅ LR-06 wave 4 applied and verified (`lat-refactor/2026-10-09-lr-06-wave-4-qa.md`)
- ⬜ LR-10, LR-13–LR-18 done; LR-12 spec + pass mark agreed; LH-07 done
