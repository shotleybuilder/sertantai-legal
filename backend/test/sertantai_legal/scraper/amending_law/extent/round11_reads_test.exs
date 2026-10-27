defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Round11ReadsTest do
  @moduledoc """
  The extent reader's list misreads found by the CV-S05c census (classes
  A–F, `backend/data/experiments/cv-s05c-shape-mining/run-01/confirmed.md`
  and `overreach.md`), each on its law's real wording (CV-S05 round 11).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns), do: Enum.map_join(ns, &p1("section-#{&1}", "Words."))

  defp part(n, sections), do: ~s(<Part id="part-#{n}">#{words(sections)}</Part>)

  defp chapters(n, chs),
    do:
      ~s(<Part id="part-#{n}">) <>
        Enum.map_join(chs, fn {c, ss} ->
          ~s(<Chapter id="part-#{n}-chapter-#{c}">#{words(ss)}</Chapter>)
        end) <>
        "</Part>"

  describe "A: \"In Part N— (a) X extends to P, (b) Y extends to Q …\": every item read" do
    test "Infrastructure Act 2015 s.56(6)" do
      e =
        read(
          "UK_ukpga_2015_7",
          words([38, 39, 40, 41, 42, 43, 45, 48, 49, 50]) <>
            p1(
              "section-56",
              "In Part 6 (energy)—a sections 38 and 39, sections 41 and 42, sections 51 to 53 and Schedules 6 and 7 extend to England and Wales and Scotland,b section 40 and section 49 extend to England and Wales, Scotland and Northern Ireland, andc sections 43 to 48 and section 50 extend to England and Wales only."
            )
        )

      assert Extent.of(e, "s.38") == "E+W+S"
      assert Extent.of(e, "s.40") == "E+W+S+NI"
      assert Extent.of(e, "s.45") == "E+W"
      assert Extent.of(e, "s.50") == "E+W"
    end

    test "Agriculture Act 2020 s.24-style: three items, the last with its own \"only\" (ukpga 2020/16 s.24)" do
      e =
        read(
          "UK_ukpga_2020_16",
          words(12..15) <>
            p1(
              "section-24",
              "In Part 2—a section 12 extends to England and Wales, Scotland and Northern Ireland,b sections 13 and 14 extend to England and Wales and Scotland only, andc section 15 extends to Northern Ireland only."
            )
        )

      assert Extent.of(e, "s.12") == "E+W+S+NI"
      assert Extent.of(e, "s.13") == "E+W+S"
      assert Extent.of(e, "s.15") == "NI"
    end

    test "\"andb\" glued (Climate Change Act-style, ukpga 2006/16 s.108(3))" do
      e =
        read(
          "UK_ukpga_2006_16",
          p1("section-1", "Words.") <>
            p1("section-108", "This Act extends to England and Wales only, subject as follows.") <>
            chapters(8, [{2, [87, 88]}, {3, [98, 99]}]) <>
            p1(
              "section-109",
              "In Part 8 (flexible administrative arrangements)—a Chapter 2 of Part 8 (powers to reform agricultural etc. bodies) extends also to Scotland and Northern Ireland, andb Chapter 3 of Part 8 (financial assistance) extends also to Northern Ireland."
            )
        )

      assert Extent.of(e, "s.87") == "E+W+S+NI"
      assert Extent.of(e, "s.98") == "E+W+NI"
    end

    test "\"In this Act— (a) Part I extends …, (b) Part II extends to Scotland only\" (ukpga 1999/9 s.17)" do
      e =
        read(
          "UK_ukpga_1999_9",
          part("I", 1..2) <>
            part("II", 12..13) <>
            p1(
              "section-17",
              "In this Act—a Part I extends to England and Wales only,b Part II extends to Scotland only, andc section 15 and Schedules 3 and 4 have the same extent as the enactments which they amend or repeal."
            )
        )

      assert Extent.of(e, "s.1") == "E+W"
      assert Extent.of(e, "s.12") == "S"
    end
  end

  describe "B and F: an item's own exception taken out of it" do
    test "\"Part 1, apart from sections 17 and 18\" (ukpga 2020/21 s.56)" do
      e =
        read(
          "UK_ukpga_2020_21",
          part(1, 16..19) <>
            p1(
              "section-56",
              "The following provisions of this Act extend to England and Wales only—a Part 1, apart from sections 17 and 18;b section 40."
            )
        )

      assert Extent.of(e, "s.16") == "E+W"
      assert Extent.of(e, "s.19") == "E+W"
      refute Extent.of(e, "s.17") == "E+W"
    end

    test "\"Part 3, except for section 163(3)\": the Part read, the section with the excepted subsection withheld (ukpga 2003/43 s.202)" do
      e =
        read(
          "UK_ukpga_2003_43",
          p1("section-1", "This Act extends to England and Wales only.") <>
            part(3, [150, 163, 164]) <>
            p1(
              "section-202",
              "The following provisions also extend to Scotland—a sections 124 and 125;b Part 3, except for section 163(3);c sections 185, 187 and 188 and Schedule 12."
            )
        )

      assert Extent.of(e, "s.150") == "E+W+S"
      assert Extent.of(e, "s.164") == "E+W+S"
      refute Extent.of(e, "s.163(3)") == "E+W+S"
    end

    test "\"(with the exception of …)\" in brackets with brackets inside (ukpga 2004/20 s.198)" do
      e =
        read(
          "UK_ukpga_2004_20",
          chapters(1, [{3, [51, 59, 60]}]) <>
            part(3, [133, 151]) <>
            p1(
              "section-198",
              "The following provisions of this Act do not extend to Northern Ireland—a Chapter 3 of Part 1 (with the exception of section 59 and paragraphs 1, 5, 6, 8, 10(1) and (2) and 11 of Schedule 14);b so much of Part 2 as amends the 1989 Act;c sections 82, 90, 91 and 100; andd Part 3 (with the exception of section 151(5))."
            )
        )

      assert {:not, "NI", refs} = Enum.find(e.lists, &match?({:not, "NI", _}, &1))
      assert "s.51" in refs and "s.60" in refs and "s.133" in refs
      refute "s.59" in refs
      refute "s.151" in refs
    end

    test "\"Part 12, except sections 166 and 171 to 174\" (ukpga 2014/12 s.184)" do
      e =
        read(
          "UK_ukpga_2014_12",
          part(12, [155, 166, 170, 172]) <>
            p1(
              "section-184",
              "The following provisions extend to England and Wales, Scotland and Northern Ireland—a section 111;i Part 12, except sections 166 and 171 to 174;j section 180."
            )
        )

      assert Extent.of(e, "s.155") == "E+W+S+NI"
      assert Extent.of(e, "s.170") == "E+W+S+NI"
      refute Extent.of(e, "s.166") == "E+W+S+NI"
      refute Extent.of(e, "s.172") == "E+W+S+NI"
    end

    test "\"this Part, other than section 204 (and Schedule 21)\" (ukpga 2022/32 s.207)" do
      e =
        read(
          "UK_ukpga_2022_32",
          ~s(<Part id="part-6">) <>
            words([202, 204, 205]) <>
            p1(
              "section-207",
              "The following provisions extend to England and Wales, Scotland and Northern Ireland— a section 1; b section 202; c this Part, other than section 204 (and Schedule 21)."
            ) <> "</Part>"
        )

      assert Extent.of(e, "s.205") == "E+W+S+NI"
      refute Extent.of(e, "s.204") == "E+W+S+NI"
    end

    test "\"(excluding paragraph 5(3) of Schedule 8 and section 91)\": a bracket with brackets inside (ukpga 2012/9 s.119)" do
      e =
        read(
          "UK_ukpga_2012_9",
          chapters(5, [{3, [87, 90, 91]}]) <>
            p1(
              "section-119",
              "The following provisions extend to England and Wales and Northern Ireland only—a Part 2 of Schedule 1,b Chapter 3 of Part 5 (excluding paragraph 5(3) of Schedule 8 and section 91),d any provision which extends to England and Wales and Northern Ireland only by virtue of subsection (7)."
            )
        )

      assert {:only, "E+W+NI", refs} = Enum.find(e.lists, &match?({:only, "E+W+NI", _}, &1))
      assert "s.87" in refs
      refute "s.91" in refs
      refute "sch.8.para.5(3)" in refs
    end

    test "\"Part 2 (including …) but excluding sections 60 and 61, Schedule 5 and Part 2 of Schedule 6\" (ukpga 2007/27 s.93)" do
      e =
        read(
          "UK_ukpga_2007_27",
          part(2, [44, 60, 61, 62]) <>
            p1(
              "section-93",
              "The following provisions extend to England and Wales and Northern Ireland only—b Part 2 (including Schedules 3 and 4 and Part 1 of Schedule 6) but excluding sections 60 and 61, Schedule 5 and Part 2 of Schedule 6;c section 75(2) and (3)."
            )
        )

      assert {:only, "E+W+NI", refs} = Enum.find(e.lists, &match?({:only, "E+W+NI", _}, &1))
      assert "s.44" in refs and "s.62" in refs and "sch.3" in refs
      refute "s.60" in refs
      refute "sch.5" in refs
      refute "sch.6.pt.2" in refs
    end

    test "\"this Part, except— (i) sections 82 and 83 …\": the excepted never also in the list (ukpga 2000/19 s.87)" do
      e =
        read(
          "UK_ukpga_2000_19",
          ~s(<Part id="part-4">) <>
            words([82, 83, 84]) <>
            p1(
              "section-87",
              "The following provisions of this Act extend to Northern Ireland—c section 73;g this Part, except—i sections 82 and 83 and Schedule 8; andii so much of this Part as gives effect to any repeal other than the repeals mentioned in subsection (3)."
            ) <> "</Part>"
        )

      assert {:named, "NI", refs} = Enum.find(e.lists, &match?({:named, "NI", _}, &1))
      assert "s.84" in refs
      refute "s.82" in refs
    end
  end

  describe "C: plain provisions read, their qualified companion withheld" do
    test "\"Parts 1 and 2 of Schedule 7 and section 73 so far as relating to those Parts\" (ukpga 2007/27 s.93)" do
      e =
        read(
          "UK_ukpga_2007_27",
          p1(
            "section-93",
            "The following provisions extend to England and Wales only—a section 78(1) and (2);b section 87; andd Parts 1 and 2 of Schedule 7 and section 73 so far as relating to those Parts."
          )
        )

      assert {:only, "E+W", refs} = Enum.find(e.lists, &match?({:only, "E+W", _}, &1))
      assert "sch.7.pt.1" in refs and "sch.7.pt.2" in refs
      refute "s.73" in refs
      assert Enum.any?(e.lists, &match?({:unread, nil, ["s.73"]}, &1))
    end

    test "\"section 6, so far as relating to paragraphs 81, 95 and 96 of Schedule 1, and those paragraphs\" (ukpga 2017/3 s.182)" do
      e =
        read(
          "UK_ukpga_2017_3",
          p1(
            "section-182",
            "The following provisions extend to England and Wales, Scotland and Northern Ireland—a section 6, so far as relating to paragraphs 81, 95 and 96 of Schedule 1, and those paragraphs;b section 8(11)."
          )
        )

      assert {:named, "E+W+S+NI", refs} = Enum.find(e.lists, &match?({:named, "E+W+S+NI", _}, &1))
      assert "sch.1.para.81" in refs and "s.8(11)" in refs
      refute "s.6" in refs
    end
  end

  describe "D: a wholly qualified item withheld, never dropped to the default" do
    test "\"section 154 and Schedules 7, 8 and 9 so far as they relate to …\" (ukpga 1980/43 s.155)" do
      e =
        read(
          "UK_ukpga_1980_43",
          p1(
            "section-155",
            "The following provisions of this Act extend to Northern Ireland—a sections 83(3), 90 and 91 and this section; andb section 154 and Schedules 7, 8 and 9 so far as they relate to an enactment extending to Northern Ireland."
          )
        )

      assert {:named, "NI", refs} = Enum.find(e.lists, &match?({:named, "NI", _}, &1))
      assert "s.90" in refs
      refute "s.154" in refs
      assert Enum.any?(e.lists, &match?({:unread, nil, ["s.154" | _]}, &1))
    end
  end

  describe "E: one-offs" do
    test "\"This section, and the following provisions only of this Act, extend to Northern Ireland, that is to say,—\" (ukpga 1972/11 s.30)" do
      e =
        read(
          "UK_ukpga_1972_11",
          words(1..6) <>
            p1(
              "section-30",
              "This section, and the following provisions only of this Act, extend to Northern Ireland, that is to say,—a sections 1 to 6 and Schedules 1 and 2;b sections 13 and 17;e section 23 and paragraph 2 of Schedule 5;ee section 25."
            )
        )

      assert {:named, "NI", refs} = Enum.find(e.lists, &match?({:named, "NI", _}, &1))
      assert "s.30" in refs and "s.13" in refs and "sch.2" in refs and "s.25" in refs
    end

    test "\"… shall extend to the whole of the United Kingdom, namely—\" (ukpga 1989/15 s.194)" do
      e =
        read(
          "UK_ukpga_1989_15",
          p1(
            "section-194",
            "This section and the following provisions of this Act shall extend to the whole of the United Kingdom, namely—a Schedules 2 and 5 and sections 4, 13 and 23 so far as relating to any scheme under either of those Schedules;b section 95; andc any amendment or repeal by this Act of any provision contained in the Parliamentary Commissioner Act 1967."
          )
        )

      assert {:named, "E+W+S+NI", refs} = Enum.find(e.lists, &match?({:named, "E+W+S+NI", _}, &1))
      assert "s.194" in refs and "s.95" in refs
    end

    test "a \"za\" item first: the items after it kept (ukpga 1994/21 s.68)" do
      e =
        read(
          "UK_ukpga_1994_21",
          p1(
            "section-68",
            "The following provisions of this Act do not extend to Scotland, that is to say—za sections 4A to 4C and Schedules 1A and 1B;a sections 49 and 50 and Schedule 7; andb so much of Schedules 9 and 11 as relates to enactments extending to England and Wales only."
          )
        )

      assert {:not, "S", refs} = Enum.find(e.lists, &match?({:not, "S", _}, &1))
      assert "s.49" in refs and "sch.7" in refs and "sch.1A" in refs
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

    test "a same-extent list's Parts and Chapters read, its item's exception taken out (ukpga 2009/23 s.323(2))" do
      e =
        read(
          "UK_ukpga_2009_23",
          part(1, 1..2) <>
            part(2, 41..42) <>
            chapters(7, [{3, [215, 216]}]) <>
            p1(
              "section-323",
              "The amendment or repeal of any enactment (including an enactment comprised in subordinate legislation) by, or in consequence of, the following provisions of this Act has the same extent as the enactment amended or repealed—a Part 1 (the MMO);b Part 2 (exclusive economic zone, UK marine area and Welsh zone), other than paragraph 2 of Schedule 4;c Chapter 3 of Part 7 (migratory and freshwater fish);g Schedule 14 (minor and consequential amendments relating to IFC authorities)."
            )
        )

      assert {:same, nil, refs} = Enum.find(e.lists, &match?({:same, nil, _}, &1))
      assert "s.1" in refs and "s.41" in refs and "s.215" in refs and "sch.14" in refs
      refute "sch.4.para.2" in refs
    end

    test "\"in Chapter 1 of Part 6, sections 165, 166 and 186\": those sections, not the Chapter (ukpga 2009/23 s.323(4)(f))" do
      e =
        read(
          "UK_ukpga_2009_23",
          p1("section-1", "This Act extends to England and Wales only.") <>
            chapters(6, [{1, [150, 165, 166]}]) <>
            p1(
              "section-323",
              "The following provisions also extend to Scotland—a Part 3 (marine planning);f in Chapter 1 of Part 6, sections 165, 166 and 186 (powers of IFC officers etc)."
            )
        )

      assert Extent.of(e, "s.165") == "E+W+S"
      refute Extent.of(e, "s.150") == "E+W+S"
    end
  end

  describe "\"In Schedule N— (a) …\" (the census's empty leads)" do
    test "\"; andb\" run in: item (b) read too (SI 2014/1638 reg.3(2))" do
      e =
        read(
          "UK_uksi_2014_1638",
          p1(
            "regulation-3",
            "In Schedule 13—a the amendments made by paragraphs 16, 20 and 30 extend to Scotland only; andb the amendments made by paragraphs 11 and 14 extend to England and Wales only."
          )
        )

      assert {:only, "S", ["sch.13.para.16", "sch.13.para.20", "sch.13.para.30"]} in e.lists
      assert {:only, "E+W", ["sch.13.para.11", "sch.13.para.14"]} in e.lists
    end

    test "a bare Part is the Schedule's (ukpga 2020/22 s.53(2))" do
      e =
        read(
          "UK_ukpga_2020_22",
          part(1, [1]) <>
            p1(
              "section-53",
              "In Schedule 8—a Part 1 extends to Scotland only;b Part 2 extends to England and Wales only;c Part 3 extends to Northern Ireland only."
            )
        )

      assert {:only, "S", ["sch.8.pt.1"]} in e.lists
      assert {:only, "NI", ["sch.8.pt.3"]} in e.lists
      refute Extent.of(e, "s.1") == "S"
    end
  end

  describe "a Schedule paragraph's own extent (the census's unread tail)" do
    defp sch_para(sch, para, text),
      do:
        ~s(<Schedule id="schedule-#{sch}"><Pnumber>#{sch}</Pnumber><ScheduleBody>) <>
          ~s(<P1 id="schedule-#{sch}-paragraph-#{para}"><Pnumber>#{para}</Pnumber><P1para><Text>#{text}</Text></P1para></P1>) <>
          "</ScheduleBody></Schedule>"

    test "\"This paragraph does not extend to Northern Ireland\", \"… extends only to England and Wales\" (ukpga 2003/39 Sch.8)" do
      e =
        read(
          "UK_ukpga_2003_39",
          p1("section-1", "This Act extends to England and Wales, Scotland and Northern Ireland.") <>
            sch_para(8, 27, "This paragraph does not extend to Northern Ireland.") <>
            sch_para(9, 13, "This paragraph extends only to England and Wales.")
        )

      assert {:not, "NI", ["sch.8.para.27"]} in e.lists
      assert {:only, "E+W", ["sch.9.para.13"]} in e.lists
      assert Extent.of(e, "sch.8.para.27") == "E+W+S"
    end

    test "never with more after the places (ukpga 2006/16 Sch.11 para 97)" do
      e =
        read(
          "UK_ukpga_2006_16",
          sch_para(
            11,
            97,
            "This paragraph extends only to England and Wales and to the territorial waters adjacent to England and Wales."
          )
        )

      refute Enum.any?(e.lists, &match?({_, _, ["sch.11.para.97"]}, &1))
    end
  end
end
