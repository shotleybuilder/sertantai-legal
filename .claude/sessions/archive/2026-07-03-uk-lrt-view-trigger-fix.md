---
session: uk_lrt view INSTEAD OF trigger fix
project: sertantai-legal
status: closed
opened: 2026-07-03
closed: 2026-07-03
outcome: success
commits: [0811928]

summary: >
  Fixed 59 test failures caused by migration 20260702000003 which recreated the
  uk_lrt view as SELECT * FROM legal_register_uk, destroying the INSTEAD OF
  INSERT/UPDATE/DELETE triggers. Restored the original view pattern with
  significance columns added.

decisions:
  - what: Restore uk_lrt as explicit-column view on legal_register (parent) with WHERE country='uk'
    why: PostgreSQL BEFORE triggers on partitioned tables conflict with inserts routed through partition logic. The INSTEAD OF triggers bypass this by inserting into the parent table directly.
    result: 59 failures → 0 failures, 1461 tests passing

metrics:
  tests: { before: 1402_passing_59_failing, after: 1461_passing_0_failing }
  triggers_restored: 3

lessons:
  - title: Never DROP VIEW uk_lrt without recreating INSTEAD OF triggers
    detail: >
      The uk_lrt view is not a simple SELECT * FROM legal_register_uk. It has
      INSTEAD OF INSERT/UPDATE/DELETE triggers that bypass partition routing.
      DROP VIEW destroys these silently. Any future column additions to
      legal_register require updating the view AND all three trigger functions.
    tag: schema
  - title: SELECT * FROM partition exposes the partition key column
    detail: >
      PostgreSQL expands SELECT * at view creation time. A view over a partition
      that includes the country column causes INSERT routing through the parent
      table's partition logic, which conflicts with BEFORE ROW triggers. The
      original view excluded country by using an explicit column list.
    tag: infrastructure
  - title: Gate destructive psql commands in settings.local.json
    detail: >
      The blanket Bash(PGPASSWORD=postgres psql *) permission auto-approved
      DROP VIEW without prompting. Narrowed to SELECT and \d only — writes
      now require manual approval.
    tag: tooling

artifacts:
  - backend/priv/repo/migrations/20260703000001_fix_uk_lrt_view_with_triggers.exs
  - .claude/settings.local.json

depends_on:
  - 2026-07-02-significance-signals.md

enables:
  - Safe future column additions to legal_register
---
# Title: uk_lrt View INSTEAD OF Trigger Fix

**Started**: 2026-07-03

## Todo
- [x] Investigate 59 test failures from uk_lrt view recreation
- [x] Identify root cause: INSTEAD OF triggers lost by DROP VIEW
- [x] Create migration to restore view + triggers with significance columns
- [x] Verify 1461 tests pass, 0 failures
- [x] Commit and push
- [x] Gate destructive psql in settings.local.json
- [x] Save memory about uk_lrt view triggers

## Notes
- Root cause: migration 20260702000003 used `CREATE VIEW uk_lrt AS SELECT * FROM legal_register_uk`
- Original view (20260518000001) was explicit columns from `legal_register WHERE country = 'uk'` with INSTEAD OF triggers
- The INSTEAD OF triggers insert into `legal_register` (parent) with `country = 'uk'` hardcoded, bypassing partition routing
- PostgreSQL 17 limitation: BEFORE FOR EACH ROW triggers on partitioned tables block view inserts that route through partition logic
- Memory saved: `feedback_uk_lrt_view_triggers.md`
