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

  describe "S4: a qualified companion is withheld, never dropped" do
    defp unread(e),
      do: e.lists |> Enum.filter(&match?({:unread, _, _}, &1)) |> Enum.flat_map(&elem(&1, 2))

    test "\"(b) paragraphs 87 and 88 of Schedule 5 (and section 55 so far as relating to those paragraphs)\" (ukpga 2022/30 s.169)" do
      e =
        read(
          "UK_ukpga_2022_30",
          p1("section-1", "This Act extends to England and Wales.") <>
            words([55]) <>
            p1(
              "section-169",
              "The following provisions extend to England and Wales, Scotland and Northern Ireland— a section 1; b paragraphs 87 and 88 of Schedule 5 (and section 55 so far as relating to those paragraphs)."
            )
        )

      assert "s.55" in unread(e)
      refute Extent.of(e, "s.55") == "E+W"
      assert Extent.of(e, "sch.5.para.87") == "E+W+S+NI"
    end

    test "\"Part 6 (including Schedule 13 so far as it relates to Part 6) extends to …\" (ukpga 2023/55 s.254)" do
      e =
        read(
          "UK_ukpga_2023_55",
          ~s(<Part id="part-6">#{words([100])}</Part>) <>
            p1(
              "section-254",
              "Part 6 (including Schedule 13 so far as it relates to Part 6) extends to England and Wales, Scotland and Northern Ireland."
            )
        )

      assert Extent.of(e, "s.100") == "E+W+S+NI"
      assert "sch.13" in unread(e)
    end

    test "\"subsections (4) and (5) above so far as they relate to …\" in a list: the section's own, withheld (ukpga 1977/38 s.32)" do
      e =
        read(
          "UK_ukpga_1977_38",
          words([1, 29, 32]) <>
            p1(
              "section-32",
              "The following provisions of this Act extend to Scotland only, namely— section 1(2); section 29; subsections (4) and (5) above so far as they relate to any enactment which extends to Scotland only."
            )
        )

      assert "s.32(4)" in unread(e)
      assert Extent.of(e, "s.29") == "S"
    end
  end

  describe "S5: a provision's own subsections and self in its list" do
    test "\"subsections (1), (3) and (6) to (10) of this section\" (Criminal Law Act 1977 s.65(10)(b))" do
      e =
        read(
          "UK_ukpga_1977_45",
          words([38, 52]) <>
            p1(
              "section-65",
              "In this Act—a Part V extends to Scotland;b the following provisions extend to Northern Ireland namely— sections 38 to 40, section 52, subsections (1), (3) and (6) to (10) of this section, Schedule 7, in Schedule 14, paragraph 5;c section 31 extends to the Channel Islands; but save as aforesaid, this Act extends to England and Wales only."
            )
        )

      assert Extent.of(e, "s.65(1)") == "E+W+NI"
      assert Extent.of(e, "s.65(7)") == "E+W+NI"
      assert Extent.of(e, "s.65(2)") == "E+W"
    end

    test "\"(b) subsections (1) to (4), this subsection and …\" (ukpga 1992/43 s.56(5))" do
      e =
        read(
          "UK_ukpga_1992_43",
          p1("section-1", "This Act extends to England and Wales and Scotland.") <>
            words([49, 54]) <>
            p1(
              "section-56",
              "The following provisions of this Act extend to Northern Ireland—a sections 1 to 10, 49 and 54;b subsections (1) to (4) of this section."
            )
        )

      assert Extent.of(e, "s.56(1)") == "E+W+S+NI"
    end

    test "\"(v) this Chapter\" in a named list (ukpga 2017/3 s.182(2))" do
      e =
        read(
          "UK_ukpga_2017_3",
          p1("section-1", "This Act extends to England and Wales.") <>
            ~s(<Part id="part-9"><Chapter id="part-9-chapter-2">#{words([180, 181])}#{p1("section-182", "The following provisions extend to England and Wales, Scotland and Northern Ireland—a section 35;b section 50;v this Chapter.")}</Chapter></Part>)
        )

      assert Extent.of(e, "s.180") == "E+W+S+NI"
    end

    test "\"this section extends also to Scotland\" (ukpga 1998/31 s.145)" do
      e =
        read(
          "UK_ukpga_1998_31",
          p1("section-1", "This Act extends to England and Wales.") <>
            words([130]) <>
            p1(
              "section-145",
              "Section 130(2) extends to Scotland only; and this section extends also to Scotland."
            )
        )

      assert Extent.of(e, "s.145") == "E+W+S"
    end
  end

  describe "S6: statements whose verb comes late" do
    test "\"the following provisions of this Act— (a) …; (b) …; extend to England and Wales only\" (ukpga 1982/53 s.77)" do
      e =
        read(
          "UK_ukpga_1982_53",
          words([3, 4, 6, 17]) <>
            p1(
              "section-77",
              "Subject to subsection (6) below, the following provisions of this Act—a sections 3, 4 and 6;b sections 17 to 22, extend to England and Wales only."
            )
        )

      assert Extent.of(e, "s.3") == "E+W"
    end

    test "\"This Act does not extend to Northern Ireland and— (a) in Part IV, sections 42 and 43 extend to England and Wales only and section 44 extends to Scotland only\" (ukpga 1987/27 s.50)" do
      e =
        read(
          "UK_ukpga_1987_27",
          words([1, 42, 43, 44]) <>
            p1(
              "section-50",
              "This Act does not extend to Northern Ireland and—a in Part IV, sections 42 and 43 extend to England and Wales only and section 44 extends to Scotland only."
            )
        )

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.42") == "E+W"
      assert Extent.of(e, "s.44") == "S"
    end

    test "\"This Act shall not extend to Scotland or, . . . to Northern Ireland\" (ukpga 1968/64 s.20)" do
      e =
        read(
          "UK_ukpga_1968_64",
          p1("section-20", "This Act shall not extend to Scotland or, . . . to Northern Ireland.")
        )

      assert e.default == "E+W"
    end
  end

  describe "S7: a whole-law default" do
    test "\"This Act extends to Scotland (subject to subsection (6)) and Northern Ireland\" (ukpga 1999/28 s.43)" do
      e =
        read(
          "UK_ukpga_1999_28",
          p1(
            "section-43",
            "This Act extends to Scotland (subject to subsection (6)) and Northern Ireland."
          )
        )

      assert e.default == "S+NI"
    end

    test "\"This Act extends only to England and Wales, except that— (a) section 46(1) extends to Scotland only, …\" (ukpga 2010/29 s.49)" do
      e =
        read(
          "UK_ukpga_2010_29",
          words([1, 46]) <>
            p1(
              "section-49",
              "This Act extends only to England and Wales, except that—a section 46(1) extends to Scotland only,b paragraph 43 of Schedule 4 extends to England and Wales and Scotland."
            )
        )

      assert e.default == "E+W"
      assert Extent.of(e, "s.46(1)") == "S"
    end
  end

  describe "S9: a qualified subject or object never read whole" do
    test "\"this Part to the extent that it applies to those sections\" (ukpga 2006/41 s.278)" do
      e =
        read(
          "UK_ukpga_2006_41",
          p1("section-1", "This Act extends to England and Wales.") <>
            ~s(<Part id="part-13">#{words([260, 266])}</Part><Part id="part-15">#{words([271])}#{p1("section-278", "Sections 260 to 266 in Part 13 (price of medical supplies), and this Part to the extent that it applies to those sections, extend also to Scotland and Northern Ireland.")}</Part>)
        )

      assert Extent.of(e, "s.260") == "E+W+S+NI"
      refute Extent.of(e, "s.271") == "E+W+S+NI"
    end

    test "\"section 43 so far as it applies to regulations under section 46\": s.46 is the object (ukpga 2014/2 s.?)" do
      e =
        read(
          "UK_ukpga_2014_2",
          p1("section-1", "This Act extends to England and Wales.") <>
            words([43, 45, 46]) <>
            p1(
              "section-50",
              "The following provisions of this Act extend to England and Wales, Scotland and Northern Ireland—a section 43 (orders and regulations) so far as it applies to regulations under section 46 or an order under section 49;b section 45."
            )
        )

      refute Extent.of(e, "s.46") == "E+W+S+NI"
      assert Extent.of(e, "s.45") == "E+W+S+NI"
    end
  end

  describe "S10: repealed words inside a number list" do
    test "\"This Act, except sections ... ... 101 and this section, does not extend to Northern Ireland\" (ukpga 1974/40 s.109)" do
      e =
        read(
          "UK_ukpga_1974_40",
          words([1, 101]) <>
            p1(
              "section-109",
              "This Act, except sections ... ... 101 and this section, does not extend to Northern Ireland."
            )
        )

      assert Extent.of(e, "s.101") == "E+W+S+NI"
    end

    test "\"Sections ... 4, 5, . . . of this Act do not extend to Scotland\" (ukpga 1976/55 s.27)" do
      e =
        read(
          "UK_ukpga_1976_55",
          p1("section-1", "This Act extends to England and Wales and Scotland.") <>
            words([4, 5]) <>
            p1(
              "section-27",
              "Sections ... 4, 5, . . . . . . of this Act do not extend to Scotland."
            )
        )

      assert Extent.of(e, "s.4") == "E+W"
    end
  end

  describe "S12: a same-extent item" do
    test "\"(c) section 15 and Schedules 3 and 4 have the same extent as the enactments which they amend or repeal\" (ukpga 1999/9 s.17)" do
      e =
        read(
          "UK_ukpga_1999_9",
          ~s(<Part id="part-I">#{words([1])}</Part><Part id="part-II">#{words([12])}</Part><Part id="part-III">#{words([15])}</Part>) <>
            p1(
              "section-17",
              "In this Act—a Part I extends to England and Wales only,b Part II extends to Scotland only, andc section 15 and Schedules 3 and 4 have the same extent as the enactments which they amend or repeal."
            )
        )

      assert Extent.of(e, "s.15") == :same
      assert Extent.of(e, "sch.3") == :same
    end
  end

  describe "S14: \"cease to apply\"" do
    test "\"Section 61B(1) to (7) (…) cease to apply in relation to England\" is not applying there (ukpga 2013/27 s.5)" do
      e =
        read(
          "UK_ukpga_2013_27",
          p1(
            "section-5",
            "Section 61B(1) to (7) (Secretary of State or Welsh Ministers may call in unadopted local development order for approval) cease to apply in relation to England."
          )
        )

      refute Enum.any?(rows(e, :applies), fn {_, refs} -> "s.61B(1)" in refs end)

      assert {"E", ~w[s.61B(1) s.61B(2) s.61B(3) s.61B(4) s.61B(5) s.61B(6) s.61B(7)]} in rows(
               e,
               :applies_not
             )
    end
  end

  describe "S15: a bracket then a bare number" do
    test "\"sections 228, 229 (and Schedule 22), 230, 233 to 236 …\" are sections (ukpga 2023/55 s.254(12))" do
      e =
        read(
          "UK_ukpga_2023_55",
          p1("section-1", "This Act extends to England and Wales, Scotland and Northern Ireland.") <>
            words([228, 229, 230, 233, 236]) <>
            p1(
              "section-254",
              "In Part 12— a sections 228, 229 (and Schedule 22), 230, 233 to 236 extend to England and Wales only; b section 231 extends to Scotland only."
            )
        )

      assert Extent.of(e, "s.230") == "E+W"
      assert Extent.of(e, "sch.22") == "E+W"
      refute Enum.any?(e.lists, fn {_, _, refs} -> "sch.230" in refs end)
    end
  end

  describe "S8: territorial application (class KA)" do
    test "\"They apply in relation to— (a) England …, and (b) Wales\" (uksi 2016/1154 reg.1(3))" do
      e =
        read(
          "UK_uksi_2016_1154",
          p1(
            "regulation-1",
            "These Regulations may be cited as the Environmental Damage (Prevention and Remediation) (England) Regulations 2016. These Regulations extend to England and Wales only. They apply in relation to—a England and the sea adjacent to England out as far as the seaward boundary of the territorial sea, andb Wales, within the meaning given by section 158 of the Government of Wales Act 2006."
          )
        )

      assert e.application == "E+W"
    end

    test "\"Regulation 17 applies in relation to live fish and live eggs of fish in Wales\" (wsi 2014/3303)" do
      e =
        read(
          "UK_wsi_2014_3303",
          words([17], "regulation") <>
            p1(
              "regulation-2",
              "Regulation 17 applies in relation to live fish and live eggs of fish in Wales."
            )
        )

      assert {"W", ["reg.17"]} in rows(e, :applies)
    end

    test "never a disapplication of things in a place (uksi 2012/3119)" do
      e =
        read(
          "UK_uksi_2012_3119",
          words([14], "regulation") <>
            p1(
              "regulation-1",
              "These Regulations do not apply in relation to any building in Wales, other than an excepted energy building."
            )
        )

      assert e.application == nil
    end
  end

  describe "found by the census run-04 (round 13's own check)" do
    test "things that are cases, not a place's, set no application" do
      e =
        read(
          "UK_ukpga_1982_27",
          p1(
            "section-18",
            "This section applies to a freezing order made under section 40D of the Immigration Act 2014 by a magistrates' court in England and Wales or a court of summary jurisdiction in Northern Ireland."
          ) <>
            p1(
              "section-19",
              "Subsections (5) to (8) of this section apply to a corporate joint committee as they apply to a local authority in Wales."
            ) <>
            p1(
              "section-20",
              "Subsection (3C) applies to an agent who advertises letting agency work in relation to dwelling houses in England."
            )
        )

      assert rows(e, :applies) == []
    end

    test "a range before a describing bracket: \"section 14(3) to (5) (acknowledgment …)\" (ukpga 2011/16 s.120)" do
      alias SertantaiLegal.Scraper.AmendingLaw.RefList

      assert RefList.parse("section 14(3) to (5) (acknowledgment of green deal plan)") ==
               ~w[s.14(3) s.14(4) s.14(5)]

      assert RefList.parse("section 29(1) to (3) (and section 29(4) has effect accordingly)")
             |> Enum.take(3) == ~w[s.29(1) s.29(2) s.29(3)]
    end
  end

  test "each \"in Schedule N, paragraphs …\" its own Schedule's; \"by virtue of subsection (6)\" no item" do
    alias SertantaiLegal.Scraper.AmendingLaw.RefList

    assert RefList.parse(
             "in Schedule 2, paragraphs 2, 5 and 7(3), in Schedule 4, paragraphs 1, 2 and 4."
           ) ==
             ~w[sch.2.para.2 sch.2.para.5 sch.2.para.7(3) sch.4.para.1 sch.4.para.2 sch.4.para.4]

    assert RefList.parse(
             "any provision which extends to England and Wales only by virtue of subsection (6) or (7)",
             "s.119"
           ) == []
  end

  test "never another law's section, nor an \"as if\" modification, as an application (2003/20 s.24, 1990/8 s.319ZZA)" do
    e =
      read(
        "UK_ukpga_2003_20",
        p1(
          "section-24",
          "Section 10 of the Police and Fire Reform (Scotland) Act 2012 (declaration) shall apply to a constable of the Police Force appointed in Scotland."
        ) <>
          p1(
            "section-25",
            "This section applies in relation to a relevant planning function conferred on a mineral planning authority as if references to a local planning authority were to a mineral planning authority in England."
          )
      )

    assert rows(e, :applies) == []
  end

  test "\"Part 6 of this Act (nature and biodiversity) extends to England and Wales, except that— (a) the amendments made by Schedule 15 … have the same extent as …\" (ukpga 2021/30 s.146)" do
    e =
      read(
        "UK_ukpga_2021_30",
        ~s(<Part id="part-6">#{words([100, 101])}</Part>) <>
          p1(
            "section-146",
            "Part 6 of this Act (nature and biodiversity) extends to England and Wales, except that— a the amendments made by Schedule 15 (biodiversity gain in nationally significant infrastructure projects) have the same extent as the provisions amended; b section 101 extends to England and Wales and Scotland."
          )
      )

    assert Extent.of(e, "s.100") == "E+W"
  end

  describe "agent seed 18: an unnumbered Schedule" do
    test "\"(b) Part I of the Schedule\" does not extend to Scotland (ukpga 1981/45 s.31)" do
      e =
        read(
          "UK_ukpga_1981_45",
          ~s(<Part id="part-I">#{words([1, 2])}</Part>) <>
            p1(
              "section-31",
              "The following provisions of this Act do not extend to Scotland, namely—a Part I; andb Part I of the Schedule."
            ) <>
            p1("section-32", "It is hereby declared that this Act extends to Northern Ireland.")
        )

      assert Extent.of(e, "sch.pt.I") == "E+W+NI"
      assert Extent.of(e, "sch.para.3") == "E+W+S+NI"
    end

    test "\"This article extends to …, and paragraphs 1 and 14 of the Schedule, and article 3 in so far as …, have the same extent as the provisions modified\" (SI 2005/2060 art.1(4))" do
      e =
        read(
          "UK_uksi_2005_2060",
          words([3], "article") <>
            p1(
              "article-1",
              "Subject to paragraph (4), this Order extends to Scotland only. This article extends to England and Wales, Scotland and Northern Ireland, and paragraphs 1 and 14 of the Schedule, and article 3 in so far as it relates to those paragraphs, have the same extent as the provisions modified."
            )
        )

      assert Extent.of(e, "sch.para.1") == :same
      assert Extent.of(e, "sch.para.14(2)") == :same
      refute Extent.of(e, "reg.3") == :same
      assert Extent.of(e, "reg.1") == "E+W+S+NI"
    end
  end

  describe "agent seed 19" do
    test "\"Part 2 of Schedule 10 extends to Northern Ireland only\" reaches the Part's paragraphs, ids without the Part (SOCPA 2005 s.179(6)(d))" do
      e =
        read(
          "UK_ukpga_2005_15",
          p1("section-1", "This Act extends to England and Wales.") <>
            words([144]) <>
            ~s(<Schedule id="schedule-10"><Part id="schedule-10-part-1">#{p1("schedule-10-paragraph-1", "Words.")}</Part><Part id="schedule-10-part-2">#{p1("schedule-10-paragraph-8", "Words.")}</Part></Schedule>) <>
            p1("section-179", "Part 2 of Schedule 10 extends to Northern Ireland only.")
        )

      assert Extent.of(e, "sch.10.para.8") == "NI"
      assert Extent.of(e, "sch.10.para.8(2)") == "NI"
      refute Extent.of(e, "sch.10.para.1") == "NI"
    end

    test "an aside with a nested bracket withholds only its own provision (Police and Justice Act 2006 s.54(2))" do
      e =
        read(
          "UK_ukpga_2006_48",
          p1("section-1", "This Act extends to England and Wales.") <>
            ~s(<Schedule id="schedule-1"><Part id="schedule-1-part-5">#{p1("schedule-1-paragraph-40", "Words.")}</Part></Schedule>) <>
            p1(
              "section-54",
              "The following provisions extend also to Scotland and Northern Ireland— section 5; Parts 5 and 6 of Schedule 1 (and section 1(3) so far as relating to those Parts); section 41."
            )
        )

      assert Extent.of(e, "sch.1.para.40") == "E+W+S+NI"
      assert Extent.of(e, "s.1(3)") == nil
    end

    test "a commencement list's items are no extent statements (Police and Justice Act 2006 s.53(4))" do
      e =
        read(
          "UK_ukpga_2006_48",
          p1("section-1", "This Act extends to England and Wales.") <>
            words([35]) <>
            p1(
              "section-53",
              "The following provisions come into force in accordance with provision made by order by the Scottish Ministers—a sections 35 to 38 so far as they extend to Scotland;b paragraphs 17 to 19 and 29 of Schedule 14 so far as they extend to Scotland."
            )
        )

      refute Enum.any?(e.lists, fn {k, _, refs} -> k == :unread and "s.35..s.38" in refs end)
    end
  end

  test "\"Part 2 of the Schedule\" reaches an unnumbered Schedule's paragraphs (SI 2016/1142 art.1(5))" do
    e =
      read(
        "UK_uksi_2016_1142",
        words([3], "article") <>
          ~s(<Schedule id="schedule"><Part id="schedule-part-1">#{p1("schedule-paragraph-1", "Words.")}</Part><Part id="schedule-part-2">#{p1("schedule-paragraph-3", "Words.")}</Part></Schedule>) <>
          p1(
            "article-1",
            "Articles 3 to 5 and Part 2 of the Schedule extend to England and Wales and Northern Ireland only."
          )
      )

    assert Extent.of(e, "sch.para.3(3)") == "E+W+NI"
    refute Extent.of(e, "sch.para.1") == "E+W+NI"
  end
end
