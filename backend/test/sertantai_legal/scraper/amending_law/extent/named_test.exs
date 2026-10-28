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
          "Sections 1 and 2 above, and Schedule 1 to this Act (except paragraph 12), shall not extend to Northern Ireland."
        ] do
      assert named("UK_ukpga_2000_1", text) == [], text
    end
  end

  test "a statement qualified after its places is withheld, never dropped (CV-S05 seed 22)" do
    assert named(
             "UK_ukpga_2000_1",
             "Section 1(2) and Schedule 1 extend to Northern Ireland so far as they amend the House of Commons Disqualification Act 1975."
           ) == [{:unread, nil, ["s.1(2)", "sch.1"]}]
  end

  test "never a provision named in a bracketed description (NEW-C)" do
    assert named(
             "UK_ukpga_2013_32",
             "Paragraph 25 (amendment to section 24A of the Nuclear Installations Act 1965 as it has effect in England and Wales and Scotland) extends to England and Wales and Scotland only."
           ) == []

    assert named("UK_ukpga_2013_32", "Section 73(2) (powers) extends to Scotland only.") ==
             [{:only, "S", ["s.73(2)"]}]
  end

  test "a Chapter of this Part (NEW-A)" do
    p1 = &ExtentDoc.p1/2

    doc =
      ExtentDoc.doc(
        "UK_ukpga_2015_15",
        ~s(<Part id="part-3"><Chapter id="part-3-chapter-3">#{p1.("section-83", "One.")}#{p1.("section-84", "Two.")}</Chapter><Chapter id="part-3-chapter-4">#{p1.("section-99", "Chapter 3 of this Part extends only to England and Wales.")}</Chapter></Part>)
      )

    assert Named.named(Units.unit_sentences(doc), doc) == [{:only, "E+W", ["s.83", "s.84"]}]
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
