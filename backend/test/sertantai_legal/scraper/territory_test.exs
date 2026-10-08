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
