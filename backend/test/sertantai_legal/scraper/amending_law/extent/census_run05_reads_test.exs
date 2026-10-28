defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.CensusRun05ReadsTest do
  @moduledoc """
  The extent reader's misreads found by the CV-S05d census run-05 (CV-S05
  strategy step 1, `backend/data/experiments/cv-s05d-whole-reader-census/run-05/out/triage.md`),
  one or more per wording R1–R13 and the R10 residual, each on its law's
  real words (CV-S05 strategy step 3).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.ApplicationClause

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns, kind \\ "section"), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))
  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  defp refs(e, kind, place),
    do: for({^kind, ^place, refs} <- e.lists ++ e.applies, r <- refs, do: r)

  defp p2s(id, subs),
    do:
      ~s(<P1 id="#{id}">) <>
        Enum.map_join(subs, fn {n, text} ->
          ~s(<P2 id="#{id}-#{n}"><Pnumber>#{n}</Pnumber><P2para><Text>#{text}</Text></P2para></P2>)
        end) <> "</P1>"

  describe "R1: a Schedule's Part that only owns the paragraphs listed" do
    @sentence "Paragraphs 3, 11(a) and (c), 17 of Part 1 of Schedule 1 to this Order apply in relation to England only."

    test "only the paragraphs listed apply to England (uksi 2006/1407 reg.1)" do
      e =
        read(
          "UK_uksi_2006_1407",
          p1("article-1", @sentence) <>
            ~s(<Schedule id="schedule-1"><Part id="schedule-1-part-1">#{p1("schedule-1-part-1-paragraph-3", "Words.")}#{p1("schedule-1-part-1-paragraph-4", "Words.")}#{p1("schedule-1-part-1-paragraph-17", "Words.")}</Part></Schedule>)
        )

      applies = refs(e, :applies, "E")
      assert "sch.1.pt.1.para.3" in applies
      assert "sch.1.pt.1.para.17" in applies
      refute "sch.1.pt.1.para.4" in applies
    end

    test "\"Schedule 1 to this Order apply …\" is never the whole SI's application" do
      assert ApplicationClause.parse(@sentence) == nil
      assert ApplicationClause.parse_bound(@sentence) == nil

      assert ApplicationClause.parse("This Order applies in relation to England only.") ==
               {:apply, ["E"]}
    end
  end

  test "R2: \"… but, subject to that, this Part of this Act extends to England and Wales only\" (ukpga 1980/65 s.47(8))" do
    e =
      read(
        "UK_ukpga_1980_65",
        ~s(<Part id="part-V">#{words([28, 32, 46])}#{p1("section-47", "Sections 32 and 46 above extend to Scotland only but, subject to that, this Part of this Act extends to England and Wales only.")}</Part>)
      )

    assert {"S", ["s.32", "s.46"]} in rows(e, :only)
    assert {"E+W", ["s.28", "s.47"]} in rows(e, :only)
  end

  test "R3: \"section 153 except subsection (1)(k) and (m)\" is withheld, never dropped (ukpga 1990/43 s.164)" do
    e =
      read(
        "UK_ukpga_1990_43",
        words([141, 153]) <>
          p1(
            "section-164",
            "Only the following provisions of this Act (together with this section) extend to Northern Ireland, namely— section 141; section 153 except subsection (1)(k) and (m); section 156 in so far as it relates to Part VI."
          )
      )

    assert "s.141" in refs(e, :also, "NI")
    assert "s.153" in refs(e, :unread, nil)
    refute "s.164(1)(k)" in refs(e, :unread, nil)
  end

  describe "R4: \"extend to England and Wales but apply in relation to England only\" (uksi 2010/708 art.1)" do
    test "the extent half is read, and \"but Part 5 applies\" is Part 5's alone" do
      e =
        read(
          "UK_uksi_2010_708",
          p1(
            "article-1",
            "Parts 1, 5 and 6 extend to England and Wales, but Part 5 applies in relation to England only."
          ) <>
            ~s(<Part id="part-1">#{words([2], "article")}</Part><Part id="part-5">#{words([11], "article")}</Part><Part id="part-6">#{words([13], "article")}</Part>)
        )

      assert {"E+W", ["reg.2", "reg.11", "reg.13"]} in rows(e, :named)
      assert {"E", ["reg.11"]} in rows(e, :applies)
    end

    test "\"article 9, together with Schedule 2, extend to E+W but apply in relation to England only\"" do
      e =
        read(
          "UK_uksi_2010_708",
          words([9], "article") <>
            p1(
              "article-2",
              "Article 9, together with Schedule 2, extend to England and Wales but apply in relation to England only."
            )
        )

      assert {"E+W", ["reg.9", "sch.2"]} in rows(e, :named)
      assert {"E", ["reg.9", "sch.2"]} in rows(e, :applies)
    end
  end

  test "R5: nested locators, each sub-item its provision's own (uksi 2017/1012 reg.2)" do
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

  test "R6: \"in Schedule 11, the amendments to …\" withholds the Schedule, never reads it whole (ukpga 2022/32 s.207)" do
    e =
      read(
        "UK_ukpga_2022_32",
        words([54, 79]) <>
          p1(
            "section-207",
            "The following provisions extend to England and Wales only— a section 54; b section 79; c in Schedule 11, the amendments to the Rehabilitation of Offenders Act 1974 and the Police Act 1997."
          )
      )

    refute "sch.11" in refs(e, :only, "E+W")
    assert "sch.11" in refs(e, :unread, nil)
  end

  test "R7: \"This subsection does not apply to Scotland\" is the subsection's (ukpga 1974/39 s.189(3))" do
    e =
      read(
        "UK_ukpga_1974_39",
        p2s("section-189", [
          {"1", "In this Act, unless the context otherwise requires— words."},
          {"3",
           "Any provision of this Act requiring a document to be signed is complied with by a body corporate if the document is sealed by that body. This subsection does not apply to Scotland."}
        ])
      )

    assert {"S", ["s.189(3)"]} in rows(e, :applies_not)
  end

  test "R8: \"(and those Parts of Schedule 7)\" after a qualified item (ukpga 2020/7 s.100)" do
    e =
      read(
        "UK_ukpga_2020_7",
        words([1, 8]) <>
          ~s(<Schedule id="schedule-7"><Part id="schedule-7-part-1">#{p1("schedule-7-paragraph-1", "Words.")}</Part><Part id="schedule-7-part-3">#{p1("schedule-7-paragraph-8", "Words.")}</Part></Schedule>) <>
          p1(
            "section-100",
            "The following provisions extend to England and Wales, Scotland and Northern Ireland—a section 1;c section 8, so far as it relates to Part 1 of Schedule 7 (and that Part of Schedule 7)."
          )
      )

    named = refs(e, :named, "E+W+S+NI")
    assert "sch.7.para.1" in named
    refute "sch.7.para.8" in named
    refute "s.8" in named
    assert "s.8" in refs(e, :unread, nil)
  end

  test "R9: \"…, but this paragraph does not apply in Scotland\" (uksi 2026/194 reg.22(3))" do
    e =
      read(
        "UK_uksi_2026_194",
        p2s("regulation-22", [
          {"3",
           "In default of an agreement, the arbitrator is such person as may be appointed following a request by— a a party; or b the parties jointly, but this paragraph does not apply in Scotland."}
        ])
      )

    assert {"S", ["reg.22(3)"]} in rows(e, :applies_not)
  end

  describe "R10: the clause's own section leading an exception list" do
    test "\"…, that is to say, this section and— (a) …\" (ukpga 1988/19 s.34)" do
      e =
        read(
          "UK_ukpga_1988_19",
          words([33]) <>
            p1(
              "section-34",
              "This Act, except for the following provisions, shall not extend to Northern Ireland, that is to say, this section and—a . . .c section 33 so far as it gives effect to any amendment specified in Schedule 3."
            )
        )

      assert "s.34" in refs(e, :also, "NI")
    end

    test "\"Except for this section and any amendment or repeal by this Act …\" (ukpga 1995/25 s.125)" do
      e =
        read(
          "UK_ukpga_1995_25",
          p1(
            "section-125",
            "Except for this section and any amendment or repeal by this Act of any provision contained in—a the Parliamentary Commissioner Act 1967,b the Sea Fish (Conservation) Act 1967, this Act shall not extend to Northern Ireland."
          )
        )

      assert "s.125" in refs(e, :also, "NI")
    end
  end

  test "R11: the saving in \"The repeal by this Act of … and the corresponding saving in paragraph 2 of Schedule 2 …\" (ukpga 1980/58 s.41)" do
    e =
      read(
        "UK_ukpga_1980_58",
        p1(
          "section-41",
          "The repeal by this Act of section 14(1) of the Limitation Act 1963 and the corresponding saving in paragraph 2 of Schedule 2 to this Act shall extend to Northern Ireland, but otherwise this Act does not extend to Scotland or to Northern Ireland."
        )
      )

    assert {"NI", ["sch.2.para.2"]} in rows(e, :named)
  end

  test "R12: \"extends to other parts of the United Kingdom\" (ukpga 1978/29 s.110)" do
    e =
      read(
        "UK_ukpga_1978_29",
        p1(
          "section-110",
          "Paragraph 3 of Schedule 10 extends to other parts of the United Kingdom."
        )
      )

    assert {"E+W+S+NI", ["sch.10.para.3"]} in rows(e, :named)
  end

  test "R13: \"… and those in Part III of Schedule 1 to Scotland only\" (ukpga 1990/11 s.7)" do
    e =
      read(
        "UK_ukpga_1990_11",
        p1(
          "section-7",
          "The repeals in Part II of Schedule 1 extend to England and Wales only and those in Part III of Schedule 1 to Scotland only."
        )
      )

    assert {"E+W", ["sch.1.pt.II"]} in rows(e, :only)
    assert {"S", ["sch.1.pt.III"]} in rows(e, :only)
  end

  test "R10 residual: \"Chapters 1 to 5 of Part 8\" after \"in Part 8 (…),\" never reaches Chapter 6 (ukpga 2009/23 s.323)" do
    e =
      read(
        "UK_ukpga_2009_23",
        ~s(<Part id="part-8"><Chapter id="part-8-chapter-5">#{words([290])}</Chapter><Chapter id="part-8-chapter-6">#{words([293, 295])}</Chapter></Part>) <>
          p1(
            "section-323",
            "This Act extends to England and Wales only. The following provisions also extend to Scotland—a in Part 8 (enforcement), Chapters 1 to 5 of Part 8 and section 295."
          )
      )

    also = refs(e, :also, "S")
    assert "s.290" in also
    assert "s.295" in also
    refute "s.293" in also
  end

  describe "seed 20 observations" do
    test "an exception list whose items are another subsection's (ukpga 1989/38 s.30(5)-(6))" do
      e =
        read(
          "UK_ukpga_1989_38",
          words([10, 22, 27]) <>
            p2s("section-30", [
              {"5",
               "With the exception of the provisions mentioned in subsection (6), this Act does not extend to Northern Ireland."},
              {"6",
               "Those provisions are— a sections 10(1) and (2) so far as they amend or repeal any enactment which extends to Northern Ireland; b section 10(6); c paragraph 2 of Schedule 5 and section 22(5) so far as relating thereto; d section 27 (which extends only to Northern Ireland); and e this section."}
            ])
        )

      also = refs(e, :also, "NI")
      assert "s.10(6)" in also
      assert "sch.5.para.2" in also
      assert {"NI", ["s.27"]} in rows(e, :only)
      assert "s.30" in also
      refute "s.10(1)" in also
      refute "s.22(5)" in also
      assert e.default == "E+W+S"
    end

    test "\"Subsections (5) to (7) above shall not extend to Scotland\" (ukpga 1987/43 s.5(8))" do
      e =
        read(
          "UK_ukpga_1987_43",
          p2s("section-5", [
            {"5", "Words."},
            {"8", "Subsections (5) to (7) above shall not extend to Scotland."}
          ])
        )

      assert {"S", ["s.5(5)", "s.5(6)", "s.5(7)"]} in rows(e, :not)
    end

    test "\"(and the related repeals in Schedule 28)\" withholds the Schedule (ukpga 2008/4 s.79)" do
      e =
        read(
          "UK_ukpga_2008_4",
          p2s("section-79", [
            {"2", "Words."},
            {"3", "Words."},
            {"4",
             "Subsections (2) and (3) (and the related repeals in Schedule 28) extend to England and Wales only."}
          ])
        )

      assert {"E+W", ["s.79(2)", "s.79(3)"]} in rows(e, :only)
      assert "sch.28" in refs(e, :unread, nil)
    end

    test "\"… and subsection (2) of that section extends to Scotland only\" (ukpga 2009/26 s.115)" do
      e =
        read(
          "UK_ukpga_2009_26",
          p1(
            "section-115",
            "Subsections (1) and (3) to (5) of section 105 extend to Scotland and Northern Ireland and subsection (2) of that section extends to Scotland only."
          )
        )

      assert {"S", ["s.105(2)"]} in rows(e, :only)
      assert "s.105(3)" in refs(e, :named, "S+NI")
    end

    test "\"subsections (1) to (4) of this section shall be construed … do not extend to Northern Ireland\" is no statement (ukpga 1963/11 s.22)" do
      e =
        read(
          "UK_ukpga_1963_11",
          p1(
            "section-22",
            "In the application of this section to Northern Ireland—a “enactment” includes any enactment of the Parliament of Northern Ireland; andc subject to the preceding provisions of this subsection, subsections (1) to (4) of this section shall be construed as they are construed in their application to England and Wales, notwithstanding that the Land Compensation Act 1961 does not extend to Northern Ireland."
          )
        )

      assert refs(e, :not, "NI") == []
    end

    test "\"Sub-paragraph (1) does not extend to Northern Ireland\" in a Schedule paragraph (ukpga 2003/39 Sch.8 para 70)" do
      e =
        read(
          "UK_ukpga_2003_39",
          ~s(<Schedule id="schedule-8">#{p2s("schedule-8-paragraph-70", [{"1", "Words."}, {"2", "Sub-paragraph (1) does not extend to Northern Ireland."}])}</Schedule>)
        )

      assert {"NI", ["sch.8.para.70(1)"]} in rows(e, :not)
    end
  end

  test "seed 21 NEW: \"This Act extends to … (except that an amendment or repeal made by this Act has the same extent as the provision to which it relates)\" (ukpga 2008/20 s.3(4))" do
    e =
      read(
        "UK_ukpga_2008_20",
        p1(
          "section-3",
          "This Act extends to England and Wales, Scotland and Northern Ireland (except that an amendment or repeal made by this Act has the same extent as the provision to which it relates)."
        )
      )

    assert e.default == "E+W+S+NI"
    assert {nil, ["*"]} in rows(e, :same)
  end

  describe "seed 22 NEW" do
    test "NEW-1: a second statement qualified after its places is withheld (ukpga 1996/23 s.108(3))" do
      e =
        read(
          "UK_ukpga_1996_23",
          words([89, 90, 91]) <>
            p1(
              "section-108",
              "The provisions of this Act extend to England and Wales and, except as mentioned below, to Northern Ireland. Sections 89, 90 and 91 (consumer arbitration agreements) extend to Scotland and the provisions of Schedules 3 and 4 (consequential amendments and repeals) extend to Scotland so far as they relate to enactments which so extend, subject as follows."
            )
        )

      assert {"S", ["s.89", "s.90", "s.91"]} in rows(e, :named)
      assert "sch.3" in refs(e, :unread, nil)
      assert "sch.4" in refs(e, :unread, nil)
    end

    test "NEW-2: an exception list's item stating its own extent in brackets (ukpga 1989/38 s.30(6)(d))" do
      e =
        read(
          "UK_ukpga_1989_38",
          words([10, 27]) <>
            p2s("section-30", [
              {"5",
               "With the exception of the provisions mentioned in subsection (6), this Act does not extend to Northern Ireland."},
              {"6",
               "Those provisions are— b section 10(6); d section 27 (which extends only to Northern Ireland); and e this section."}
            ])
        )

      assert {"NI", ["s.27"]} in rows(e, :only)
      assert "s.10(6)" in refs(e, :also, "NI")
      refute "s.27" in refs(e, :also, "NI")
    end
  end
end
