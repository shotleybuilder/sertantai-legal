defmodule SertantaiLegal.Scraper.TerritoryTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Territory

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

    test "disjoint?/2" do
      assert Territory.disjoint?("W", "S")
      refute Territory.disjoint?("E+W", "W")
    end

    test "union/1 of extent codes" do
      assert Territory.union(["S", "W", "E"]) == "E+W+S"
      assert Territory.union([]) == nil
    end
  end
end
