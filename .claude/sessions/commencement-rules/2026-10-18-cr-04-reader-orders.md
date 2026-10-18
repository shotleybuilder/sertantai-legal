---
session: 'CR-04: Reader — Commencement Orders'
status: pending
opened: '2026-10-18'
parent: commencement-rules/2026-10-18-cr-00-meta.md
---

# Session: CR-04: Reader — Commencement Orders (PENDING)

## Problem

A commencement order becomes rules about the law it commences. Today `CommencingOrder` reads orders only for hop 2 and finds no date for 1,463 amending-law records whose orders are held (LR-44).

## Todo

- ⬜ Trace a sample of the 1,463: why no date is read (list forms, Schedules to the order, "so far as not already in force", territory, purposes)
- ⬜ Reader: an order's articles and Schedules → rules (`scope`, `when: date`, territory, purposes, `not_already_in_force`)
- ⬜ Which orders: those notes name (hop 2) and those made under a law's commencement power (for CR-07)
- ⬜ Classified diff vs `CommencingOrder` on the benchmark; date differs (854) expected down

## Dependencies

- ⬜ CR-01, CR-02; LR-42 (orders held)
