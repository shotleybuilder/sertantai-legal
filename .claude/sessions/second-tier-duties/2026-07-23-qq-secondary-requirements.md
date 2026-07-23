---
session: QQ Secondary Requirements — ACoP/Guidance Mapping
project: sertantai-legal
status: pending
opened: 2026-07-23

summary: >
  Map QQ guidance citations to existing secondary sources in sertantai. The QQ
  requirements mapping identified 26 guidance/ACoP/code-of-practice items referenced
  across 389 requirement rows. 14 are HSE ACoPs with L-codes that should already
  exist in our secondary_sources table. Remaining items include international
  dangerous goods codes (ADR, RID, IMDG, ICAO), Welsh/EA codes of practice, and
  EH40. Goal: link QQ requirements to our parsed secondary provisions where coverage
  exists, and identify gaps.

depends_on:
  - qq-requirements/2026-07-22-qq-requirements-mapping.md
  - qq-requirements/2026-07-22-unmatched-triage.md
  - second-tier-duties/2026-07-16-parse-acops.md
  - second-tier-duties/2026-07-16-parse-hsgs.md
---

## Context

The QQ requirements mapping pipeline classified 389 lrt rows (26 unique titles) as
`guidance`. These are ACoPs, HSGs, codes of practice, and international codes that
QQ tracks alongside statutory requirements. Our secondary sources pipeline has already
parsed 21 ACoPs and 29 HSGs into provisions — many of these QQ guidance items should
map directly.

## QQ Guidance Items (26 unique, by requirement count)

### HSE ACoPs with L-codes (14 items, ~248 requirements)

| L-code | Title | QQ reqs | In sertantai? |
|--------|-------|---------|---------------|
| L22 | Safe Use of Work Equipment | 48 | Check |
| L132 | Control of Lead at Work | 34 | Check |
| L143 | Managing and Working with Asbestos | 31 | Check |
| L24 | Workplace Health, Safety and Welfare | 28 | Check |
| L121 | Work with Ionising Radiation | 24 | Check |
| L5 | Control of Substances Hazardous to Health | 21 | Check |
| L138 | Dangerous Substances and Explosive Atmospheres | 18 | Check |
| L25 | Personal Protective Equipment at Work | 11 | Check |
| L56 | Safety in Gas Systems and Appliances | 10 | Check |
| L101 | Safe Work in Confined Spaces | 8 | Check |
| L112 | Safe Use of Power Presses | 3 | Check |
| L153 | Managing Health and Safety in Construction | 1 | Check |
| L8 | Legionnaires' Disease (Legionella) | 1 | Check |
| L74 | First Aid at Work | 1 | Check |

### HSE Exposure Limits (1 item, 8 requirements)

| Item | QQ reqs | Notes |
|------|---------|-------|
| EH40/2005 Workplace Exposure Limits | 8 | Published as table document, not ACoP |

### International Dangerous Goods Codes (4 items, ~131 requirements)

| Item | QQ reqs | Notes |
|------|---------|-------|
| RID 2025 (Rail) | 38 | International convention |
| ADR 2025 (Road) | 38 | European agreement |
| ICAO Technical Instructions 2025-26 | 31 | Aviation |
| IMDG Code, 42-24 Edition | 21 | Maritime |
| ADN 2015 (Inland Waterway) | 3 | European agreement |

### Codes of Practice / Environmental (5 items, ~8 requirements)

| Item | QQ reqs | Notes |
|------|---------|-------|
| Waste Duty of Care Code of Practice | 3 | Defra |
| Separate Collection for Recycling (Wales) | 2 | Welsh Gov |
| UN Model Regulations (DG transport) | 1 | International |
| EA UK ETS Charging Scheme 2021 | 1 | Environment Agency |
| MRF Sampling & Reporting Code of Practice | 1 | Defra |
| Duty of Care: Managing Controlled Waste | 1 | Defra |

## Tasks

- [ ] Cross-reference 14 ACoP L-codes against secondary_sources table
- [ ] Check which ACoPs have parsed provisions (from parse-acops session)
- [ ] Map QQ requirements to secondary_source_provisions where coverage exists
- [ ] Identify gap ACoPs (in QQ but not parsed)
- [ ] Assess international DG codes — are these in scope for sertantai?
- [ ] Assess environmental codes of practice — link to environmental guidance session findings
- [ ] Add matched secondary citations to QQ SQLite store (new table or lrt category)
