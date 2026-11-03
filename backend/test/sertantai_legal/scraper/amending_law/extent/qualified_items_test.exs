defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.QualifiedItemsTest do
  @moduledoc """
  Items qualified by "so far as …", "in so far as …" or an aside: withheld
  as unread, never read whole and never dropped to the default, while
  their plain companions are read; each on its law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns, kind \\ "section"), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))
  defp part(n, ids, kind \\ "section"), do: ~s(<Part id="part-#{n}">#{words(ids, kind)}</Part>)
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

  test "an item led by its qualifier is withheld, never read whole (FRSA 2004 s.63(2))" do
    e =
      read(
        "UK_ukpga_2004_21",
        Enum.map_join([34, 35, 36, 52, 53, 60], &p1("section-#{&1}", "Words.")) <>
          ~s|<P1 id="section-63"><P1para><P2 id="section-63-1"><Pnumber>1</Pnumber><P2para><Text>Subject to subsection (2), this Act extends to England and Wales only.</Text></P2para></P2><P2 id="section-63-2"><Pnumber>2</Pnumber><P2para><Text>The following provisions also extend to Scotland—a sections 34 to 36;b in so far as relating to sections 26 to 27A of the Fire Services Act 1947 (c. 41), section 52;c in so far as relating to—i sections 46 and 61 of the Reserve and Auxiliary Forces (Protection of Civil Interests) Act 1951 (c. 65),ii the Superannuation Act 1972 (c. 11), section 53(1) and Schedule 1;d section 60.</Text></P2para></P2></P1para></P1>|
      )

    assert {:also, "S", ["s.34..s.36", "s.60"]} in e.lists
    assert {:unread, nil, ["s.52", "s.53(1)", "sch.1"]} in e.lists
    assert Extent.of(e, "s.52") == nil
  end

  describe "plain provisions read, their qualified companion withheld" do
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

  describe "a wholly qualified item withheld, never dropped to the default" do
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

  describe "a lettered or named item's qualified piece withheld, its plain piece read" do
    test "a default sentence's lettered items qualified by \"so far as …\" are withheld, never the default (Criminal Law Act 1977 s.65(10))" do
      e =
        read(
          "UK_ukpga_1977_45",
          words([31, 38, 52]) <>
            p1(
              "section-65",
              "In this Act—a Part V and, so far as there provided, the provisions mentioned in section 63(2) above extend to Scotland;b the following provisions extend to Northern Ireland namely— sections 38 to 40, . . . section 52, Schedule 7, in Schedule 14, paragraph 5;c section 31 and Schedule 6, so far as they amend any enactment which extends to the Channel Islands or the Isle of Man, extend to the Channel Islands or the Isle of Man, as the case may be;d subsections (4) and (5) above and Schedules 12 and 13, so far as they relate to—i section 45 of the Prison Act 1952 (in its application to persons for the time being in Northern Ireland or in the Channel Islands or the Isle of Man);ii Part III and section 39(1) of the Criminal Justice Act 1961; andiii sections 60 and 63 of the Criminal Justice Act 1967, extend to Northern Ireland, the Channel Islands and the Isle of Man (as well as, by virtue of paragraph (a) above, to Scotland;e . . . but save as aforesaid, this Act extends to England and Wales only."
            )
        )

      assert e.default == "E+W"
      assert Extent.of(e, "s.38") == "E+W+NI"
      assert unread?(e, "sch.12")
      assert unread?(e, "s.31")
      refute Extent.of(e, "sch.12") == "E+W"
    end

    test "\"section 113 (together with such of the other provisions of Part 7 as relate to …)\" (Climate Change-style, ukpga 2008/4 s.152)" do
      e =
        read(
          "UK_ukpga_2008_4",
          part(7, [113, 114]) <>
            p1(
              "section-152",
              "The following provisions of this Act extend to England and Wales, Scotland and Northern Ireland—a section 77;b section 96;c section 113 (together with such of the other provisions of Part 7 as relate to the commission of offences under that section);d Part 10."
            )
        )

      assert Extent.of(e, "s.113") == "E+W+S+NI"
      assert unread?(e, "s.114")
    end

    test "a lettered item with a qualified companion: its plain provisions read (ukpga 2015/7 s.56(6)(b))" do
      e =
        read(
          "UK_ukpga_2015_7",
          part(5, [30, 33, 34, 37]) <>
            p1(
              "section-56",
              "In Part 5 (planning, land and buildings)—a an amendment or repeal has the same extent as the provision to which it relates, andb sections 30(2) to (4), 32(11) and (12) and 33(2), Part 4 of Schedule 5 and section 34 so far as applying to Part 5 and section 37(6) extend to England and Wales only."
            )
        )

      assert Extent.of(e, "s.33(2)") == "E+W"
      assert unread?(e, "s.34")
      # (after an "and" in the qualifier's object: its own item or the
      # object's, so withheld, never the Part's same extent)
      assert unread?(e, "s.37(6)")
      refute Extent.of(e, "s.37(6)") == :same
    end

    test "a named statement's qualified piece withheld, its plain piece read (Environment Act 1995 s.125(8))" do
      e =
        read(
          "UK_ukpga_1995_25",
          part("III", [57, 58]) <>
            p1(
              "section-125",
              "Part III of this Act, and Schedule 24 to this Act so far as relating to Part III, extends to England and Wales only."
            )
        )

      assert Extent.of(e, "s.57") == "E+W"
      assert unread?(e, "sch.24")
    end

    test "\"X and, so far as relating to those provisions, Y also extend …\": Y qualified, X read (ukpga 2006/47 s.66)" do
      e =
        read(
          "UK_ukpga_2006_47",
          p1("section-1", "This Act extends to England and Wales and Scotland.") <>
            p1(
              "section-66",
              "Sections 1, 28, 29 and 55 and Schedule 1 and, so far as relating to those provisions, sections 59 to 61 and 65 also extend to Northern Ireland."
            )
        )

      assert {:also, "NI", refs} = Enum.find(e.lists, &match?({:also, "NI", _}, &1))
      assert "s.1" in refs and "sch.1" in refs
      refute "s.59..s.61" in refs
      assert unread?(e, "s.65")
    end

    test "a \"save as aforesaid\" sentence's item: its plain provisions read, the qualified withheld (ukpga 1972/71 s.66)" do
      e =
        read(
          "UK_ukpga_1972_71",
          words([23, 24, 64]) <>
            p1(
              "section-66",
              "In this Act—a sections 23, 24, 28, 29, 30, 33, 35, 51 and this section, ... section 64(1) and Schedule 5 so far as they relate to the Road Traffic Act 1972 and section 64(2) and Schedule 6 so far as they relate to the Summary Jurisdiction (Scotland) Act 1908 and the Firearms Act 1968, extend to Scotland;b section 63 and this section extend to Northern Ireland; but save as aforesaid, this Act extends to England and Wales only."
            )
        )

      assert e.default == "E+W"
      assert Extent.of(e, "s.23") == "E+W+S"
      assert unread?(e, "sch.5")
    end

    test "a withheld subject never takes its qualifier's object (ukpga 2014/6 s.140)" do
      e =
        read(
          "UK_ukpga_2014_6",
          words([56, 126]) <>
            p1(
              "section-140",
              "Section 126(3) and (4), so far as relating to paragraphs 5, 56 to 62 and 64 of Schedule 7, extends to Northern Ireland."
            )
        )

      assert unread?(e, "s.126(3)")
      refute unread?(e, "s.56")
      refute unread?(e, "s.56..s.62")
    end
  end

  describe "a qualified companion is withheld, never dropped" do
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

  describe "a qualified subject or object never read whole" do
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

  describe "an aside or a describing phrase withholds what it qualifies" do
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

    test "\"in Schedule 11, the amendments to …\" withholds the Schedule, never reads it whole (ukpga 2022/32 s.207)" do
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

    test "\"(and those Parts of Schedule 7)\" after a qualified item (ukpga 2020/7 s.100)" do
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

    test "a second statement qualified after its places is withheld (ukpga 1996/23 s.108(3))" do
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
  end
end
