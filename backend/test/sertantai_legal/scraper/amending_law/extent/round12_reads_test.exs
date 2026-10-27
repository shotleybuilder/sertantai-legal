defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Round12ReadsTest do
  @moduledoc """
  The extent reader's misread found by the round 11 agent check (seed 16,
  NEW-1), the census run-02 residuals (R1–R3) and the doubtful reading
  noted, each on its law's real wording (CV-S05 round 12).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns), do: Enum.map_join(ns, &p1("section-#{&1}", "Words."))
  defp part(n, sections), do: ~s(<Part id="part-#{n}">#{words(sections)}</Part>)

  defp unread?(e, ref),
    do: Enum.any?(e.lists, fn {k, _, refs} -> k == :unread and ref in refs end)

  test "NEW-1: a default sentence's lettered items qualified by \"so far as …\" are withheld, never the default (Criminal Law Act 1977 s.65(10))" do
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

  test "R1: \"which inserts Part 4A into the Energy Act 2008\" is a description, not another law's provision (ukpga 2009/23 s.323(2))" do
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

  test "R2: a same-extent item with its own \"other than\" (Infrastructure Act 2015 s.56(2))" do
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

  test "R3: \"section 113 (together with such of the other provisions of Part 7 as relate to …)\" (Climate Change-style, ukpga 2008/4 s.152)" do
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
end
