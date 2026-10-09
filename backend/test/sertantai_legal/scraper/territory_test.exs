defmodule SertantaiLegal.Scraper.TerritoryTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Territory

  describe "from_note/1" do
    test "reads the territory a note's change applies to" do
      assert Territory.from_note(
               "Regulations revoked (S.) (1.11.2025) by The Environmental Authorisations (Scotland) Amendment Regulations 2025"
             ) == "S"

      assert Territory.from_note("Regulations revoked (E.W.) (6.4.2012) by S.I. 2012/811") ==
               "E+W"

      assert Territory.from_note("Words substituted (E. and W.) (1.4.2010) by x") == "E+W"
      assert Territory.from_note("Reg. 5 revoked (N.I.) (1.1.2000) by S.R. 1999/1") == "NI"
      assert Territory.from_note("Art. 2 revoked (in relation to W.) (1.1.2000) by x") == "W"
      assert Territory.from_note("S. 3 repealed (E.W.S.) (1.1.2000) by x") == "E+W+S"
    end

    test "a territory given as \"for S.\" or \"in relation to W.\" inside the date parenthesis" do
      assert Territory.from_note(
               "Ss. 1-28 repealed (1.4.2015 for S. for the repeal of ss. 1-19, 22-28) by Pollution Prevention and Control Act 1999 (c. 24)"
             ) == "S"

      assert Territory.from_note("Reg. 3 revoked (1.4.2010 in relation to E.W.) by x") == "E+W"
    end

    test "\"except in relation to W.\" is no single territory" do
      assert Territory.from_note(
               "Words in s. 10(1) substituted (1.10.2023 except in relation to W., 6.4.2024 for W.) by Building Safety Act 2022 (c. 30)"
             ) == nil
    end

    test "every clause's territory (LH-06: uksi 1996/972 reg.10A)" do
      assert Territory.from_note(
               "Regulations revoked (E.) (1.10.2005) by S.I. 2005/894, regs. 1, 2 and Regulations revoked (W.) (16.7.2005) by S.I. 2005/1806, reg. 1"
             ) == "E+W"
    end

    test "nil when the note names no territory, or only in the amending instrument's title" do
      assert Territory.from_note(
               "Art. 22 revoked (15.4.2018) by The Regulations 2018 (subject to savings)"
             ) == nil

      assert Territory.from_note(
               "Reg. 5 revoked (1.1.2000) by The Fire (Scotland) Order (S.S.I. 2005/344) (S.)"
             ) == nil

      assert Territory.from_note(nil) == nil
    end
  end

  describe "normalize/1" do
    test "extent attributes in either notation" do
      assert Territory.normalize("E.W.") == "E+W"
      assert Territory.normalize("E.W.S.") == "E+W+S"
      assert Territory.normalize("N.I.") == "NI"
      assert Territory.normalize("S+E+W") == "E+W+S"
      assert Territory.normalize("") == nil
      assert Territory.normalize(nil) == nil
    end
  end

  describe "note_territories/1: one territory per clause (LR-02)" do
    test "clauses separately; none after an except" do
      assert Territory.note_territories(
               "S. 22(3) repealed (E.W.) (12.1.2010) by Marine and Coastal Access Act 2009 (c. 23); and s. 22(3) repealed (S.) (24.2.2011) by Marine (Scotland) Act 2010 (asp 5)"
             ) == ["E+W", "S"]

      assert Territory.note_territories("S. 4 repealed (1.10.2023 except in relation to W.) by X") ==
               []
    end

    test "disjoint?/2" do
      assert Territory.disjoint?("W", "S")
      refute Territory.disjoint?("E+W", "W")
    end
  end

  describe "from_note/1 territories on several dates (LR-02)" do
    test "every \"for X.\" in the note's brackets counts" do
      assert Territory.from_note(
               "S. 104(5A) inserted (1.10.2017 for E., 1.4.2019 for W.) by Water Act 2014 (c. 21)"
             ) ==
               "E+W"

      assert Territory.from_note(
               "Pt. 2A inserted (21.7.2008 for specified purposes, otherwise 6.4.2010 for E. and 26.7.2010 for W.) by Health and Social Care Act 2008 (c. 14)"
             ) == nil

      # a nested ")" doesn't cut the bracket short (1991/56 s.51CF(8))
      assert Territory.from_note(
               "S. 51CF inserted (1.4.2017 for E. for the substitution of s. 51B(6) for specified purposes, 1.10.2017 for E., 1.4.2019 for W.) by Water Act 2014 (c. 21)"
             ) == "E+W"

      # every "(X.)" before the " by " (1996/18 s.50(3)(c)(i))
      assert Territory.from_note(
               "Words inserted (E.) (11.7.2001) and (W.) (1.4.2002) by S.I. 2001/2237 and S.I. 2002/808"
             ) ==
               "E+W"

      assert Territory.from_note(
               "Ss. 202A-202G inserted (6.4.2012 for E.) by Planning Act 2008 (c. 29)"
             ) == "E"
    end

    test "a dated part naming no territory (\"for specified purposes\", \"otherwise\") means everywhere: no territory (1990/9 s.20A, 1990/18 s.3A)" do
      assert Territory.from_note(
               "S. 20A inserted (6.8.2004 for specified purposes, 22.6.2015 for W. so far as not already in force) by Planning and Compulsory Purchase Act 2004 (c. 5)"
             ) == nil

      assert Territory.from_note(
               "S. 3A inserted (1.10.2007 for S. and 1.10.2008 otherwise) by Health Act 2006 (c. 28)"
             ) == nil

      assert Territory.from_note("S. 7 inserted (1.4.2010 for W., 1.4.2011 for E.) by X") == "E+W"
    end

    test "N.I without its final dot (2007/19 s.6(2)(b))" do
      assert Territory.from_note("S. 6(2)(b) substituted (E.W.N.I) (1.4.2013) by S.I. 2013/602") ==
               "E+W+NI"
    end
  end

  describe "from_note/1 spelled-out territories (LR-02, Q1)" do
    test "a change verb followed by \"in relation to\" a named territory" do
      assert Territory.from_note(
               "Regulations disapplied in relation to Scotland (with effect from 1.4.2015) by virtue of Scotland Act 2012 (c. 11); S.I. 2015/638 Regulations disapplied in relation to Wales (with effect from 1.4.2018) by virtue of Wales Act 2014 (c. 29)"
             ) == "W+S"

      assert Territory.from_note("S. 4 repealed in relation to England and Wales (1.4.2010) by X") ==
               "E+W"
    end

    test "a title or a function \"in relation to Wales\" is not a territory" do
      assert Territory.from_note(
               "S. 5 amended (1.7.1999) by The National Assembly for Wales (Transfer of Functions in relation to Wales) Order 1999 (S.I. 1999/672)"
             ) == nil

      assert Territory.from_note(
               "Functions in relation to Wales transferred (1.7.1999) by S.I. 1999/672"
             ) == nil
    end
  end

  describe "set operations on extent codes" do
    test "covers?/2: the repealed territories include every territory of the row" do
      assert Territory.covers?("E+W+S", "E+W")
      assert Territory.covers?("E+W", "E+W")
      refute Territory.covers?("S", "E+W+S")
      # no row extent: the UK
      refute Territory.covers?("S", nil)
      assert Territory.covers?("E+W+S+NI", nil)
    end

    test "subtract/2 gives the live territories in canonical order" do
      assert Territory.subtract("E+W+S", "S") == "E+W"
      assert Territory.subtract(nil, "E+W") == "S+NI"
      assert Territory.subtract("E+W", "E+W") == nil
    end

    test "union/1 of extent codes" do
      assert Territory.union(["S", "W", "E"]) == "E+W+S"
      assert Territory.union([]) == nil
    end
  end
end
