defmodule SertantaiLegal.Scraper.AmendingLaw.RefListTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.RefList

  test "a law's own provision list (SOCPA 2005 s.179(3), Coronavirus Act 2020 s.89(2))" do
    assert RefList.parse(
             "sections 60 to 68, 70, 107(1) and (4) and 108, section 123, Schedules 1, 3, 5 and 15, Part 2 of Schedule 10, this section",
             "s.179"
           ) ==
             [
               "s.60..s.68",
               "s.70",
               "s.107(1)",
               "s.107(4)",
               "s.108",
               "s.123",
               "sch.1",
               "sch.3",
               "sch.5",
               "sch.15",
               "sch.10.pt.2",
               "s.179"
             ]

    assert RefList.parse("sections 59 to 70;") == ["s.59..s.70"]
  end

  test "covers?/2: a ref inside an item" do
    assert RefList.covers?("s.59..s.70", "s.62(1)")
    refute RefList.covers?("s.59..s.70", "s.78")
    assert RefList.covers?("sch.7", "sch.7.para.27(2)")
    assert RefList.covers?("s.107", "s.107(4)")
  end

  test "a lettered range spelt out (SI 2014/469: \"paragraph 8(2)(b) to (d)\")" do
    assert RefList.parse("paragraph 8(2)(b) to (d) of Schedule 1") ==
             ["sch.1.para.8(2)(b)", "sch.1.para.8(2)(c)", "sch.1.para.8(2)(d)"]

    assert RefList.parse("regulation 4(a) to (c)") == ["reg.4(a)", "reg.4(b)", "reg.4(c)"]
  end

  test "\"this article\", \"This Regulation\": the provision's own (CV-S05 round 8)" do
    assert RefList.parse("This article, articles 6(4) and (5) and 7", "reg.1") ==
             ["reg.1", "reg.6(4)", "reg.6(5)", "reg.7"]

    assert RefList.parse("This Regulation, Regulation 2 and Regulations 8 to 11", "reg.1") ==
             ["reg.1", "reg.2", "reg.8..reg.11"]
  end

  describe "sub-letter runs (CV-S05 round 13, S2: the CV-S05d census)" do
    test "a letter after a lettered path keeps its parent (SI 2005/457 art.1, ukpga 1981/29 s.46)" do
      assert RefList.parse("Article 2(1)(a) and (b)") == ["reg.2(1)(a)", "reg.2(1)(b)"]
      assert RefList.parse("section 19(2)(a) and (b)") == ["s.19(2)(a)", "s.19(2)(b)"]
    end

    test "each level continued in turn (ukpga 1998/37 s.121)" do
      assert RefList.parse("Sections 36(1), (2)(a), (b) and (d) and (6)(b) and section 118") ==
               ["s.36(1)", "s.36(2)(a)", "s.36(2)(b)", "s.36(2)(d)", "s.36(6)(b)", "s.118"]
    end

    test "roman numerals under letters (SI 2024/437 reg.1, SI 2022/1273 reg.1)" do
      assert RefList.parse("regulation 2(f), (g), (w)(i) and (ii) and (x)") ==
               ["reg.2(f)", "reg.2(g)", "reg.2(w)(i)", "reg.2(w)(ii)", "reg.2(x)"]

      assert RefList.parse(
               "Regulations 4, 5, 62(6) and 72(2)(a)(ii) and (iii), (b)(i), (c)(ii) and (iii), and (d)(ii), (iii) and (iv)"
             ) ==
               ~w[reg.4 reg.5 reg.62(6) reg.72(2)(a)(ii) reg.72(2)(a)(iii) reg.72(2)(b)(i)
                  reg.72(2)(c)(ii) reg.72(2)(c)(iii) reg.72(2)(d)(ii) reg.72(2)(d)(iii) reg.72(2)(d)(iv)]
    end

    test "a space before a short label: \"34 (f)\" (SI 2013/1506 reg.3(2))" do
      assert RefList.parse("Regulations 1, 2(1), (4) and (5), 7, 33(2) and 34 (f)") ==
               ~w[reg.1 reg.2(1) reg.2(4) reg.2(5) reg.7 reg.33(2) reg.34(f)]

      # (never a describing bracket)
      assert RefList.parse("section 5 (power to make regulations)") == ["s.5"]
    end
  end

  describe "subdivisions named before their provision (round 13, S13)" do
    test "never the whole provision" do
      assert RefList.parse("subsections (1) to (6) of section 11") ==
               ~w[s.11(1) s.11(2) s.11(3) s.11(4) s.11(5) s.11(6)]

      assert RefList.parse("Paragraphs (28), (29)(b), (32) and (51) to (54) of regulation 5") ==
               ~w[reg.5(28) reg.5(29)(b) reg.5(32) reg.5(51) reg.5(52) reg.5(53) reg.5(54)]

      assert RefList.parse("sub-paragraph (2) of paragraph 3 of Schedule 1") == [
               "sch.1.para.3(2)"
             ]
    end
  end

  test "an unnumbered Schedule: \"Part I of the Schedule\", \"paragraphs 1 and 14 of the Schedule\" (round 13: agent seed 18)" do
    assert RefList.parse("Part I; and Part I of the Schedule.", "s.31")
           |> Enum.member?("sch.pt.I")

    assert RefList.parse("paragraphs 1 and 14 of the Schedule") == ["sch.para.1", "sch.para.14"]
    # (never another law's Schedule)
    assert RefList.parse("paragraph 3 of the Schedule to the Health Act 2006") == []
  end
end
