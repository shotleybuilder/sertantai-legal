defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Round13ReadsTest do
  @moduledoc """
  The extent reader's misreads found by the CV-S05d whole-reader census
  (run-03, `backend/data/experiments/cv-s05d-whole-reader-census/run-03/out/triage.md`),
  one or more per wording S1–S17, each on its law's real words (CV-S05
  round 13).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns, kind \\ "section"), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))

  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  describe "S2: sub-letter runs" do
    test "\"Subsection (2)(aa) applies only in relation to Wales\" (TCPA 1990 s.70)" do
      e =
        read(
          "UK_ukpga_1990_8",
          p1("section-70", "Subsection (2)(aa) applies only in relation to Wales.") <>
            p1(
              "section-71",
              "Subsections (1A), (2)(b) and (2ZZA) to (2ZZC) of section 70 do not apply in relation to Wales."
            )
        )

      assert {"W", ["s.70(2)(aa)"]} in rows(e, :applies)
    end

    test "\"Subsection (3)(a) above does not apply in Wales\" (ukpga 1980/66 s.264)" do
      e =
        read(
          "UK_ukpga_1980_66",
          p1("section-264", "Subsection (3)(a) above does not apply in Wales.")
        )

      assert {"W", ["s.264(3)(a)"]} in rows(e, :applies_not)
    end

    test "\"Regulations 1, 2(1), (4) and (5), 7, 33(2) and 34 (f) … shall extend to Northern Ireland\" (SI 2013/1506 reg.3(2))" do
      e =
        read(
          "UK_uksi_2013_1506",
          words([1, 2, 7, 33, 34], "regulation") <>
            p1(
              "regulation-3",
              "These Regulations shall not extend to Northern Ireland except as provided by paragraphs (2) and (3). Regulations 1, 2(1), (4) and (5), 7, 33(2) and 34 (f) of these Regulations shall extend to Northern Ireland."
            )
        )

      refs = e.lists |> Enum.filter(&match?({_, "NI", _}, &1)) |> Enum.flat_map(&elem(&1, 2))
      assert "reg.34(f)" in refs
      refute "reg.34" in refs
      assert "reg.2(4)" in refs
    end

    test "\"Article 2(1)(a) and (b) of this Order extends to England and Wales\" (SI 2005/457 art.1)" do
      e =
        read(
          "UK_uksi_2005_457",
          words([2], "article") <>
            p1("article-1", "Article 2(1)(a) and (b) of this Order extends to England and Wales.")
        )

      refs = e.lists |> Enum.flat_map(&elem(&1, 2))
      assert "reg.2(1)(b)" in refs
      refute "reg.2(b)" in refs
    end
  end

  describe "S11: a locator" do
    test "\"in regulation 16, paragraphs (4) and (5)\" is those paragraphs (SI 2020/818 reg.1A)" do
      e =
        read(
          "UK_uksi_2020_818",
          words([16, 17, 18], "regulation") <>
            p1(
              "regulation-1A",
              "The following provisions of these Regulations do not apply in England and Wales or Scotland—a in regulation 16, paragraphs (4) and (5);b regulation 17;c in regulation 18, paragraphs (8)(b) and (9)."
            )
        )

      assert [{"E+W+S", refs}] = rows(e, :applies_not)
      assert Enum.sort(refs) == ~w[reg.16(4) reg.16(5) reg.17 reg.18(8)(b) reg.18(9)]
    end
  end

  describe "S1: exception lists' items extend there too" do
    defp also(e, place),
      do: e.lists |> Enum.filter(&match?({:also, ^place, _}, &1)) |> Enum.flat_map(&elem(&1, 2))

    test "\"Except for the following provisions, that is to say— (a) …; and (b) … so far as …, this Act does not extend to Northern Ireland\" (ukpga 1972/62 s.27)" do
      e =
        read(
          "UK_ukpga_1972_62",
          words([9, 10, 11, 16, 17, 26, 27]) <>
            p1(
              "section-27",
              "Except for the following provisions, that is to say—a sections 9, 10, 11, 16, 17(1), 26(1) and (2) and this section and Schedule 4; andb section 26(3) and (4) and Schedule 6 so far as they relate to the Corn Sales Act 1921, this Act does not extend to Northern Ireland."
            )
        )

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.9") == "E+W+S+NI"
      assert Extent.of(e, "s.27") == "E+W+S+NI"
      assert "sch.4" in also(e, "NI")
      # (a qualified exception item keeps the default: KX, round 6)
      refute "sch.6" in also(e, "NI")
    end

    test "\"Except for section 8, this Act does not extend to Northern Ireland\" (ukpga 1991/65 s.10)" do
      e =
        read(
          "UK_ukpga_1991_65",
          words([1, 8]) <>
            p1(
              "section-10",
              "Except for section 8, this Act does not extend to Northern Ireland."
            )
        )

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.8") == "E+W+S+NI"
      assert Extent.of(e, "s.1") == "E+W+S"
    end

    test "\"This Act does not extend to Scotland, with the exception of— (a) sections …\" (ukpga 1996/25 s.79)" do
      e =
        read(
          "UK_ukpga_1996_25",
          words([37, 41, 79]) <>
            p1(
              "section-79",
              "This Act does not extend to Scotland, with the exception of—a sections 37, 38, 41, 42, 59, 60, 61(3), 63, 72, 73, 74(2) and (3) and 78, this section and section 81;b paragraphs 6 and 7 of Schedule 3, and paragraph 8 of Schedule 3 so far as it relates to paragraphs 6 and 7;c paragraph 5 of Schedule 5."
            )
        )

      assert e.default == "E+W+NI"
      assert Extent.of(e, "s.41") == "E+W+S+NI"
      assert Extent.of(e, "s.79") == "E+W+S+NI"
      assert "sch.3.para.6" in also(e, "S")
    end

    test "\"This Act, except section 63 and except as provided by section 189, does not extend to Northern Ireland\" (ukpga 1972/20 s.209; S16)" do
      e =
        read(
          "UK_ukpga_1972_20",
          words([63, 189]) <>
            p1(
              "section-209",
              "This Act, except section 63 and except as provided by section 189, does not extend to Northern Ireland."
            )
        )

      assert also(e, "NI") == ["s.63"]
    end

    test "two exception clauses: \"… except section 88, does not extend to Northern Ireland and, except section 86 and Schedule 3, does not extend to Scotland\" (ukpga 1973/26 s.89)" do
      e =
        read(
          "UK_ukpga_1973_26",
          words([1, 86, 88]) <>
            p1(
              "section-89",
              "This Act, except section 88, does not extend to Northern Ireland and, except section 86 and Schedule 3, does not extend to Scotland."
            )
        )

      assert e.default == "E+W"
      assert Extent.of(e, "s.88") == "E+W+NI"
      assert Extent.of(e, "s.86") == "E+W+S"
      assert Extent.of(e, "s.1") == "E+W"
    end

    test "plain pieces of a qualified item read: \"(c) paragraphs 1 to 3 … of Schedule 5 and section 17(1) and (2) so far as relating to those paragraphs\" (ukpga 1995/45 s.18)" do
      e =
        read(
          "UK_ukpga_1995_45",
          words([11, 17, 18]) <>
            p1(
              "section-18",
              "This Act, except—a this section;b subsections (1) to (6) of section 11;c paragraphs 1 to 3, 6, 7, 23 and 30 of Schedule 5 and section 17(1) and (2) so far as relating to those paragraphs; andd Schedule 6 and section 17(5) so far as relating to the repeals of paragraph 1 of Schedule 5 to the Fair Trading Act 1973, does not extend to Northern Ireland."
            )
        )

      assert "sch.5.para.1..sch.5.para.3" in also(e, "NI") or "sch.5.para.1" in also(e, "NI")
      refute "s.17(1)" in also(e, "NI")
      # (S13: "subsections (1) to (6) of section 11" is those, never all of s.11)
      refute "s.11" in also(e, "NI")
    end

    test "\"…; but, with the exception of those provisions, this Act does not extend to Northern Ireland\" (ukpga 1971/11 s.25)" do
      e =
        read(
          "UK_ukpga_1971_11",
          words([1, 8, 25]) <>
            p1(
              "section-25",
              "Sections 1 to 7, 17 to 20, 21(2) and 24 of this Act and the Schedule to this Act extend to Northern Ireland; but, with the exception of those provisions, this Act does not extend to Northern Ireland."
            )
        )

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.1") == "E+W+S+NI"
      assert Extent.of(e, "s.8") == "E+W+S"
    end

    test "\"The following provisions of this Act (apart from this section) extend to Northern Ireland— (a) section 30; …\" (ukpga 1993/11 s.68)" do
      e =
        read(
          "UK_ukpga_1993_11",
          p1("section-1", "This Act extends to England and Wales and Scotland.") <>
            words([30, 32]) <>
            p1(
              "section-68",
              "The following provisions of this Act (apart from this section) extend to Northern Ireland—a section 30;b section 32 so far as it relates to regulations under section 30."
            )
        )

      assert Extent.of(e, "s.30") == "E+W+S+NI"
    end
  end

  describe "S1: the default of an exception clause" do
    test "two not-extend sentences in one clause (ukpga 1973/37 s.40)" do
      e =
        read(
          "UK_ukpga_1973_37",
          words([4, 9]) <>
            p1(
              "section-40",
              "This Act, except section 4(5) to (8), so far as relating to the matters mentioned in section 4(5)(d) and (e) and so much of this Act as relates to the interpretation of those provisions, does not extend to Northern Ireland. The following provisions of this Act, that is to say—a section 4(5) to (8), so far as relating to the matters mentioned in section 4(5)(d) and (e);b section 9, so far as relating to any enactment which extends to Scotland; extend to Scotland, but except as aforesaid this Act does not extend to Scotland."
            )
        )

      assert e.default == "E+W"
    end

    test "never \"the preceding sections of this Act\" as an exception list's subject (ukpga 1999/26 s.46)" do
      alias SertantaiLegal.Scraper.AmendingLaw.Extent.ExceptionList

      assert ExceptionList.statements(
               "Apart from sections 39 and 45 and subject to subsection (1), the preceding sections of this Act shall not extend to Northern Ireland."
             ) == []
    end
  end

  describe "S3: \"or\"-lists in same-extent subjects" do
    defp same(e),
      do: e.lists |> Enum.filter(&match?({:same, nil, _}, &1)) |> Enum.flat_map(&elem(&1, 2))

    defp part(n, ids, kind \\ "section"), do: ~s(<Part id="part-#{n}">#{words(ids, kind)}</Part>)

    test "\"… or Part 1, 8 … or 19 of Schedule 18\" is Schedule 18's Parts, never the Act's (ukpga 2007/28 s.?)" do
      e =
        read(
          "UK_ukpga_2007_28",
          part(1, [1, 10]) <>
            words([60, 202, 239]) <>
            p1(
              "section-246",
              "The extent of any amendment, repeal or revocation made by section 60, 202(1), 203, 209 or 239 or by Schedule 1, 2, 7, 8, 9, 12, 13, 16 or 17 or Part 1, 8, 9, 14, 17, 18 or 19 of Schedule 18 is the same as that of the provision amended, repealed or revoked."
            )
        )

      refs = same(e)
      assert "s.239" in refs and "s.209" in refs and "sch.17" in refs
      assert "sch.18.pt.1" in refs and "sch.18.pt.19" in refs
      refute "s.1" in refs
      refute "s.10" in refs
    end

    test "\"made by Part 2, 3, or 4 of these Regulations\" (SI 2019/530 reg.1)" do
      e =
        read(
          "UK_uksi_2019_530",
          part(2, [5], "regulation") <>
            part(3, [50], "regulation") <>
            part(4, [100], "regulation") <>
            p1(
              "regulation-1",
              "An amendment, repeal or revocation made by Part 2, 3, or 4 of these Regulations has the same extent as the provision being amended, repealed or revoked."
            )
        )

      assert Enum.all?(~w[reg.5 reg.50 reg.100], &(&1 in same(e)))
    end

    test "\"(c) paragraph 12 or 46 of Schedule 2\" (ukpga 2022/6 s.41)" do
      e =
        read(
          "UK_ukpga_2022_6",
          words([24]) <>
            p1(
              "section-41",
              "An amendment made by—a section 24;b Schedule 1;c paragraph 12 or 46 of Schedule 2, has the same extent as the enactment or provision to which it relates."
            )
        )

      assert Enum.all?(~w[s.24 sch.1 sch.2.para.12 sch.2.para.46], &(&1 in same(e)))
    end
  end
end
