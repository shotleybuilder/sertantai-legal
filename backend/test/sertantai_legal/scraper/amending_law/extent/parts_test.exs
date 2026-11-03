defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.PartsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Parts
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

  defp refs(e, kind, place),
    do: for({^kind, ^place, refs} <- e.lists ++ e.applies, r <- refs, do: r)

  setup do
    p1 = &ExtentDoc.p1/2

    doc =
      ExtentDoc.doc("UK_ukpga_1990_1", """
      <Part id="part-I">#{p1.("section-1", "One.")}#{p1.("section-2", "Two.")}</Part>
      <Part id="part-II">#{p1.("section-3", "Three.")}</Part>
      <Part id="part-3">#{p1.("section-4", "Four.")}</Part>
      """)

    %{doc: doc}
  end

  test "the sections of the Parts named", %{doc: doc} do
    assert Parts.parts("Parts I and II", doc, nil) == ["s.1", "s.2", "s.3"]
  end

  test "a Part named in either numeral", %{doc: doc} do
    assert Parts.parts("Part 1", doc, nil) == ["s.1", "s.2"]
    assert Parts.parts("Part III", doc, nil) == ["s.4"]
  end

  test "every Part named (\"Part 3 and Part 4\": SI 2022/1037)", %{doc: doc} do
    assert Parts.parts("An amendment made by Part 1 and Part 3", doc, nil) == [
             "s.1",
             "s.2",
             "s.4"
           ]
  end

  test "this Part: the one holding the clause", %{doc: doc} do
    assert Parts.parts("this Part", doc, "s.3") == ["s.3"]
  end

  test "never a Chapter's Part", %{doc: doc} do
    assert Parts.parts("Chapter 3 of Part 1", doc, nil) == []
  end

  describe "Chapters (CV-S05 NEW-A)" do
    setup do
      p1 = &ExtentDoc.p1/2

      doc =
        ExtentDoc.doc("UK_ukpga_2013_32", """
        <Part id="part-1">#{p1.("section-1", "One.")}</Part>
        <Part id="part-2"><Chapter id="part-2-chapter-1">#{p1.("section-2", "Two.")}#{p1.("section-3", "Three.")}</Chapter><Chapter id="part-2-chapter-2">#{p1.("section-4", "Four.")}</Chapter></Part>
        <Part id="part-3"><Chapter id="part-3-chapter-1">#{p1.("section-5", "Five.")}</Chapter><Chapter id="part-3-chapter-2">#{p1.("section-6", "Six.")}#{p1.("section-7", "Seven.")}</Chapter></Part>
        """)

      %{doc: doc}
    end

    test "a Chapter of a Part: its sections, never the whole Part", %{doc: doc} do
      assert Parts.parts("Chapter 1 of Part 2", doc, nil) == ["s.2", "s.3"]
      assert Parts.parts("Chapters 1 and 2 of Part II", doc, nil) == ["s.2", "s.3", "s.4"]
    end

    test "a Chapter of this Part: the Part holding the clause", %{doc: doc} do
      assert Parts.parts("Chapter 2 of this Part", doc, "s.5") == ["s.6", "s.7"]
    end

    test "a bare Chapter takes the Part named before it; that Part, that Part" do
      assert Parts.qualify_chapters(
               "b in Part 2— i Chapter 1 (general considerations), ii Chapter 2, iv section 56"
             ) ==
               "b in Part 2— i Chapter 1 of Part 2 (general considerations), ii Chapter 2 of Part 2, iv section 56"

      assert Parts.qualify_chapters("h Chapter 1 of Part 3; i Chapter 2 of that Part") ==
               "h Chapter 1 of Part 3; i Chapter 2 of Part 3"

      # never a Schedule's Part
      assert Parts.qualify_chapters("Part 2 of Schedule 1; Chapter 4") ==
               "Part 2 of Schedule 1; Chapter 4"
    end
  end

  describe "a Part or Chapter named in a statement, read whole" do
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

    test "\"… but, subject to that, this Part of this Act extends to England and Wales only\" (ukpga 1980/65 s.47(8))" do
      e =
        read(
          "UK_ukpga_1980_65",
          ~s(<Part id="part-V">#{words([28, 32, 46])}#{p1("section-47", "Sections 32 and 46 above extend to Scotland only but, subject to that, this Part of this Act extends to England and Wales only.")}</Part>)
        )

      assert {"S", ["s.32", "s.46"]} in rows(e, :only)
      assert {"E+W", ["s.28", "s.47"]} in rows(e, :only)
    end

    test "\"Chapters 1 to 5 of Part 8\" after \"in Part 8 (…),\" never reaches Chapter 6 (ukpga 2009/23 s.323)" do
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
  end

  describe "a Schedule's Part" do
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
end
