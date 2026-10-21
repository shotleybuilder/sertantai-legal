# CV-01 golden set — expected label periods, one map per provision.
#
# Source: data/reports/change-vocabulary/golden/ (golden-set.md, expected-batch{1,2,3}.md),
# signed off by Gemini 2026-10-21 (data/code-reviews/2026-10-21-cv-01-golden-set-gemini.md;
# its AMEND lines applied), normalised to D1. 25 golden provisions plus SI 2010/404
# reg.14(1) and reg.14(3) from the CV-02 slice = 27. The four slice provisions
# (2010/404 reg.14, reg.14(1), reg.14(3); 2000/1043 reg.11(3)) are copied verbatim
# from test/sertantai_legal/scraper/change_vocabulary/slice_test.exs.
#
# Normalisation rules (override the drafts where they differ):
#  1. D1: in_force_from = the date the provision's CURRENT TEXT took effect (its start,
#     or the latest text change — substitution/insertion/renumbering — on the provision
#     itself, or a provision-level change on an ancestor, in force in that period).
#     changed_by = the laws that made that text version ([] for the law's original
#     text; the inserting law for an inserted provision). Parallel same-day changes
#     (E/W) → all of them, sorted (C5).
#  2. A repeal for only part of the territory opens a new period with the narrower
#     territory but does NOT change in_force_from or changed_by.
#  3. Repealed everywhere → :repealed, territory "nowhere", in_force_from nil,
#     changed_by = the repealing law(s).
#  4. A change to a child provision never opens a period on the parent (C9).
#  5. The label starts at the provision's start (coming into force); no made-to-
#     coming-into-force :prospective row — except a never-commenced provision
#     (:prospective from Royal Assent) and an Act provision prospective until a later
#     commencement (keeps the draft's prospective row). `start` = first valid_from.
#  6. Status atoms: :in_force, :in_force_partial, :prospective, :repealed,
#     :repealed_saved. C1/C12: a one-territory repeal with text retained stays
#     :in_force with narrowed territory.
#  7. Unknown commencement date (UNDECIDABLE) → in_force_from nil, undecidable: true;
#     the label then begins at Royal Assent as :in_force with in_force_from nil (C10).
#  8. Gemini AMENDs applied: 2000/1043 reg.11(3) changed_by both laws; 2017/544
#     reg.1(1) renumbering period in_force_from 2024-11-04; 2012/3038 reg.1A territory
#     NI from its application clause (C6); 1974/37 s.78 per C11 (extent E+W+S,
#     repealed "nowhere" from 2006-10-01).
#  9. Whole-law "continued" / "modified" / "Commencement Order" effects are ignored;
#     superseded by the D1 correction below: a commencement IS a version.
# 10. A period opens only when a field changes; a change that alters no field
#     (further commencement while still partial, partial expiry of a prospective
#     provision) is folded into the running period.
#
# `extent` is the provision's legal extent (legal_articles.extent_code), except where
# C6 / C11 set it. `territory` "nowhere" = in force nowhere (C2); nil = unknown.
#
# Corrected 2026-10-21 to D1 as written (label_projection.ex, Jason 2026-10-13):
# a commencement is a version (in_force_from its date, changed_by its law, []
# for the law itself); in_force_from / changed_by are empty while prospective
# or partly in force. Coronavirus Act s.78's 2024 expiry is the Act's own
# (s.89): changed_by [].
# And to D3 (label_projection.ex): a repeal carrying savings is :repealed_saved,
# kept where it was in force — HSWA 1974 s.78 from 2006-10-01 (E+W+S).

