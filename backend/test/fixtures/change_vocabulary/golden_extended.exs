# CV-S09 extended golden set — 23 provisions, the same shape and normalisation
# rules as golden.exs (read those there).
#
# Drafted blind from the sources (expected-batch{4,5,6,7}.md), reviewed by Gemini
# (data/code-reviews/2026-10-30-cv-s09-golden-gemini.md) and ruled by Jason: C13 a
# commencement for one territory is in force there, each a version (D1); C14
# inserted text takes the inserting law's narrower extent; D3 repealed_saved when
# the feed or the law names a saving; rule 9 covers a modification drafted as a
# substitution. Directive 90/269 Art 8b(1) held out (directives: Windsor Framework).
#
# Held apart from golden.exs (Jason 2026-10-30): grown in the middle of the
# CV-S01–S09 workflow, it judged the later steps by provisions the earlier steps
# never saw. It gates the workflow's next pass, from step 1
# (`mix lat.vocabulary --golden --extended`).
#
# CV-S09 batch 1: SI 1977/500 reg.4A(1)(c) corrected to E+W+S (its inserting SI
# 1992/2051 is a GB instrument, C14); 2007/19 s.2(1)(d), CROW s.1A(b) and s.1(6B)
# moved to `commenced_by`.

[
  %{
    id: "reg.3(3)",
    start: ~D[1999-12-29],
    case: "words repositioned (C4 renumbering opens a period), then a substitution (CV-S09)",
    law: "UK_uksi_1999_3242",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1999-12-29],
        in_force_from: ~D[1999-12-29],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[2003-10-27]
      },
      %{
        status: :in_force,
        valid_from: ~D[2003-10-27],
        in_force_from: ~D[2003-10-27],
        changed_by: ["UK_uksi_2003_2457"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[2015-10-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2015-10-01],
        in_force_from: ~D[2015-10-01],
        changed_by: ["UK_uksi_2015_1637"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.76",
    start: ~D[1963-07-31],
    case:
      "commenced through its parts, never fully (covered-market carve-out); its children repealed 1977 (C9) and 1991 (CV-S09)",
    law: "UK_ukpga_1963_41",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[1963-07-31],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1964-05-01]
      },
      %{
        status: :in_force_partial,
        valid_from: ~D[1964-05-01],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1991-01-01]
      },
      %{
        status: :repealed,
        valid_from: ~D[1991-01-01],
        in_force_from: nil,
        changed_by: ["UK_ukpga_1990_43"],
        commenced_by: [],
        territory: "nowhere",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.91",
    start: ~D[1963-07-31],
    case:
      "commenced through its parts, never fully (covered-market carve-out; SI 1989/2312 commences s.91(4) only in part) (CV-S09)",
    law: "UK_ukpga_1963_41",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[1963-07-31],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1964-02-18]
      },
      %{
        status: :in_force_partial,
        valid_from: ~D[1964-02-18],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.1A(b)",
    start: ~D[2004-09-19],
    case:
      "inserted; commenced for England then Wales: in force where commenced, each a version (C13) (CV-S09)",
    law: "UK_ukpga_1984_3",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2004-09-19],
        in_force_from: ~D[2004-09-19],
        changed_by: ["UK_ukpga_2000_37"],
        commenced_by: ["UK_uksi_2004_2173"],
        territory: "E",
        valid_to: ~D[2005-05-28]
      },
      %{
        status: :in_force,
        valid_from: ~D[2005-05-28],
        in_force_from: ~D[2005-05-28],
        changed_by: ["UK_ukpga_2000_37"],
        commenced_by: ["UK_wsi_2005_423"],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "s.1(6B)",
    start: ~D[2004-09-19],
    case: "inserted; commenced for England then Wales (C13) (CV-S09)",
    law: "UK_ukpga_1984_3",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2004-09-19],
        in_force_from: ~D[2004-09-19],
        changed_by: ["UK_ukpga_2000_37"],
        commenced_by: ["UK_uksi_2004_2173"],
        territory: "E",
        valid_to: ~D[2005-05-28]
      },
      %{
        status: :in_force,
        valid_from: ~D[2005-05-28],
        in_force_from: ~D[2005-05-28],
        changed_by: ["UK_ukpga_2000_37"],
        commenced_by: ["UK_wsi_2005_423"],
        territory: "E+W",
        valid_to: nil
      }
    ],
    extent: "E+W",
    undecidable: false
  },
  %{
    id: "reg.12(2)",
    start: ~D[1999-12-29],
    case: "words revoked the same day by an E+W SI and an SSI (C5) (CV-S09)",
    law: "UK_uksi_1999_3242",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1999-12-29],
        in_force_from: ~D[1999-12-29],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[2006-10-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2006-10-01],
        in_force_from: ~D[2006-10-01],
        changed_by: ["UK_ssi_2006_457", "UK_uksi_2005_1541"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "reg.15(5)(b)",
    start: ~D[2017-04-06],
    case:
      "inserted by a GB-only SI (C14); a same-day inserter revoked before it took effect (no C5) (CV-S09)",
    law: "UK_uksi_2013_1471",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2017-04-06],
        in_force_from: ~D[2017-04-06],
        changed_by: ["UK_uksi_2017_304"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "art.Article 2(17)",
    start: ~D[2008-12-16],
    case:
      "EU retained law, start undated (C10); GB substitution on IP completion day (C8: NI keeps the EU text) (CV-S09)",
    law: "UK_eur_2008_1272",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2008-12-16],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2020-12-31],
        changed_by: ["UK_uksi_2019_720", "UK_uksi_2020_1567"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: true
  },
  %{
    id: "reg.5",
    start: ~D[2008-10-01],
    case: "a GB law revoked whole with savings (D3) (CV-S09)",
    law: "UK_uksi_2008_2337",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2008-10-01],
        in_force_from: ~D[2008-10-01],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[2009-04-06]
      },
      %{
        status: :repealed_saved,
        valid_from: ~D[2009-04-06],
        in_force_from: nil,
        changed_by: ["UK_uksi_2009_716"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "reg.19(1)(b)(ii)[NI]",
    start: ~D[2009-12-29],
    case:
      "NI territorial version, text unchanged at the split (C3); NI revocation with savings 2027 (CV-S09)",
    law: "UK_uksi_2008_1597",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2009-12-29],
        in_force_from: ~D[2009-12-29],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2009-12-29],
        changed_by: [],
        commenced_by: [],
        territory: "NI",
        valid_to: ~D[2027-01-20]
      },
      %{
        status: :repealed_saved,
        valid_from: ~D[2027-01-20],
        in_force_from: nil,
        changed_by: ["UK_uksi_2026_867"],
        commenced_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "NI",
    undecidable: false
  },
  %{
    id: "reg.3(6)",
    start: ~D[2007-03-01],
    case: "NI law revoked with savings, text retained (D3) (CV-S09)",
    law: "UK_nisr_2007_31",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2007-03-01],
        in_force_from: ~D[2007-03-01],
        changed_by: [],
        commenced_by: [],
        territory: "NI",
        valid_to: ~D[2012-05-28]
      },
      %{
        status: :repealed_saved,
        valid_from: ~D[2012-05-28],
        in_force_from: nil,
        changed_by: ["UK_nisr_2012_179"],
        commenced_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "NI",
    undecidable: false
  },
  %{
    id: "art.Article 140",
    start: ~D[2006-12-18],
    case:
      "EU retained law, start undated (C10); omitted for GB on IP completion day, in force in NI (C8) (CV-S09)",
    law: "UK_eur_2006_1907",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2006-12-18],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: true
  },
  %{
    id: "reg.11(9)",
    start: ~D[1997-07-01],
    case: "NI law revoked by a range with savings (D3: the feed names a saving) (CV-S09)",
    law: "UK_nisr_1997_248",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1997-07-01],
        in_force_from: ~D[1997-07-01],
        changed_by: [],
        commenced_by: [],
        territory: "NI",
        valid_to: ~D[2006-08-01]
      },
      %{
        status: :repealed_saved,
        valid_from: ~D[2006-08-01],
        in_force_from: nil,
        changed_by: ["UK_nisr_2006_173"],
        commenced_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "NI",
    undecidable: false
  },
  %{
    id: "reg.7(2)",
    start: ~D[1989-04-20],
    case:
      "ancestor substituted, dated by the amending law where the feed has no date; application clause excludes NI (C6) (CV-S09)",
    law: "UK_uksi_1989_462",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1989-04-20],
        in_force_from: ~D[1989-04-20],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1990-01-29]
      },
      %{
        status: :in_force,
        valid_from: ~D[1990-01-29],
        in_force_from: ~D[1990-01-29],
        changed_by: ["UK_uksi_1989_2367"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: nil,
    undecidable: false
  },
  %{
    id: "s.2(1)(d)",
    start: ~D[2007-07-26],
    case: "prospective; commenced for E+W+S then NI (C13) (CV-S09)",
    law: "UK_ukpga_2007_19",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[2007-07-26],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2011-09-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2011-09-01],
        in_force_from: ~D[2011-09-01],
        changed_by: [],
        commenced_by: ["UK_uksi_2011_1867"],
        territory: "E+W+S",
        valid_to: ~D[2012-09-03]
      },
      %{
        status: :in_force,
        valid_from: ~D[2012-09-03],
        in_force_from: ~D[2012-09-03],
        changed_by: [],
        commenced_by: ["UK_nisr_2012_286"],
        territory: "E+W+S+NI",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "reg.19B(5)(b)",
    start: ~D[2011-10-24],
    case: "inserted; a later heading change on its regulation never reaches it (CV-S09)",
    law: "UK_uksi_2009_1348",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2011-10-24],
        in_force_from: ~D[2011-10-24],
        changed_by: ["UK_uksi_2011_1885"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "reg.4A(1)(c)",
    start: ~D[1993-01-01],
    case: "inserted with its regulation; words inserted later (CV-S09)",
    law: "UK_uksi_1977_500",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1993-01-01],
        in_force_from: ~D[1993-01-01],
        changed_by: ["UK_uksi_1992_2051"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[2014-04-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[2014-04-01],
        in_force_from: ~D[2014-04-01],
        changed_by: ["UK_uksi_2014_469"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "reg.8(2)",
    start: ~D[1982-07-01],
    case:
      "regulation substituted 2015; a 1993 modification drafted as a substitution is not a version (rule 9) (CV-S09)",
    law: "UK_uksi_1981_917",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1982-07-01],
        in_force_from: ~D[1982-07-01],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[2015-04-06]
      },
      %{
        status: :in_force,
        valid_from: ~D[2015-04-06],
        in_force_from: ~D[2015-04-06],
        changed_by: ["UK_uksi_2014_3248"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "reg.33",
    start: ~D[2015-04-06],
    case:
      "plain row (random draw); the instrument's application clause: Great Britain (C6) (CV-S09)",
    law: "UK_uksi_2015_51",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2015-04-06],
        in_force_from: ~D[2015-04-06],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: nil
      }
    ],
    extent: "E+W+S+NI",
    undecidable: false
  },
  %{
    id: "s.108(1)(a)",
    start: ~D[1937-07-30],
    case:
      "old Act commenced by its own clause a year after assent; repealed by the 1961 consolidation (CV-S09)",
    law: "UK_ukpga_1937_67",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[1937-07-30],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1938-07-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[1938-07-01],
        in_force_from: ~D[1938-07-01],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1962-04-01]
      },
      %{
        status: :repealed,
        valid_from: ~D[1962-04-01],
        in_force_from: nil,
        changed_by: ["UK_ukpga_1961_34"],
        commenced_by: [],
        territory: "nowhere",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "s.127(3)",
    start: ~D[1961-06-22],
    case:
      "prospective to commencement; words repealed 1975; repealed 1996 (dated by the law, feed undated) (CV-S09)",
    law: "UK_ukpga_1961_34",
    periods: [
      %{
        status: :prospective,
        valid_from: ~D[1961-06-22],
        in_force_from: nil,
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1962-04-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[1962-04-01],
        in_force_from: ~D[1962-04-01],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1975-01-01]
      },
      %{
        status: :in_force,
        valid_from: ~D[1975-01-01],
        in_force_from: ~D[1975-01-01],
        changed_by: ["UK_uksi_1974_1941"],
        commenced_by: [],
        territory: "E+W+S",
        valid_to: ~D[1996-09-02]
      },
      %{
        status: :repealed,
        valid_from: ~D[1996-09-02],
        in_force_from: nil,
        changed_by: ["UK_uksi_1996_1592"],
        commenced_by: [],
        territory: "nowhere",
        valid_to: nil
      }
    ],
    extent: "E+W+S",
    undecidable: false
  },
  %{
    id: "reg.12",
    start: ~D[1975-01-01],
    case: "no stated extent; the Rules apply in Scotland (C6) (CV-S09)",
    law: "UK_uksi_1974_2068",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[1975-01-01],
        in_force_from: ~D[1975-01-01],
        changed_by: [],
        commenced_by: [],
        territory: "S",
        valid_to: nil
      }
    ],
    extent: nil,
    undecidable: false
  },
  %{
    id: "reg.7(5)(b)[NI]",
    start: ~D[2009-12-29],
    case: "NI territorial version split by sibling changes, its text unchanged (C3, C9) (CV-S09)",
    law: "UK_uksi_2008_1597",
    periods: [
      %{
        status: :in_force,
        valid_from: ~D[2009-12-29],
        in_force_from: ~D[2009-12-29],
        changed_by: [],
        commenced_by: [],
        territory: "E+W+S+NI",
        valid_to: ~D[2020-12-31]
      },
      %{
        status: :in_force,
        valid_from: ~D[2020-12-31],
        in_force_from: ~D[2009-12-29],
        changed_by: [],
        commenced_by: [],
        territory: "NI",
        valid_to: ~D[2027-01-20]
      },
      %{
        status: :repealed_saved,
        valid_from: ~D[2027-01-20],
        in_force_from: nil,
        changed_by: ["UK_uksi_2026_867"],
        commenced_by: [],
        territory: "NI",
        valid_to: nil
      }
    ],
    extent: "NI",
    undecidable: false
  }
]
