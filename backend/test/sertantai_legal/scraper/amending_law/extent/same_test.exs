defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.SameTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Same, Units}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

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

  defp same(law, body) do
    doc = ExtentDoc.doc(law, body)
    Same.amendments_same(Units.unit_sentences(doc), doc)
  end

  test "every amendment the law makes: \"*\"" do
    assert same(
             "UK_ukpga_2015_20",
             ExtentDoc.p1(
               "section-114",
               "Except as provided by subsections (2) and (3), a repeal, revocation or other amendment made by this Act has the same extent as the provision repealed, revoked or amended."
             )
           ) == [{:same, nil, ["*"]}]
  end

  test "made by the provisions in Parts named: those Parts' (uksi 2023/1071, round 4 N-A)" do
    assert same(
             "UK_uksi_2023_1071",
             ExtentDoc.p1(
               "regulation-1",
               "Any amendment or revocation made by the provisions in Parts 2 and 3 has the same extent as the provision amended or revoked."
             ) <>
               ~s{<Part id="part-2">} <>
               ExtentDoc.p1("regulation-107", "Schedule 1 has effect.") <> "</Part>"
           ) == [{:same, nil, ["reg.107"]}]
  end

  test "the same extent, except paragraphs that extend to Scotland only (SI 2014/469, round 3 E)" do
    assert [{:same, nil, ["sch.3"]}, {:only, "S", [_ | _]}] =
             same(
               "UK_uksi_2014_469",
               ExtentDoc.p1(
                 "article-1",
                 "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that the amendments made by paragraphs 11 to 13 of that Schedule extend to Scotland only."
               )
             )
  end

  test "named provisions with the same extent as the provisions amended (1996/18 s.244)" do
    assert same(
             "UK_ukpga_1996_18",
             ExtentDoc.p1(
               "section-244",
               "Sections 240 and 242 and Schedule 1 have the same extent as the provisions amended."
             )
           ) == [{:same, nil, ["s.240", "s.242", "sch.1"]}]
  end

  test "\"A provision of these Regulations that amends …\" and \"any part of the UK to which the amended enactment extends\" (CV-S05 round 6)" do
    assert same(
             "UK_uksi_2025_82",
             ExtentDoc.p1(
               "regulation-1",
               "A provision of these Regulations that amends or revokes an enactment has the same extent as the enactment amended or revoked unless otherwise specified."
             )
           ) == [{:same, nil, ["*"]}]

    assert same(
             "UK_uksi_2012_2404",
             ExtentDoc.p1(
               "article-4",
               "An amendment in Schedule 2 or 3 extends to any part of the United Kingdom to which the amended enactment extends."
             )
           ) == [{:same, nil, ["sch.2", "sch.3"]}]
  end

  describe "same-extent statements read whole" do
    test "\"Any amendment or repeal by this Act of an enactment which extends to … has the same extent as that enactment but, save as aforesaid, …\" (LGA 1985 s.106(2))" do
      e =
        read(
          "UK_ukpga_1985_51",
          p1("section-84", "Words.") <>
            p1(
              "section-106",
              "Any amendment or repeal by this Act of an enactment which extends to Scotland or Northern Ireland has the same extent as that enactment but, save as aforesaid, this Act extends to England and Wales only."
            )
        )

      assert {e.default, e.lists} == {"E+W", [{:same, nil, ["*"]}]}
      assert Extent.of(e, "s.84") == :same
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

    test "\"which inserts Part 4A into the Energy Act 2008\" is a description, not another law's provision (ukpga 2009/23 s.323(2))" do
      e =
        read(
          "UK_ukpga_2009_23",
          words([311, 314]) <>
            p1(
              "section-323",
              "The amendment or repeal of any enactment (including an enactment comprised in subordinate legislation) by, or in consequence of, the following provisions of this Act has the same extent as the enactment amended or repealed—f in Part 10—i sections 311 and 312 (Natural England);iii section 314 (which inserts Part 4A into the Energy Act 2008 (c. 32));g Schedule 14 (minor and consequential amendments relating to IFC authorities)."
            )
        )

      assert {:same, nil, refs} = Enum.find(e.lists, &match?({:same, nil, _}, &1))
      assert "s.314" in refs and "s.311" in refs
    end

    test "a same-extent item with its own \"other than\" (Infrastructure Act 2015 s.56(2))" do
      e =
        read(
          "UK_ukpga_2015_7",
          part(1, [1, 16, 17]) <>
            p1(
              "section-56",
              "Part 1 (strategic highways companies) extends to England and Wales only, save that—a sections 16 and 18 to 20 extend to England and Wales, Scotland and Northern Ireland, andb an amendment or repeal made by Part 1, other than the amendment made by section 17(7), has the same extent as the provision to which it relates."
            )
        )

      assert {:same, nil, refs} = Enum.find(e.lists, &match?({:same, nil, _}, &1))
      assert "s.1" in refs
      refute "s.17" in refs
    end

    test "\"In Part 5— (a) an amendment or repeal has the same extent …\": the amendments that Part makes (ukpga 2015/7 s.56(6))" do
      e =
        read(
          "UK_ukpga_2015_7",
          part(1, [1]) <>
            part(5, [29, 31]) <>
            p1(
              "section-56",
              "In Part 5 (planning, land and buildings)—a an amendment or repeal has the same extent as the provision to which it relates, andb sections 30(2) to (4) and 33(2) extend to England and Wales only."
            )
        )

      assert {:same, nil, refs} = Enum.find(e.lists, &match?({:same, nil, _}, &1))
      assert "s.29" in refs and "s.31" in refs
      refute "s.1" in refs
      refute "*" in refs
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

    test "\"This Act extends to … (except that an amendment or repeal made by this Act has the same extent as the provision to which it relates)\" (ukpga 2008/20 s.3(4))" do
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
  end

  describe "\"or\"-lists in same-extent subjects" do
    defp same(e),
      do: e.lists |> Enum.filter(&match?({:same, nil, _}, &1)) |> Enum.flat_map(&elem(&1, 2))

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

  describe "a same-extent item" do
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
end
