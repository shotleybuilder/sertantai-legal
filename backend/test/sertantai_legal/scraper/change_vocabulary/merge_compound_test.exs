defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.CompoundTest do
  @moduledoc """
  The feed's compound amending provision: two sibling pieces in one string
  ("reg.4(2)(a)(b)" is (a) and (b)), never a nesting ("(a)(i)").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.Compound

  describe "pieces/1 expands sibling brackets of one kind" do
    test "letters" do
      assert Compound.pieces("reg.4(2)(a)(b)") == ["reg.4(2)(a)", "reg.4(2)(b)"]
      assert Compound.pieces("sch.16.para.9(a)(e)") == ["sch.16.para.9(a)", "sch.16.para.9(e)"]
      assert Compound.pieces("reg.2(c)(d)") == ["reg.2(c)", "reg.2(d)"]
      assert Compound.pieces("s.1(aa)(bb)") == ["s.1(aa)", "s.1(bb)"]
    end

    test "numbers, with a capital suffix" do
      assert Compound.pieces("reg.10(1)(3)") == ["reg.10(1)", "reg.10(3)"]
      assert Compound.pieces("sch.4.para.33(2)(4)") == ["sch.4.para.33(2)", "sch.4.para.33(4)"]
      assert Compound.pieces("s.5(1A)(2)") == ["s.5(1A)", "s.5(2)"]
    end

    test "roman numerals" do
      assert Compound.pieces("sch.1.para.19(2)(b)(i)(ii)") ==
               ["sch.1.para.19(2)(b)(i)", "sch.1.para.19(2)(b)(ii)"]

      assert Compound.pieces("reg.20(a)(i)(ii)") == ["reg.20(a)(i)", "reg.20(a)(ii)"]
    end
  end

  describe "pieces/1 leaves a ref whole" do
    test "a nesting" do
      for ref <- ["reg.4(2)(a)(i)", "reg.4(1)(a)", "reg.4(2)(b)", "s.3(a)(1)"],
          do: assert(Compound.pieces(ref) == [ref])
    end

    test "a letter beside what may be a roman numeral (ambiguous)" do
      for ref <- ["reg.4(h)(i)", "reg.4(u)(v)", "reg.4(i)(j)"],
          do: assert(Compound.pieces(ref) == [ref])
    end

    test "one bracket, none, or the same piece twice" do
      for ref <- ["reg.4(2)", "sch.7", "reg.4(a)(a)", "sch.6.para.33"],
          do: assert(Compound.pieces(ref) == [ref])
    end
  end
end
