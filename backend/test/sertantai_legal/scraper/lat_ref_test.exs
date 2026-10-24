defmodule SertantaiLegal.Scraper.LatRefTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatRef

  test "ancestors/1: the row, its levels, an extent version's tagged levels first" do
    assert LatRef.ancestors("L:s.6(1)(a)") == ["L:s.6(1)(a)", "L:s.6(1)", "L:s.6"]

    assert LatRef.ancestors("L:reg.33(1)[S]") ==
             ["L:reg.33(1)[S]", "L:reg.33[S]", "L:reg.33(1)", "L:reg.33"]
  end

  test "V1-03: ancestors/1 reads past a disambiguator (\"s.1(2)n1\": asp 2002/3)" do
    assert LatRef.ancestors("L:s.1(2)n1") == ["L:s.1(2)n1", "L:s.1(2)", "L:s.1"]
    assert LatRef.ancestors("L:s.4n2") == ["L:s.4n2", "L:s.4"]

    assert LatRef.ancestors("L:reg.3(1)n1[S]") ==
             ["L:reg.3(1)n1[S]", "L:reg.3(1)[S]", "L:reg.3[S]", "L:reg.3(1)", "L:reg.3"]
  end

  describe "covers?/3: a range the document order doesn't hold (CV-S04)" do
    test "a range of subsections goes by number when the order lists whole provisions" do
      ctx = %{order: ["s.9", "s.10", "s.11"]}
      assert LatRef.covers?("s.10(2)..s.10(4)", "s.10(3)", ctx)
      refute LatRef.covers?("s.10(2)..s.10(4)", "s.10(5)", ctx)
      assert LatRef.covers?("s.9..s.11", "s.10", ctx)
    end
  end
end
