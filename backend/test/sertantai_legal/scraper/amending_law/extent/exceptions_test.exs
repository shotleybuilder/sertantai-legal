defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ExceptionsTest do
  @moduledoc """
  Exceptions in an extent clause, read whole by the extent reader on each
  law's real wording: a Part's extent with its exceptions after it, an
  exception list's items extending there too, an item's own exception
  taken out of it, and the default an exception clause leaves.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{ExceptionList, Excepting, Units}

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns, kind \\ "section"), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))
  defp part(n, ids, kind \\ "section"), do: ~s(<Part id="part-#{n}">#{words(ids, kind)}</Part>)

  defp chapters(n, chs),
    do:
      ~s(<Part id="part-#{n}">) <>
        Enum.map_join(chs, fn {c, ss} ->
          ~s(<Chapter id="part-#{n}-chapter-#{c}">#{words(ss)}</Chapter>)
        end) <>
        "</Part>"

  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  defp refs(e, kind, place),
    do: for({^kind, ^place, refs} <- e.lists ++ e.applies, r <- refs, do: r)

  defp p2s(id, subs),
    do:
      ~s(<P1 id="#{id}">) <>
        Enum.map_join(subs, fn {n, text} ->
          ~s(<P2 id="#{id}-#{n}"><Pnumber>#{n}</Pnumber><P2para><Text>#{text}</Text></P2para></P2>)
        end) <> "</P1>"

  defp unread?(e, ref),
    do: Enum.any?(e.lists, fn {k, _, refs} -> k == :unread and ref in refs end)

  describe "a Part's extent with its exceptions after it (ERRA 2013 s.102)" do
    defp erra,
      do:
        part(2, 7..8) <>
          part(3, 25..26) <>
          ~s(<Part id="part-6">) <>
          Enum.map_join(91..93, &p1("section-#{&1}", "Words.")) <>
          ~s|<P1 id="section-102"><P1para><P2 id="section-102-3"><Pnumber>3</Pnumber><P2para><Text>Part 2 extends only to England and Wales and Scotland, except that the following provisions of Part 2 extend also to Northern Ireland—a section 8(3);b paragraph 11 of Schedule 1.</Text></P2para></P2><P2 id="section-102-4"><Pnumber>4</Pnumber><P2para><Text>Part 3 extends to England and Wales, Scotland and Northern Ireland, except as follows— (a) paragraphs 15 to 44 of Schedule 6 extend only to England and Wales and Scotland; (b) paragraphs 52 to 68 of that Schedule extend only to England and Wales.</Text></P2para></P2><P2 id="section-102-8"><Pnumber>8</Pnumber><P2para><Text>This Part extends to England and Wales, Scotland and Northern Ireland except that— (a) section 92 extends only to England and Wales and Scotland.</Text></P2para></P2></P1para></P1></Part>|

    test "the lead read for the Part, less the provisions its exceptions set" do
      e = read("UK_ukpga_2013_24", erra())

      assert {:only, "E+W+S", ["s.7", "s.8"]} in e.lists
      assert {:named, "E+W+S+NI", ["s.25", "s.26"]} in e.lists
      assert {:named, "E+W+S+NI", ["s.91", "s.93", "s.102"]} in e.lists
      assert {:only, "E+W", ["sch.6.para.52..sch.6.para.68"]} in e.lists
    end

    test "an exception naming a Schedule paragraph outranks its introducing section's Part" do
      e = %{
        read("UK_ukpga_2013_24", erra())
        | introduced_by: %{"sch.6" => "s.26", "sch.1" => "s.7"}
      }

      assert Extent.of(e, "sch.6.para.15") == "E+W+S"
      assert Extent.of(e, "sch.6.para.1") == "E+W+S+NI"
      assert Extent.of(e, "s.92") == "E+W+S"
      assert Extent.of(e, "s.8(3)") == "E+W+S+NI"
      assert Extent.of(e, "sch.1.para.11") == "E+W+S+NI"
      assert Extent.of(e, "sch.1.para.2") == "E+W+S"
    end

    test "a qualified exception leaves the lead unread" do
      doc =
        ExtentDoc.doc(
          "UK_ukpga_2013_24",
          part(2, 7..8) <>
            p1(
              "section-102",
              "Part 2 extends only to England and Wales and Scotland, except that— (a) section 8 also extends to Northern Ireland so far as it relates to the 1974 Act."
            )
        )

      assert Excepting.leads(Units.unit_sentences(doc), doc) == []
    end
  end

  test "\"with the exception of— … (b) any provision amending … an enactment which does not so extend\" (CPA 1987 s.49(1))" do
    e =
      read(
        "UK_ukpga_1987_43",
        part(1, 1..2) <>
          ~s(<Part id="part-5">) <>
          p1("section-36", "Words.") <>
          p1(
            "section-49",
            "This Act shall extend to Northern Ireland with the exception of— (a) the provisions of Part 1; (b) any provision amending or repealing an enactment which does not so extend; and (c) any other provision so far as it has effect for the purposes of, or in relation to, a provision falling within paragraph (a) or (b) above."
          ) <> "</Part>"
      )

    assert {:same, nil, ["*"]} in e.lists
    assert Extent.of(e, "s.36") == :same
    assert Extent.of(e, "s.1") == "E+W+S"
  end

  test "\"Part 2 (…), excluding section 35 but including Schedules 1 to 9, extends to England and Wales only\" (Civil Partnership Act 2004 s.262(1))" do
    e =
      read(
        "UK_ukpga_2004_33",
        part(2, 34..36) <>
          ~s(<Part id="part-8">) <>
          p1(
            "section-262",
            "Part 2 (civil partnership: England and Wales), excluding section 35 but including Schedules 1 to 9, extends to England and Wales only."
          ) <> "</Part>"
      )

    assert {:only, "E+W", ["s.34", "s.36" | schedules]} =
             Enum.find(e.lists, &match?({:only, _, _}, &1))

    assert schedules == Enum.map(1..9, &"sch.#{&1}")
    assert Extent.of(e, "s.35") == nil
  end

  describe "an item's own exception taken out of it" do
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

  describe "an exception list's items as statements" do
    test "an exception list's items are never \"not\" statements of their own (ukpga 1976/55 s.27; 1995/45 s.18)" do
      e =
        read(
          "UK_ukpga_1976_55",
          p1(
            "section-27",
            "Except for the following provisions, namely—a sections ... 15, 26(1) and (2) and this section;b section 7 and Schedule 3 so far as they relate to enactments (within the meaning of that section) that extend to Northern Ireland; andc Part I of Schedule 4 and, so far as it relates to that Part, section 26(3), this Act does not extend to Northern Ireland."
          )
        )

      refute Enum.any?(e.lists, &match?({:not, "NI", ["s.26(3)"]}, &1))

      e =
        read(
          "UK_ukpga_1995_45",
          p1(
            "section-18",
            "This Act, except—a this section;b subsections (1) to (6) of section 11;c paragraphs 1 to 3, 6, 7, 23 and 30 of Schedule 5 and section 17(1) and (2) so far as relating to those paragraphs; andd Schedule 6 and section 17(5) so far as relating to the repeals of paragraph 1 of Schedule 5 to the Fair Trading Act 1973, does not extend to Northern Ireland."
          )
        )

      refute Enum.any?(e.lists, &match?({:not, "NI", ["sch.6"]}, &1))
    end

    test "\"This Act, except for— a …, b …, c so much of …, does not extend to NI\": comma-separated items read (ukpga 1994/21 s.68)" do
      e =
        read(
          "UK_ukpga_1994_21",
          p1(
            "section-68",
            "This Act, except for—a sections 7 to 9, 12 and 13 and Schedule 2,b sections 20 and 21 and Schedule 4,c so much of Schedule 1 as amends the Parliamentary Commissioner Act 1967,d so much of Schedule 9 as amends any enactment that extends to Northern Ireland,e the repeal, by virtue of their inclusion in Schedule 11, of—i the entries relating to the Corporation in the Statutory Corporations (Financial Provisions) Act 1975, does not extend to Northern Ireland."
          )
        )

      assert {:also, "NI", refs} = Enum.find(e.lists, &match?({:also, "NI", _}, &1))
      assert "s.7..s.9" in refs and "s.20" in refs and "sch.4" in refs
      refute "sch.11" in refs
      refute "sch.1" in refs
    end

    test "an exception list's qualified item is no statement of its own (HSWA s.84(1))" do
      e =
        read(
          "UK_ukpga_1974_37",
          part("I", [1, 15]) <>
            p1(
              "section-84",
              "This Act, except—a Part I and this Part so far as may be necessary to enable regulations under section 15 or 30 to be made and operate for the purpose mentioned in paragraph 2 of Schedule 3; andb paragraphs . . . 3 of Schedule 9, does not extend to Northern Ireland."
            )
        )

      assert e.default == "E+W+S"
      refute unread?(e, "s.15")
      refute Enum.any?(e.lists, &match?({:not, "NI", _}, &1))
    end
  end

  describe "an exception list's items extend there too" do
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
      # (a qualified exception item keeps the default)
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

    test "\"This Act, except section 63 and except as provided by section 189, does not extend to Northern Ireland\" (ukpga 1972/20 s.209)" do
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
      # ("subsections (1) to (6) of section 11" is those, never all of s.11)
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

  describe "the default of an exception clause" do
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
      assert ExceptionList.statements(
               "Apart from sections 39 and 45 and subject to subsection (1), the preceding sections of this Act shall not extend to Northern Ireland."
             ) == []
    end
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

  test "\"section 153 except subsection (1)(k) and (m)\": the section read, its excepted paragraphs narrowed back (ukpga 1990/43 s.164; Decision 3, 2026-11-09)" do
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
    assert "s.153" in refs(e, :also, "NI")
    refute "s.153" in refs(e, :unread, nil)
    refute "s.164(1)(k)" in refs(e, :unread, nil)
  end

  describe "the clause's own section leading an exception list" do
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

  describe "an exception list set out in another subsection" do
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

    test "an exception list's item stating its own extent in brackets (ukpga 1989/38 s.30(6)(d))" do
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
