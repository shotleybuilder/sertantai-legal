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

  test "every Part named (\"Part 3 and Part 4\": SI 2022/1037)", %{doc: doc} do
    assert Parts.parts("An amendment made by Part 1 and Part 3", doc, nil) == [
             "s.1",
             "s.2",
             "s.4"
           ]
  end

  test "this Part: the one holding the clause", %{doc: doc} do
    assert Parts.parts("this Part", doc, "s.3") == ["s.3"]
  end

  test "never a Chapter's Part", %{doc: doc} do
    assert Parts.parts("Chapter 3 of Part 1", doc, nil) == []
  end

  describe "Chapters (CV-S05 NEW-A)" do
    setup do
      p1 = &ExtentDoc.p1/2

      doc =
        ExtentDoc.doc("UK_ukpga_2013_32", """
        <Part id="part-1">#{p1.("section-1", "One.")}</Part>
        <Part id="part-2"><Chapter id="part-2-chapter-1">#{p1.("section-2", "Two.")}#{p1.("section-3", "Three.")}</Chapter><Chapter id="part-2-chapter-2">#{p1.("section-4", "Four.")}</Chapter></Part>
        <Part id="part-3"><Chapter id="part-3-chapter-1">#{p1.("section-5", "Five.")}</Chapter><Chapter id="part-3-chapter-2">#{p1.("section-6", "Six.")}#{p1.("section-7", "Seven.")}</Chapter></Part>
        """)

      %{doc: doc}
    end

    test "a Chapter of a Part: its sections, never the whole Part", %{doc: doc} do
      assert Parts.parts("Chapter 1 of Part 2", doc, nil) == ["s.2", "s.3"]
      assert Parts.parts("Chapters 1 and 2 of Part II", doc, nil) == ["s.2", "s.3", "s.4"]
    end

    test "a Chapter of this Part: the Part holding the clause", %{doc: doc} do
      assert Parts.parts("Chapter 2 of this Part", doc, "s.5") == ["s.6", "s.7"]
    end

    test "a bare Chapter takes the Part named before it; that Part, that Part" do
      assert Parts.qualify_chapters(
               "b in Part 2— i Chapter 1 (general considerations), ii Chapter 2, iv section 56"
             ) ==
               "b in Part 2— i Chapter 1 of Part 2 (general considerations), ii Chapter 2 of Part 2, iv section 56"

      assert Parts.qualify_chapters("h Chapter 1 of Part 3; i Chapter 2 of that Part") ==
               "h Chapter 1 of Part 3; i Chapter 2 of Part 3"

      # never a Schedule's Part
      assert Parts.qualify_chapters("Part 2 of Schedule 1; Chapter 4") ==
               "Part 2 of Schedule 1; Chapter 4"
    end
  end
end
