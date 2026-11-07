# Maritime Safety: switch-over known limits (named 2026-11-07)

These are the rows that break the switch-over's rules (`mix lat.label_rules --family "TRANSPORT: Maritime Safety"`, after the feed reader fix and the rebuild). Each class is a one- to three-row form below the step's triage size, so it is named here, not fixed. Its bug is parked with its owning step (`.claude/sessions/lat-change-pipeline/2026-11-06-maritime-safety-switch-over.md`). The rules check lists these rows apart, and the switch keeps their old label (`KnownLimits`, Jason 2026-11-02). A row leaves the list when its owning step fixes the class.

| Row | Amending law | Why | Owning step |
|---|---|---|---|
| UK_ukpga_1995_21:s.256A | UK_uksi_1999_1820 | date gap: inserted by SI 1999/1820 (law text), undated; folded as the text's maker from the Act's start (1996-01-01) | Label fold |
| UK_ukpga_1995_21:s.256A(1) | UK_uksi_1999_1820 | date gap: as s.256A | Label fold |
| UK_ukpga_1995_21:s.256A(2) | UK_uksi_1999_1820 | date gap: as s.256A | Label fold |
| UK_ukpga_1970_36:s.42(1) | UK_nisi_1995_1980 | date gap: an undated NI repeal (feed) beside the dated 1992 repeal; folded from 1970-05-29 | Label fold |
| UK_uksi_1975_2220:reg.2 | UK_uksi_1998_929 | date gap: substituted by SI 1998/929 (law text), undated; folded from 1977-01-01 | Label fold |
| UK_ukpga_1995_21:s.284(4) | UK_ukpga_1997_28 | a change by the 1997 Act (markup) dated 1996-09-15 by the commencement source, before the Act was made (1997-03-19) | Commencement reader |
| UK_ukpga_1995_21:s.85(3) | UK_ukpga_1997_28 | a words repeal by the 1997 Act Sch. 7 (law text) dated 1996-09-15, before the Act was made | Commencement reader |
| UK_uksi_1998_1258:reg.7(b) | UK_uksi_2004_1273 | no period from the law's making (1998-05-19): the first period is the 2004 repeal | Label fold |
