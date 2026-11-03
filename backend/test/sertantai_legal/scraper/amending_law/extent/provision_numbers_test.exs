defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ProvisionNumbersTest do
  @moduledoc """
  The provision numbers an extent statement names, read by the extent
  reader on each law's real wording: sub-letter runs, locators, a range
  after a singular word, a provision's own subsections and itself,
  repealed words inside a number list, a bracket then a bare number.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns, kind \\ "section"), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))
  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  defp refs(e, kind, place),
    do: for({^kind, ^place, refs} <- e.lists ++ e.applies, r <- refs, do: r)

  describe "sub-letter runs" do
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

  describe "locators" do
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

    test "nested locators, each sub-item its provision's own (uksi 2017/1012 reg.2)" do
      e =
        read(
          "UK_uksi_2017_1012",
          words([70, 71], "regulation") <>
            p1(
              "regulation-2",
              "These Regulations extend to England and Wales only, except as provided in this regulation. The following provisions also extend to Scotland—a regulation 3(8);e in regulation 70 (grant of planning permission)—i paragraph (1)(e)(ii) and (iii) (deemed grant under section 5(1) of the Pipe-lines Act 1962 );ii paragraph (2) in so far as that paragraph relates to sub-paragraph (1)(e)(ii);f in regulation 71 (duty to review), in paragraph (4)—i sub-paragraph (b);ii sub-paragraph (d) in so far as that sub-paragraph relates to a direction;m in Part 1 of Schedule 6 (consequential amendments)—i sub-paragraphs (2) and (4) of paragraph 8 (amendment of the Marine Act)."
            )
        )

      also = refs(e, :also, "S")
      assert "reg.70(1)(e)(ii)" in also
      assert "reg.70(1)(e)(iii)" in also
      assert "reg.71(4)(b)" in also
      assert "sch.6.para.8(2)" in also
      refute "reg.71" in also
      refute "sch.6.pt.1" in also
      assert "reg.71(4)(d)" in refs(e, :unread, nil)
    end
  end

  test "\"section 61 to 65 ...\": a singular word with a range (ukpga 1980/34 s.70)" do
    e =
      read(
        "UK_ukpga_1980_34",
        p1(
          "section-70",
          "The following provisions of this Act do not extend to Northern Ireland, namely,—a section 40;b section 61 to 65 ...; andc Parts I and IV of Schedule 9 (and section 69 so far as it relates to those Parts)."
        )
      )

    assert {:not, "NI", refs} = Enum.find(e.lists, &match?({:not, "NI", _}, &1))
    assert "s.61..s.65" in refs
    assert "sch.9.pt.I" in refs and "sch.9.pt.IV" in refs
  end

  describe "a provision's own subsections and itself in its list" do
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

  describe "repealed words inside a number list" do
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

  describe "a bracket then a bare number" do
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
end
