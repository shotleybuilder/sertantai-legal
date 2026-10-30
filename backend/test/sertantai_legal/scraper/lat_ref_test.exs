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

  describe "covers?/3: ends at different depths (CV-S09 batch 5)" do
    # SI 1996/396: "Schedule 10 paragraphs 11(2) to 13" (EA 1995 sch.10
    # para.12 substituted HSWA s.28(10))
    test "from a subparagraph to a paragraph" do
      r = "sch.10.para.11(2)..sch.10.para.13"
      assert LatRef.covers?(r, "sch.10.para.12")
      assert LatRef.covers?(r, "sch.10.para.13")
      assert LatRef.covers?(r, "sch.10.para.11(3)")
      refute LatRef.covers?(r, "sch.10.para.11(1)")
      refute LatRef.covers?(r, "sch.10.para.11")
      refute LatRef.covers?(r, "sch.10.para.14")
    end

    test "from a paragraph to a subparagraph" do
      r = "s.4..s.6(2)"
      assert LatRef.covers?(r, "s.4")
      assert LatRef.covers?(r, "s.5")
      assert LatRef.covers?(r, "s.6(1)")
      refute LatRef.covers?(r, "s.6")
      refute LatRef.covers?(r, "s.6(3)")
      refute LatRef.covers?(r, "s.7")
    end
  end
end
