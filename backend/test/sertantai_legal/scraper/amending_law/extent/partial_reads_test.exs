defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.PartialReadsTest do
  @moduledoc """
  The extent reader's partial reads and misreads found by the round 7
  agent check (seed 12) and by the catalogue's own-refs crediting
  (`Extent.Credit`, CV-S05 round 8), each on its law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Units

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp sections(ns), do: Enum.map_join(ns, &p1("section-#{&1}", "Words."))

  test "NEW-4: \"Section 7 extends to Northern Ireland, but the other provisions … do not\" (1997/42 s.9(3))" do
    e =
      read(
        "UK_ukpga_1997_42",
        sections(1..8) <>
          ~s|<P1 id="section-9"><P1para><P2 id="section-9-3"><P2para><Text>Section 7 extends to Northern Ireland, but the other provisions of this Act do not extend to Northern Ireland.</Text></P2para></P2></P1para></P1>|
      )

    assert {e.default, e.lists} == {"E+W+S", [{:also, "NI", ["s.7"]}]}
  end

  test "NEW-1: another Act's paragraphs \"as amended by … this section\" are never this section (2013/22 s.27(13))" do
    e =
      read(
        "UK_ukpga_2013_22",
        p1(
          "section-27",
          "Paragraphs 9A, 9C and 10, as amended by the preceding provisions of this section, extend to Scotland and Northern Ireland (as well as to England and Wales)."
        )
      )

    assert e.lists == []
  end

  test "NEW-5: \"In Schedule 3— (a) paragraphs … (and article 27 …) have the same extent …; (b) …\" (SI 2013/602 art.1(8))" do
    e =
      read(
        "UK_uksi_2013_602",
        p1(
          "article-1",
          "In Schedule 3— (a) paragraphs 1 to 11 and 13 to 18 (and article 27 in so far as it relates to those paragraphs) have the same extent as the provisions to which they relate; and (b) paragraphs 12 and 19 (and article 27 in so far as it relates to those paragraphs) extend to Scotland only."
        )
      )

    assert {:only, "S", ["sch.3.para.12", "sch.3.para.19"]} in e.lists

    assert {:same, nil, ["sch.3.para.1..sch.3.para.11", "sch.3.para.13..sch.3.para.18"]} in e.lists
  end

  test "NEW-2: a qualified item, its sub-list and a qualified number left out (1975/21 s.463(1))" do
    e =
      read(
        "UK_ukpga_1975_21",
        ~s|<P1 id="section-463"><P1para><Text>The following provisions of this Act shall extend to England and Wales, that is to say— (a) in Part II, sections 365, 370 (so far as relating to section 374), 374 and 413; (b) in Schedule 9, the amendments relating to— (i) the Criminal Justice Act 1961; (ii) the Powers of Criminal Courts Act 1973.</Text></P1para></P1>|
      )

    assert e.lists == [{:named, "E+W", ["s.365", "s.374", "s.413"]}]
  end

  test "\"This article\", \"this section and the following\", a naming bracket (round 8)" do
    assert read(
             "UK_uksi_2010_708",
             p1(
               "article-1",
               "This article and article 4 extend to England and Wales, Scotland and Northern Ireland."
             )
           ).lists == [{:named, "E+W+S+NI", ["reg.1", "reg.4"]}]

    assert read(
             "UK_ukpga_1993_9",
             p1(
               "section-48",
               "This Act extends to Scotland only. This section and the following provisions of this Act also extend to England and Wales— section 12(2); section 46; and in section 47, subsection (1) in so far as relating to Schedule 5."
             )
           ).lists == [{:also, "E+W", ["s.48", "s.12(2)", "s.46"]}]

    assert read(
             "UK_ukpga_1996_18",
             p1(
               "section-244",
               "Sections 201 and 238 (and sections 236 and 243, this section and section 245) extend to Northern Ireland (as well as to England and Wales and Scotland)."
             )
           ).lists == [{:named, "NI", ["s.201", "s.238", "s.236", "s.243", "s.244", "s.245"]}]
  end

  test "\"Where any enactment repealed or amended … the repeal or amendment extends to that part\" (1986/50 s.87(5))" do
    assert read(
             "UK_ukpga_1986_50",
             p1(
               "section-87",
               "Where any enactment repealed or amended by this Act extends to any part of the United Kingdom, the repeal or amendment extends to that part."
             )
           ).lists == [{:same, nil, ["*"]}]
  end

  test "lettered statements: roman items and \"(b) an amendment … made by …\" (2023/55 s.254(3), 2025/36 s.158)" do
    s =
      "In Part 3— (a) section 1 extends to Wales; (b) an amendment or repeal made by section 2 has the same extent as the provision amended; (ii) section 3 extends to Scotland; (iii) section 4 extends to Northern Ireland"

    assert tl(Units.statements(s)) == [
             "section 1 extends to Wales",
             "an amendment or repeal made by section 2 has the same extent as the provision amended",
             "section 3 extends to Scotland",
             "section 4 extends to Northern Ireland"
           ]
  end
end
