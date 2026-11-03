defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.LetteredItemsTest do
  @moduledoc """
  Extent statements set out as lettered items ("In Part N— (a) …; (b) …",
  "the following provisions … namely— …", a verb coming after the list):
  every item read, by the extent reader on each law's real wording; and
  a commencement's lettered list never read as extent.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
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

  defp p2s(id, texts),
    do:
      ~s|<P1 id="#{id}"><P1para>| <>
        Enum.map_join(texts, fn {n, t} ->
          ~s|<P2 id="#{id}-#{n}"><Pnumber>#{n}</Pnumber><P2para><Text>#{t}</Text></P2para></P2>|
        end) <> "</P1para></P1>"

  describe "\"In Part N— (a) X extends to P, (b) Y extends to Q …\": every item read" do
    test "each lettered item its own extent (Infrastructure Act 2015 s.56(6))" do
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

  describe "a list after its places: \"the following provisions … namely—\"" do
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
  end

  describe "statements whose verb comes late" do
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

  describe "lettered items naming their Schedule or section once" do
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

    test "a lettered item's bare paragraph is the Schedule named before it (SI 2014/469 art.3(5)(d))" do
      e =
        read(
          "UK_uksi_2014_469",
          p1(
            "article-3",
            "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that—c the amendments made by paragraphs 182(2) and (4) of that Schedule apply in relation to England only;d the amendments made by paragraph 182(3) and (5) apply in relation to Wales only."
          )
        )

      assert {:applies, "W", ["sch.3.para.182(3)", "sch.3.para.182(5)"]} in e.applies
    end

    test "\"In section 31— (a) subsections (1) and (2) extend …\" (LRRA 2006 s.34(2))" do
      e =
        read(
          "UK_ukpga_2006_51",
          p1("section-31", "Words.") <>
            p2s("section-34", [
              {2,
               "In section 31—a subsections (1) and (2) extend to England and Wales only;b subsection (3) extends to Northern Ireland only."},
              {3,
               "The repeals in the Schedule have the same extent as the enactments to which they relate."}
            ])
        )

      assert {:only, "E+W", ["s.31(1)", "s.31(2)"]} in e.lists
      assert {:only, "NI", ["s.31(3)"]} in e.lists
    end
  end

  describe "a commencement's lettered list is no extent" do
    test "a commencement's \"This Act, except— …\" is no extent; \"so far as it makes the following provision— …\" read (Police Reform Act 2002 s.108)" do
      e =
        read(
          "UK_ukpga_2002_30",
          part(1, [10]) <>
            part(5, 78..79) <>
            ~s(<Part id="part-7">) <>
            p1("section-82", "Words.") <>
            p2s("section-108", [
              {2,
               "This Act, except—a the provisions specified in subsection (3), andb the provisions to which subsections (4) and (5) apply, shall come into force on such day as the Secretary of State may by order appoint."},
              {6,
               "Subject to subsections (7) to (9), this Act extends to England and Wales only."},
              {7,
               "This Act extends to the United Kingdom so far as it makes the following provision—za the provision contained in paragraph 19F of Schedule 3 (and any interpretative or other supplementary provision as it has effect for the purposes of that provision);a the provision contained in Part 5;b the provision contained in section 82;c . . . . . .d the provision contained in section 103(6);e . . . . ."},
              {10,
               "The amendments and repeals made by this Act—a in section 96 of the Road Traffic Regulation Act 1984 (c. 27) (traffic wardens), do not extend to Scotland."}
            ]) <> "</Part>"
        )

      assert e.default == "E+W"

      assert {:named, "E+W+S+NI", ["sch.3.para.19F", "s.78", "s.79", "s.82", "s.103(6)"]} in e.lists

      assert Extent.of(e, "s.78") == "E+W+S+NI"
      assert Extent.of(e, "s.10") == "E+W"
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
end
