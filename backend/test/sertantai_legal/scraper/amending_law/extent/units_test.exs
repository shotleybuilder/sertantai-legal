defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.UnitsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Units

  test "a lead-in's lettered items are statements of their own, after the sentence" do
    s =
      "In Part 5— (a) sections 220 to 224 extend to England and Wales only; (b) section 225 extends to Scotland only"

    assert Units.statements(s) == [
             s,
             "sections 220 to 224 extend to England and Wales only",
             "section 225 extends to Scotland only"
           ]
  end

  test "a compound's second clause names \"that Schedule\"" do
    s =
      "Paragraphs 34 and 35 of Schedule 2 extend to England and Wales and Scotland, and paragraph 36 of that Schedule extends to Scotland only"

    assert Units.statements(s) == [
             s,
             "Paragraphs 34 and 35 of Schedule 2 extend to England and Wales and Scotland",
             "paragraph 36 of Schedule 2 extends to Scotland only"
           ]
  end

  test "repealed words' dots are no sentence's end" do
    assert Units.no_dots("section 1 . . . extends") == "section 1  extends"
  end

  test "a provision's units: its subsections, the leading number dropped" do
    doc =
      ExtentDoc.doc("UK_ukpga_1974_37", """
      <P1 id="section-84"><Pnumber>84</Pnumber><P1para>
      <P2 id="section-84-1"><P2para><Text>This Act extends to Great Britain.</Text></P2para></P2>
      <P2 id="section-84-2"><P2para><Text>Part III does not extend to Scotland.</Text></P2para></P2>
      </P1para></P1>
      """)

    assert Units.units(doc, "section-84") |> Enum.map(&String.trim/1) |> length() == 2
    assert Enum.any?(Units.units(doc, "section-84"), &(&1 =~ "Part III does not extend"))
  end
end
