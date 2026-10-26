defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.AmendsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Amends, Units}

  test "any provision amending the named Acts: those whose own words name them (ukpga 1975/71 s.129(6))" do
    doc =
      ExtentDoc.doc(
        "UK_ukpga_1975_71",
        ExtentDoc.p1(
          "section-10",
          "In the House of Commons Disqualification Act 1975, in Part III of Schedule 1, insert the entry."
        ) <>
          ExtentDoc.p1("section-11", "In the Trade Union Act 1913, omit section 2.") <>
          ExtentDoc.p1(
            "section-129",
            "Any provision of this Act which amends or repeals any provision of the House of Commons Disqualification Act 1975 or the Northern Ireland Assembly Disqualification Act 1975 shall extend to Northern Ireland, but except as aforesaid this Act shall not extend there."
          )
      )

    assert Amends.amends(Units.unit_sentences(doc), doc) == [{:named, "NI", ["s.10"]}]
  end
end
