# Fire and OH&S: the switched families' refold, group by group

From `mix lat.label_switch --family F --stored --rows` (2026-11-17), EP, Occupational and Maritime: 2,239 rows in 30 laws, 104 groups (law, today's status old → new, fields differing). One example per group, with the stored changes reaching it, is in the session's scratch `groups.txt` / `groups-changes.txt`; the per-row lists are `fire-and-ohs-switched-*-rows.tsv`.

## Orders on their own legislature's Act now date it fully (Commencement reader territory rule, a9af8e41)

397 rows, 5 groups

- G1 UK_asc_2023_2 in_force_partial->in_force (150): UK_asc_2023_2:s.1
- G2 UK_asp_2026_6 in_force_partial->in_force (10): UK_asp_2026_6:s.9
- G25 UK_ukpga_1990_43 in_force_partial->in_force (182): UK_ukpga_1990_43:s.34(1A)n1[S]
- G59 UK_ukpga_1995_25 in_force_partial->in_force (46): UK_ukpga_1995_25:s.108(16)[E+W]
- G84 UK_ukpga_2021_30 in_force_partial->in_force (9): UK_ukpga_2021_30:s.114

## A staged commencement's stages folded: partly in force before the full date, or a staged text change dated from its first stage (Label fold Decision 2 a, Label.Stages; label-reads-commencement-stages; limited-items-are-partly-in for NERC s.89A)

945 rows, 27 groups

- G6 UK_ssi_2018_219 in_force->in_force (2): UK_ssi_2018_219:reg.3(2A)
- G7 UK_ssi_2018_219 in_force->in_force (2): UK_ssi_2018_219:reg.3(3)
- G8 UK_ssi_2018_219 in_force->repealed (2): UK_ssi_2018_219:reg.3(3)(a)
- G13 UK_ukpga_1961_34 in_force->in_force (1): UK_ukpga_1961_34:s.176
- G14 UK_ukpga_1961_34 in_force->in_force (1): UK_ukpga_1961_34:s.176(1)
- G15 UK_ukpga_1961_34 in_force->in_force (1): UK_ukpga_1961_34:s.184(1)
- G19 UK_ukpga_1974_37 in_force->in_force (50): UK_ukpga_1974_37:s.11(4)(i)
- G20 UK_ukpga_1974_37 in_force->in_force (32): UK_ukpga_1974_37:s.11(4)(a)
- G22 UK_ukpga_1974_37 repealed->repealed (3): UK_ukpga_1974_37:s.44(7)(b)
- G24 UK_ukpga_1990_43 in_force_partial->in_force (654): UK_ukpga_1990_43:s.34B
- G35 UK_ukpga_1990_43 in_force->in_force (4): UK_ukpga_1990_43:s.150(1)(b)(ii)[S]
- G36 UK_ukpga_1990_43 in_force->in_force (4): UK_ukpga_1990_43:s.52(1)(a)[E+W]
- G40 UK_ukpga_1990_43 repealed_saved->repealed_saved (3): UK_ukpga_1990_43:s.78YB(2A)[S]
- G49 UK_ukpga_1990_43 repealed->repealed (1): UK_ukpga_1990_43:s.150(1)(b)(ii)[E+W]
- G51 UK_ukpga_1990_43 repealed->repealed (1): UK_ukpga_1990_43:s.78A(5)(c)[E+W]
- G52 UK_ukpga_1990_43 repealed->repealed (1): UK_ukpga_1990_43:s.78A(5)(c)[S]
- G53 UK_ukpga_1990_43 repealed_saved->repealed_saved (1): UK_ukpga_1990_43:s.78L(4)(b)[E+W]
- G54 UK_ukpga_1995_21 in_force->in_force (160): UK_ukpga_1995_21:s.255A
- G55 UK_ukpga_1995_21 in_force->in_force (6): UK_ukpga_1995_21:s.255B
- G57 UK_ukpga_1995_21 in_force->in_force (1): UK_ukpga_1995_21:s.136A
- G58 UK_ukpga_1995_21 in_force->in_force (1): UK_ukpga_1995_21:s.306(2A)(c)
- G65 UK_ukpga_1995_25 in_force->in_force (1): UK_ukpga_1995_25:s.108(15)[S]
- G66 UK_ukpga_1995_25 in_force->in_force (1): UK_ukpga_1995_25:s.114(2)(a)(v)
- G68 UK_ukpga_1995_25 in_force->in_force (1): UK_ukpga_1995_25:s.5(5)(i)n1
- G80 UK_ukpga_2006_16 in_force->in_force (9): UK_ukpga_2006_16:s.89A(1)
- G83 UK_ukpga_2007_19 in_force->in_force (1): UK_ukpga_2007_19:s.25
- G88 UK_ukpga_2021_30 in_force->in_force (1): UK_ukpga_2021_30:s.82(2)

## A staged removal: partly in force, then repealed (staged-removal-in-part-then-repealed)

143 rows, 6 groups

- G10 UK_ukpga_1961_34 repealed->repealed (59): UK_ukpga_1961_34:s.1
- G11 UK_ukpga_1961_34 repealed->repealed (9): UK_ukpga_1961_34:s.18(1)
- G16 UK_ukpga_1963_41 repealed_saved->repealed_saved (68): UK_ukpga_1963_41:s.10
- G17 UK_ukpga_1963_41 repealed_saved->repealed_saved (2): UK_ukpga_1963_41:s.4(4)
- G56 UK_ukpga_1995_21 repealed->repealed (2): UK_ukpga_1995_21:s.117
- G38 UK_ukpga_1990_43 repealed->repealed (3): UK_ukpga_1990_43:s.143

## A commencing law named, or a commencement now dated, by the readers' fixes (own clauses and orders read; a Part reaches its sections; territorial stages)

78 rows, 16 groups

- G9 UK_ukpga_1920_65 in_force->in_force (1): UK_ukpga_1920_65:s.1(6)
- G12 UK_ukpga_1961_34 repealed->repealed (6): UK_ukpga_1961_34:s.1(5)
- G28 UK_ukpga_1990_43 in_force->in_force (14): UK_ukpga_1990_43:s.34(9)(a)[E+W]
- G31 UK_ukpga_1990_43 in_force->in_force (8): UK_ukpga_1990_43:s.34(9)(b)[E+W]
- G37 UK_ukpga_1990_43 in_force->in_force (4): UK_ukpga_1990_43:s.79(1)[E+W]
- G43 UK_ukpga_1990_43 repealed_saved->repealed_saved (2): UK_ukpga_1990_43:s.161(4)
- G44 UK_ukpga_1990_43 repealed->repealed (2): UK_ukpga_1990_43:s.34(2)(a)[S]
- G46 UK_ukpga_1990_43 in_force_partial->in_force (2): UK_ukpga_1990_43:s.78YA(4B)
- G47 UK_ukpga_1990_43 in_force->in_force (2): UK_ukpga_1990_43:s.79(1A)[S]
- G60 UK_ukpga_1995_25 in_force->in_force (16): UK_ukpga_1995_25:s.31(5)
- G61 UK_ukpga_1995_25 in_force->in_force (4): UK_ukpga_1995_25:s.108(15)[E+W]
- G82 UK_ukpga_2006_16 in_force->in_force (2): UK_ukpga_2006_16:s.43(3)(d)
- G86 UK_ukpga_2021_30 in_force->in_force (1): UK_ukpga_2021_30:s.82
- G87 UK_ukpga_2021_30 in_force->in_force_partial (1): UK_ukpga_2021_30:s.82(1)
- G91 UK_uksi_1995_1802 in_force->in_force (12): UK_uksi_1995_1802:reg.1(3)
- G101 UK_uksi_2016_1154 in_force->in_force (1): UK_uksi_2016_1154:reg.38(2A)

## The Railways Act 2005 orders re-read: HSWA's changes from 2006-04-01 (Commencement reader Decision 5 a)

82 rows, 3 groups

- G18 UK_ukpga_1974_37 in_force->in_force (60): UK_ukpga_1974_37:s.14(1)[E+W+S]
- G21 UK_ukpga_1974_37 in_force->in_force (20): UK_ukpga_1974_37:s.11(1)
- G23 UK_ukpga_1974_37 repealed_saved->repealed_saved (2): UK_ukpga_1974_37:s.14(7)[E+W+S]

## A provision's own history: it starts when made or inserted, and only its own changes version it (RULES; Jason 2026-10-20 c); one changed_by where several laws tie

99 rows, 22 groups

- G3 UK_eudr_2010_63 in_force->in_force (1): UK_eudr_2010_63:art.Article 54
- G4 UK_nisr_2007_31 repealed_saved->repealed_saved (1): UK_nisr_2007_31:reg.8(5D)
- G5 UK_ssi_1999_1 repealed->repealed (2): UK_ssi_1999_1:reg.13
- G26 UK_ukpga_1990_43 in_force->in_force (38): UK_ukpga_1990_43:s.153(1)(aa)n1
- G30 UK_ukpga_1990_43 repealed->in_force (9): UK_ukpga_1990_43:s.153(1)(bb)n1
- G32 UK_ukpga_1990_43 repealed_saved->repealed_saved (7): UK_ukpga_1990_43:s.15(6)(a)
- G39 UK_ukpga_1990_43 repealed_saved->repealed_saved (3): UK_ukpga_1990_43:s.15(6)
- G42 UK_ukpga_1990_43 in_force->in_force (2): UK_ukpga_1990_43:s.153(1)(ss)
- G62 UK_ukpga_1995_25 in_force->in_force (3): UK_ukpga_1995_25:s.41(10A)
- G67 UK_ukpga_1995_25 in_force->in_force (1): UK_ukpga_1995_25:s.41(1B)
- G89 UK_uksi_1992_2792 in_force->in_force (1): UK_uksi_1992_2792:reg.6(1A)
- G90 UK_uksi_1993_3138 in_force->in_force (2): UK_uksi_1993_3138:reg.46(2)(b)
- G92 UK_uksi_1998_2514 in_force->in_force (1): UK_uksi_1998_2514:reg.3(4A)
- G93 UK_uksi_2002_761 in_force->in_force (1): UK_uksi_2002_761:reg.28(2)
- G94 UK_uksi_2003_3049 in_force->in_force (8): UK_uksi_2003_3049:reg.6A
- G96 UK_uksi_2008_1597 in_force->in_force (1): UK_uksi_2008_1597:reg.3[NI]
- G98 UK_uksi_2009_995 in_force->in_force (7): UK_uksi_2009_995:reg.10(1)
- G99 UK_uksi_2009_995 repealed->repealed (1): UK_uksi_2009_995:reg.10(3)(b)(iii)
- G100 UK_uksi_2016_1154 in_force->in_force (1): UK_uksi_2016_1154:reg.3
- G102 UK_uksi_2022_96 in_force->in_force (1): UK_uksi_2022_96:reg.5(2)(e)
- G103 UK_wsi_2009_995 in_force->in_force (7): UK_wsi_2009_995:reg.10(1)
- G104 UK_wsi_2009_995 repealed->repealed (1): UK_wsi_2009_995:reg.10(3)(b)(iii)

## A whole law revoked provision by provision (Label fold Decision 3 a), or revoked by a named law

17 rows, 2 groups

- G95 UK_uksi_2004_1633 in_force->repealed (3): UK_uksi_2004_1633:reg.11(2)(a)
- G97 UK_uksi_2008_2337 in_force->repealed_saved (14): UK_uksi_2008_2337:reg.1(1)

## Right on the law's text: SI 2011/988 repeals only s.75(2)(b), (c) and (10)-(12)

18 rows, 2 groups

- G27 UK_ukpga_1990_43 repealed->in_force (17): UK_ukpga_1990_43:s.75(1)[E+W]
- G50 UK_ukpga_1990_43 repealed->repealed_saved (1): UK_ukpga_1990_43:s.75(8A)n1[E+W]

## The Clean Neighbourhoods and Environment Act 2005: prospective until its first order, then England and Wales by their own orders (Commencement reader orders and territory)

413 rows, 10 groups

- G69 UK_ukpga_2005_16 in_force_partial->in_force_partial (210): UK_ukpga_2005_16:pt.6.ch.1
- G70 UK_ukpga_2005_16 in_force->in_force (133): UK_ukpga_2005_16:s.10
- G71 UK_ukpga_2005_16 in_force->in_force (33): UK_ukpga_2005_16:s.100
- G72 UK_ukpga_2005_16 in_force->in_force (15): UK_ukpga_2005_16:s.11(1)
- G73 UK_ukpga_2005_16 repealed_saved->repealed_saved (10): UK_ukpga_2005_16:s.21
- G74 UK_ukpga_2005_16 repealed_saved->repealed_saved (7): UK_ukpga_2005_16:s.2
- G75 UK_ukpga_2005_16 in_force_partial->in_force (2): UK_ukpga_2005_16:s.13
- G76 UK_ukpga_2005_16 in_force_partial->in_force (1): UK_ukpga_2005_16:pt.7
- G78 UK_ukpga_2005_16 in_force->in_force (1): UK_ukpga_2005_16:s.19(6)
- G79 UK_ukpga_2005_16 in_force_partial->in_force (1): UK_ukpga_2005_16:s.30

## An undated duplicate insertion leaves in_force_from unknown (gap undated_change, honest)

3 rows, 1 groups

- G64 UK_ukpga_1995_25 in_force->in_force (3): UK_ukpga_1995_25:s.85(4A)

## PARKED (Commencement reader): SI 1991/96 reg.2's limit on its last item (s.162(1) 'in so far as it relates to') read on every item, so EPA ss.88(9)(b), 89(4), 90(1),(2),(7), 96(2),(3) are partly in force from 1991-01-14 where they are wholly in force

21 rows, 4 groups

- G29 UK_ukpga_1990_43 in_force_partial->in_force_partial (11): UK_ukpga_1990_43:s.88(9)[E+W]
- G34 UK_ukpga_1990_43 in_force->in_force_partial (5): UK_ukpga_1990_43:s.89(4)
- G41 UK_ukpga_1990_43 in_force_partial->in_force_partial (3): UK_ukpga_1990_43:s.90(1)
- G48 UK_ukpga_1990_43 in_force->in_force_partial (2): UK_ukpga_1990_43:s.88(9)(b)[E+W]

## PARKED (Sources): the Water Industry (Scotland) Act 2002's commencement orders are not held, so its EPA changes are undated (s.53(5)) or dated from its enactment

5 rows, 1 groups

- G33 UK_ukpga_1990_43 in_force->in_force (5): UK_ukpga_1990_43:s.53(5)

## PARKED (Label fold): a repeal commenced only in partial stages, none full, folds as removed from its first stage

6 rows, 3 groups

- G45 UK_ukpga_1990_43 repealed_saved->repealed_saved (2): UK_ukpga_1990_43:s.75(3)[E+W]
- G63 UK_ukpga_1995_25 repealed_saved->repealed_saved (3): UK_ukpga_1995_25:s.67(2)
- G77 UK_ukpga_2005_16 repealed->repealed (1): UK_ukpga_2005_16:s.1

## PARKED (Label fold): a section whose subsections commence apart takes no partial period from a partly commenced subsection (NERC 2006 s.61; EA 2021 s.69, whose subsections (3) and (5) are in force by the revised text, J6)

12 rows, 2 groups

- G81 UK_ukpga_2006_16 in_force->in_force (5): UK_ukpga_2006_16:s.61
- G85 UK_ukpga_2021_30 in_force_partial->in_force (7): UK_ukpga_2021_30:s.69

