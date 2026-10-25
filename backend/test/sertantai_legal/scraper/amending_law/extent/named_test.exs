defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.NamedTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Named, Units}

  defp named(law, text) do
    doc = ExtentDoc.doc(law, ExtentDoc.p1("section-9", text))
    Named.named(Units.unit_sentences(doc), doc)
  end

  test "named provisions' own extent: also, only, not, named" do
    assert named(
             "UK_ukpga_1999_22",
             "This Act extends to England and Wales. Sections 32 to 34 and 73(2) extend to Scotland. Section 74 extends to Northern Ireland only. Sections 17 and 27 do not extend to Wales."
           ) == [
             {:named, "S", ["s.32..s.34", "s.73(2)"]},
             {:only, "NI", ["s.74"]},
             {:not, "W", ["s.17", "s.27"]}
           ]
  end

  test "never another law's, a mention, a qualified or excepted extent" do
    for text <- [
          "Sections 128(4) and 132(3) of that Act shall continue to extend to Scotland.",
          "Section 1(2) and Schedule 1 extend to Northern Ireland so far as they amend the House of Commons Disqualification Act 1975.",
          "Sections 1 and 2 above, and Schedule 1 to this Act (except paragraph 12), shall not extend to Northern Ireland."
        ] do
      assert named("UK_ukpga_2000_1", text) == [], text
    end
  end

  test "the kind: not, only, also, else named" do
    assert Named.named_kind(%{
             "not" => "",
             "only" => "only ",
             "only2" => "",
             "also" => "",
             "also2" => ""
           }) ==
             :only

    assert Named.named_kind(%{
             "not" => "",
             "only" => "",
             "only2" => "",
             "also" => "",
             "also2" => ""
           }) ==
             :named
  end
end
