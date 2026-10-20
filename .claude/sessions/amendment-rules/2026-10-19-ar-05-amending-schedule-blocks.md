---
session: "AR-05: Blocks from the Amending Law's Own Schedule"
status: active
opened: '2026-10-19'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-05: Blocks from the Amending Law's Own Schedule (ACTIVE)

## Problem

Amendment ruleset (AR-00 meta): "Part I of Schedule 4 shall be substituted for Part VIII" (EReA 1999 on ERA 1996): a target whose new text is the amending law's own Schedule.

## Todo

- ⬜ Trace EReA 1999 → ERA 1996 Pt VIII today: what `mix lat.amending --law UK_ukpga_1999_26` reads, which rows the feed and markup date, what is missing
- ⬜ Find the other instances: rules (or unread instructions) substituting / inserting a block "for" / "as" the amending law's own Schedule or Part — count across the stored rules
- ⬜ Reader: such an instruction targets the amended block (Part / range), its rows reached as a provision-level change (reader + collect tests first)
- ⬜ Pilot on the affected laws (`mix lat.wave_preview --relabel --laws …`); classified diff; batch into the AR measure run
- ⬜ Close LR-43's open bug as fixed when reached

## Dependencies

- ✅ AR-00 schema decided (2026-10-19)
- ✅ AR-04 switch-over applied (2026-10-20)
