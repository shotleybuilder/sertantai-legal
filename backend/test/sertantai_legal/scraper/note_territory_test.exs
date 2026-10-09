defmodule SertantaiLegal.Scraper.NoteTerritoryTest do
  @moduledoc """
  Reading territory from a legislation.gov.uk F note, as documented in
  `docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md`: a bare "(X.)" is where the
  change applies; a dated "date for X." is where it is in force.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.NoteTerritory

  describe "applies/1: bare \"(X.)\" — where the change applies (= the Extent attribute)" do
    test "after the verb, before \" by \"" do
      assert NoteTerritory.applies("S. 10A(1)(a) repealed (E.W.) (1.4.2010) by S.I. 2010/1") == [
               "E+W"
             ]

      assert NoteTerritory.applies("Words in s. 143(7) inserted (N.I.)(5.11.1993) by 1993 c. 50") ==
               ["NI"]

      assert NoteTerritory.applies("S. 6(2)(b) substituted (E.W.N.I) (1.4.2013) by S.I. 2013/602") ==
               ["E+W+NI"]

      assert NoteTerritory.applies("Words substituted (in relation to E.) by X") == ["E"]
    end

    test "one per change: every bare territory, each clause separately" do
      assert NoteTerritory.applies(
               "Words inserted (E.) (11.7.2001) and (W.) (1.4.2002) by S.I. 2001/2237 and S.I. 2002/808"
             ) ==
               ["E", "W"]

      assert NoteTerritory.applies(
               "S. 22(3) repealed (E.W.) (12.1.2010) by Marine and Coastal Access Act 2009 (c. 23); and s. 22(3) repealed (S.) (24.2.2011) by Marine (Scotland) Act 2010 (asp 5)"
             ) == ["E+W", "S"]
    end

    test "a \"(X.)\" inside the dates bracket is an in-force qualifier, not where it applies (1990/8 s.70B)" do
      note =
        "Ss. 70A, 70B substituted (24.8.2005 (E.) in so far as relates to s. 70A and 6.4.2009 (E.) in so far as relates to s. 70B) for s. 70A by X"

      assert NoteTerritory.applies(note) == []
      assert NoteTerritory.in_force(note) == "E"
    end

    test "spelled out straight after the change" do
      assert NoteTerritory.applies(
               "Regulations disapplied in relation to Scotland (with effect from 1.4.2015) by virtue of Scotland Act 2012 (c. 11); S.I. 2015/638 Regulations disapplied in relation to Wales (with effect from 1.4.2018) by virtue of Wales Act 2014 (c. 29)"
             ) == ["S", "W"]
    end

    test "not a territory: dated qualifiers, citations, titles, functions" do
      assert NoteTerritory.applies(
               "S. 15(1A) inserted (6.4.2012 for E.) by Planning Act 2008 (c. 29)"
             ) == []

      assert NoteTerritory.applies(
               "Words substituted (1.1.2017) by The Regulations 2016 (S.I. 2016/1154) (S.)"
             ) == []

      assert NoteTerritory.applies(
               "S. 5 amended (1.7.1999) by The National Assembly for Wales (Transfer of Functions in relation to Wales) Order 1999 (S.I. 1999/672)"
             ) == []

      assert NoteTerritory.applies(nil) == []
    end
  end

  describe "in_force/1: dated \"date for X.\" — where the change is in force (InForce qualifications)" do
    test "every territory named in the dates bracket" do
      assert NoteTerritory.in_force("S. 15(1A) inserted (6.4.2012 for E.) by Planning Act 2008") ==
               "E"

      assert NoteTerritory.in_force(
               "S. 104(5A) inserted (1.10.2017 for E., 1.4.2019 for W.) by Water Act 2014"
             ) == "E+W"

      assert NoteTerritory.in_force("S. 102 repealed (1.4.2010 for W., 1.4.2011 for E.) by X") ==
               "E+W"

      assert NoteTerritory.in_force(
               "S. 30 repealed (1.4.2015 for S.) by Environmental Protection Act 1990"
             ) == "S"
    end

    test "a nested bracket doesn't cut the dates short (1991/56 s.51CF)" do
      assert NoteTerritory.in_force(
               "S. 51CF inserted (1.4.2017 for E. for the substitution of s. 51B(6) for specified purposes, 1.10.2017 for E., 1.4.2019 for W.) by Water Act 2014"
             ) == "E+W"
    end

    test "purposes qualifiers name no territory; \"otherwise prosp.\" keeps the named ones" do
      assert NoteTerritory.in_force(
               "S. 61A(1) repealed (23.6.2009 for E. and otherwise prosp.) by Planning Act 2008"
             ) == "E"

      assert NoteTerritory.in_force(
               "S. 6(3) repealed (18.6.2012 for specified purposes, 5.11.2012 for E.) by X"
             ) == "E"
    end

    test "catch-alls mean everywhere" do
      assert NoteTerritory.in_force(
               "S. 3A inserted (1.10.2007 for S. and 1.10.2008 otherwise) by X"
             ) == "E+W+S+NI"

      assert NoteTerritory.in_force(
               "Reg. 15(1)(ab) inserted (1.9.2006 for E.S., 1.1.2007 in so far as not already in force) by X"
             ) == "E+W+S+NI"

      assert NoteTerritory.in_force(
               "Words substituted (1.10.2023 except in relation to W., 6.4.2024 for W.) by X"
             ) ==
               "E+W+S+NI"
    end

    test "\"except in relation to X.\" alone: everywhere but X" do
      assert NoteTerritory.in_force("S. 4 repealed (1.10.2023 except in relation to W.) by X") ==
               "E+S+NI"
    end

    test "no dated territory: nil (an except naming sections is not a territory)" do
      assert NoteTerritory.in_force("Words in s. 5 substituted (1.1.2017) by S.I. 2016/1154") ==
               nil

      assert NoteTerritory.in_force("S. 7C inserted (11.1.2024 for specified purposes) by X") ==
               nil

      assert NoteTerritory.in_force(
               "Pt. II repealed (6.4.2010 except in relation to ss. 13-15) by X"
             ) == nil

      assert NoteTerritory.in_force(nil) == nil
    end
  end

  describe "migrated from Territory.from_note (LH-06 / coverage II cases)" do
    test "bare forms" do
      assert NoteTerritory.applies(
               "Regulations revoked (S.) (1.11.2025) by The Environmental Authorisations (Scotland) Amendment Regulations 2025"
             ) ==
               ["S"]

      assert NoteTerritory.applies("Words substituted (E. and W.) (1.4.2010) by x") == ["E+W"]
      assert NoteTerritory.applies("Art. 2 revoked (in relation to W.) (1.1.2000) by x") == ["W"]
      assert NoteTerritory.applies("S. 3 repealed (E.W.S.) (1.1.2000) by x") == ["E+W+S"]

      # every clause (uksi 1996/972 reg.10A)
      assert NoteTerritory.applies(
               "Regulations revoked (E.) (1.10.2005) by S.I. 2005/894, regs. 1, 2 and Regulations revoked (W.) (16.7.2005) by S.I. 2005/1806, reg. 1"
             ) == ["E", "W"]
    end

    test "dated forms" do
      assert NoteTerritory.in_force(
               "Ss. 1-28 repealed (1.4.2015 for S. for the repeal of ss. 1-19, 22-28) by Pollution Prevention and Control Act 1999 (c. 24)"
             ) == "S"

      assert NoteTerritory.in_force("Reg. 3 revoked (1.4.2010 in relation to E.W.) by x") == "E+W"
    end

    test "no territory, or only in the amending instrument's title" do
      for note <- [
            "Art. 22 revoked (15.4.2018) by The Regulations 2018 (subject to savings)",
            "Reg. 5 revoked (1.1.2000) by The Fire (Scotland) Order (S.S.I. 2005/344) (S.)"
          ] do
        assert NoteTerritory.applies(note) == []
        assert NoteTerritory.in_force(note) == nil
      end
    end
  end
end
