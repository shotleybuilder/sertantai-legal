defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.SameTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Same, Units}

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
end
