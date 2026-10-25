defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.PartsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Parts

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

  test "this Part: the one holding the clause", %{doc: doc} do
    assert Parts.parts("this Part", doc, "s.3") == ["s.3"]
  end

  test "never a Chapter's Part", %{doc: doc} do
    assert Parts.parts("Chapter 3 of Part 1", doc, nil) == []
  end
end