[
  %{
    id: "reg.14",
    start: ~D[2010-04-01],
    case: "England-only omission (RetainText) by an (England) SI; Welsh heading change after",
    law: "UK_uksi_2010_404",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2010-04-01],
        in_force_from: ~D[2010-04-01],
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2023-10-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2023-10-01],
        in_force_from: ~D[2010-04-01],
        changed_by: [],
        territory: "W",
        valid_to: ~D[2026-07-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2026-07-01],
        in_force_from: ~D[2026-07-01],
        changed_by: ["UK_wsi_2025_1320"],
        territory: "W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "reg.14(1)",
    start: ~D[2010-04-01],
    case: "child of reg.14: the omission reaches it; its own Welsh word changes version it",
    law: "UK_uksi_2010_404",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2010-04-01],
        in_force_from: ~D[2010-04-01],
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2023-10-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2023-10-01],
        in_force_from: ~D[2010-04-01],
        changed_by: [],
        territory: "W",
        valid_to: ~D[2026-07-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2026-07-01],
        in_force_from: ~D[2026-07-01],
        changed_by: ["UK_wsi_2025_1320"],
        territory: "W",
        valid_to: ~D[2026-07-20]
      },
      %{
        status: :in_force,
        valid_from: ~D[2026-07-20],
        in_force_from: ~D[2026-07-20],
        changed_by: ["UK_wsi_2026_112"],
        territory: "W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "reg.14(3)",
    start: ~D[2010-04-01],
    case: "child of reg.14: only the England-only omission",
    law: "UK_uksi_2010_404",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2010-04-01],
        in_force_from: ~D[2010-04-01],
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2023-10-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2023-10-01],
        in_force_from: ~D[2010-04-01],
        changed_by: [],
        territory: "W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "s.1(4)(a)",
    start: ~D[1999-07-01],
    case:
      "inserted 1999; words omitted 2013 (same as affected); Scottish whole-Act repeal (RetainText) + same-day word omission 2019",
    law: "UK_ukpga_1967_10",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1999-07-01],
        in_force_from: ~D[1999-07-01],
        changed_by: ["UK_uksi_1999_1747"],
        territory: "E+W+S",
        valid_to: ~D[2013-04-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2013-04-01],
        in_force_from: ~D[2013-04-01],
        changed_by: ["UK_wsi_2013_755"],
        territory: "E+W+S",
        valid_to: ~D[2019-04-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2019-04-01],
        in_force_from: ~D[2019-04-01],
        changed_by: ["UK_uksi_2019_734"],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.1(1A)",
    start: ~D[2013-04-01],
    case:
      "inserted by a Welsh SI into a GB Act (single GB text); Scottish whole-Act repeal (RetainText) 2019",
    law: "UK_ukpga_1967_10",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2013-04-01],
        in_force_from: ~D[2013-04-01],
        changed_by: ["UK_wsi_2013_755"],
        territory: "E+W+S",
        valid_to: ~D[2019-04-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2019-04-01],
        in_force_from: ~D[2013-04-01],
        changed_by: ["UK_wsi_2013_755"],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.78",
    start: ~D[2020-03-25],
    case:
      "staged territorial expiries: E 2021-12-09, W 2022-03-25 (sunset), NI lapse after last continuation 2024-03-25",
    law: "UK_ukpga_2020_7",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2020-03-25],
        in_force_from: ~D[2020-03-25],
        changed_by: [],
        territory: "E+W+NI",
        valid_to: ~D[2021-12-09]
      },
      %{
        status: :in_force,
        valid_from: ~D[2021-12-09],
        in_force_from: ~D[2020-03-25],
        changed_by: [],
        territory: "W+NI",
        valid_to: ~D[2022-03-25]
      },
      %{
        status: :in_force,
        valid_from: ~D[2022-03-25],
        in_force_from: ~D[2020-03-25],
        changed_by: [],
        territory: "NI",
        valid_to: ~D[2024-03-25]
      },
      %{
        status: :repealed,
        valid_from: ~D[2024-03-25],
        in_force_from: nil,
        changed_by: [],
        territory: "nowhere",
        valid_to: nil
      }
    ],
    extent: "E+W+NI",
    undecidable: false
  },
  %{
    id: "reg.72(2)(b)",
    start: ~D[2016-12-08],
    case:
      "GB omission (RetainText Extent=E+W+S) leaves NI; same-day NI word omission on its text",
    law: "UK_uksi_2016_1105",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2016-12-08],
        in_force_from: ~D[2016-12-08],
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2020-12-31],
        changed_by: ["UK_uksi_2020_678"],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "s.78(4BA)",
    start: ~D[2015-09-06],
    case:
      "inserted by a Welsh Act inside an older Addition; staged commencement 2015 (partial) / 2017 (full)",
    law: "UK_ukpga_1990_8",
    periods: [
      %{
        status: :in_force_partial,
        valid_from: ~D[2015-09-06],
        in_force_from: nil,
        changed_by: [],
        territory: "W",
        valid_to: ~D[2017-05-05]
      },
      %{
        status: :in_force,
        valid_from: ~D[2017-05-05],
        in_force_from: ~D[2017-05-05],
        changed_by: ["UK_wsi_2017_546"],
        territory: "W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "reg.29",
    start: ~D[2010-10-01],
    case: "England-only omission with no Repeal markup; later whole-law England revocation",
    law: "UK_uksi_2010_2215",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2010-10-01],
        in_force_from: ~D[2010-10-01],
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2023-10-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2023-10-01],
        in_force_from: ~D[2010-10-01],
        changed_by: [],
        territory: "W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "s.284(3)(a)",
    start: ~D[1990-08-24],
    case:
      "territory-split words changes: E-only words repeal 2009 (RetainText), Welsh staged substitution 2015/2016",
    law: "UK_ukpga_1990_8",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1990-08-24],
        in_force_from: ~D[1990-08-24],
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2009-04-06]
      },
      %{
        status: :in_force,
        valid_from: ~D[2009-04-06],
        in_force_from: ~D[2009-04-06],
        changed_by: ["UK_ukpga_2008_29"],
        territory: "E+W",
        valid_to: ~D[2015-09-06]
      },
      %{
        status: :in_force,
        valid_from: ~D[2015-09-06],
        in_force_from: ~D[2015-09-06],
        changed_by: ["UK_anaw_2015_4"],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "s.73",
    start: ~D[2006-03-30],
    case: "prospective, commenced 2007, repealed everywhere (text removed) 2012",
    law: "UK_ukpga_2006_16",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[2006-03-30],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S",
        valid_to: ~D[2007-04-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2007-04-01],
        in_force_from: ~D[2007-04-01],
        changed_by: ["UK_uksi_2007_816"],
        territory: "E+W+S",
        valid_to: ~D[2012-07-02]
      },
      %{
        status: :repealed,
        valid_from: ~D[2012-07-02],
        in_force_from: nil,
        changed_by: ["UK_uksi_2012_1658"],
        territory: "nowhere",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.3(5)",
    start: ~D[1989-07-06],
    case:
      "UNDECIDABLE commencement (note only, SI 1991/1618 not held); Scottish whole-Act repeal (RetainText) 2025; S child changes 2014 ignored",
    law: "UK_ukpga_1989_14",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1989-07-06],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S",
        valid_to: ~D[2025-11-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2025-11-01],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: true
  },
  %{
    id: "s.101",
    start: ~D[1974-07-31],
    case: "UNDECIDABLE commencement (order not held, C10); Scottish repeal 2014 with no markup",
    law: "UK_ukpga_1974_40",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1974-07-31],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2014-06-30]
      },
      %{
        status: :in_force,
        valid_from: ~D[2014-06-30],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: true
  },
  %{
    id: "s.78",
    start: ~D[1974-07-31],
    case:
      "UNDECIDABLE commencement; C11 extent E+W+S; E+W and S repeals same day 2006-10-01 → nowhere; child (7)(c) repeal ignored",
    law: "UK_ukpga_1974_37",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1974-07-31],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S",
        valid_to: ~D[2006-10-01]
      },
      %{
        status: :repealed_saved,
        valid_from: ~D[2006-10-01],
        in_force_from: nil,
        changed_by: ["UK_ssi_2006_475", "UK_uksi_2005_1541"],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: true
  },
  %{
    id: "s.18",
    start: ~D[1993-05-27],
    case: "E+W repeal (RetainText Extent=E+W) 2010, then S range repeal (no markup) 2018 → NI",
    law: "UK_ukpga_1993_12",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[1993-05-27],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[1993-08-27]
      },
      %{
        status: :in_force,
        valid_from: ~D[1993-08-27],
        in_force_from: ~D[1993-08-27],
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2010-04-06]
      },
      %{
        status: :in_force,
        valid_from: ~D[2010-04-06],
        in_force_from: ~D[1993-08-27],
        changed_by: [],
        territory: "S+NI",
        valid_to: ~D[2018-09-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2018-09-01],
        in_force_from: ~D[1993-08-27],
        changed_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "reg.11(3)",
    start: ~D[2000-05-04],
    case:
      "substituted the same day for E (marked up) and for W (feed only) — one version, two laws (C5)",
    law: "UK_uksi_2000_1043",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2000-05-04],
        in_force_from: ~D[2000-05-04],
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2005-07-16]
      },
      %{
        status: :in_force,
        valid_from: ~D[2005-07-16],
        in_force_from: ~D[2005-07-16],
        changed_by: ["UK_uksi_2005_894", "UK_wsi_2005_1806"],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "s.4(6)",
    start: ~D[1988-11-15],
    case: "silent-feed repeal; RetainText + SOCPA s.179 extent make it E+W only → S",
    law: "UK_ukpga_1988_52",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[1988-11-15],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S",
        valid_to: ~D[1989-05-15]
      },
      %{
        status: :in_force,
        valid_from: ~D[1989-05-15],
        in_force_from: ~D[1989-05-15],
        changed_by: [],
        territory: "E+W+S",
        valid_to: ~D[2006-01-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2006-01-01],
        in_force_from: ~D[1989-05-15],
        changed_by: [],
        territory: "S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.8",
    start: ~D[2020-03-25],
    case:
      "never commenced; expired in part 2021-07-17 (RetainText) — still prospective everywhere",
    law: "UK_ukpga_2020_7",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[2020-03-25],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "art.Article 28(3)",
    start: ~D[2019-12-14],
    case:
      "EU retained law omitted for GB on IP completion day; in force in NI under the Windsor Framework (C8)",
    law: "UK_eur_2016_2031",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2019-12-14],
        in_force_from: ~D[2019-12-14],
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2019-12-14],
        changed_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "reg.1(1)",
    start: ~D[2017-05-05],
    case: "Welsh SI (territory W, not legal extent E+W); renumbered reg.1 → reg.1(1) 2024 (C4)",
    law: "UK_uksi_2017_544",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2017-05-05],
        in_force_from: ~D[2017-05-05],
        changed_by: [],
        territory: "W",
        valid_to: ~D[2024-11-04]
      },
      %{
        status: :in_force,
        valid_from: ~D[2024-11-04],
        in_force_from: ~D[2024-11-04],
        changed_by: ["UK_wsi_2024_924"],
        territory: "W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "s.8",
    start: ~D[2021-11-09],
    case: "prospective at Royal Assent, commenced by order 2022-01-24",
    law: "UK_ukpga_2021_30",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[2021-11-09],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2022-01-24]
      },
      %{
        status: :in_force,
        valid_from: ~D[2022-01-24],
        in_force_from: ~D[2022-01-24],
        changed_by: ["UK_uksi_2022_48"],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "s.6",
    start: ~D[2018-06-26],
    case:
      "staged commencement (s.6(7) 2018, specified purposes 2020-01-30, fully 2020-12-31); heading substituted 2024",
    law: "UK_ukpga_2018_16",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[2018-06-26],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2018-07-04]
      },
      %{
        status: :in_force_partial,
        valid_from: ~D[2018-07-04],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2020-12-31],
        changed_by: ["UK_uksi_2020_1622"],
        territory: "E+W+S+NI",
        valid_to: ~D[2024-01-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2024-01-01],
        in_force_from: ~D[2024-01-01],
        changed_by: ["UK_ukpga_2023_28"],
        territory: "E+W+S+NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "reg.14(1)[E+W+S]",
    start: ~D[2009-12-29],
    case: "GB territorial version created 2020-12-31; carries the shared pre-split history (C3)",
    law: "UK_uksi_2008_1597",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2009-12-29],
        in_force_from: ~D[2009-12-29],
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2011-04-22]
      },
      %{
        status: :in_force,
        valid_from: ~D[2011-04-22],
        in_force_from: ~D[2011-04-22],
        changed_by: ["UK_uksi_2011_1043"],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2020-12-31],
        changed_by: ["UK_uksi_2019_696"],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "reg.14(1)[NI]",
    start: ~D[2009-12-29],
    case:
      "NI territorial version (C3 shared history); scheduled NI revocation with savings 2027-01-20",
    law: "UK_uksi_2008_1597",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2009-12-29],
        in_force_from: ~D[2009-12-29],
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2011-04-22]
      },
      %{
        status: :in_force,
        valid_from: ~D[2011-04-22],
        in_force_from: ~D[2011-04-22],
        changed_by: ["UK_uksi_2011_1043"],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2020-12-31],
        changed_by: ["UK_uksi_2020_1112"],
        territory: "NI",
        valid_to: ~D[2027-01-20]
      },
      %{
        status: :repealed_saved,
        valid_from: ~D[2027-01-20],
        in_force_from: nil,
        changed_by: ["UK_uksi_2026_867"],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "NI",
    undecidable: false
  },
  %{
    id: "reg.36[E]",
    start: ~D[2010-10-01],
    case: "England version from a 2015 substitution marked Extent=E; original E+W history before",
    law: "UK_uksi_2010_2214",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2010-10-01],
        in_force_from: ~D[2010-10-01],
        changed_by: [],
        territory: "E+W",
        valid_to: ~D[2015-10-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2015-10-01],
        in_force_from: ~D[2015-10-01],
        changed_by: ["UK_uksi_2015_767"],
        territory: "E",
        valid_to: nil
      }
    ],
    extent: "E",
    undecidable: false
  },
  %{
    id: "reg.1A",
    start: ~D[2020-12-31],
    case:
      "inserted 2020-12-31; own application clause → NI (C6); purpose-limited revocation (RetainText) 2021 → partial (C7)",
    law: "UK_uksi_2012_3038",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2020-12-31],
        changed_by: ["UK_uksi_2020_1369"],
        territory: "NI",
        valid_to: ~D[2021-05-01]
      },
      %{
        status: :in_force_partial,
        valid_from: ~D[2021-05-01],
        in_force_from: nil,
        changed_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "NI",
    undecidable: false
  },
  %{
    id: "s.138(2)(a)",
    start: ~D[2022-04-28],
    case: "never commenced: prospective since Royal Assent",
    law: "UK_ukpga_2022_30",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[2022-04-28],
        in_force_from: nil,
        changed_by: [],
        territory: "E+W+S+NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  }
]
