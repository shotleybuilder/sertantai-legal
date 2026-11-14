defmodule SertantaiLegal.Scraper.Commencement.Order.AsidesTest do
  @moduledoc "The bracketed asides in a commencement order's list of provisions."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Asides

  test "strip/1: an aside with its own brackets goes; an item's brackets stay" do
    assert Asides.strip("paragraphs 1, 2 (except sub-paragraphs (2) and (9)(b)), 3 to 7") ==
             "paragraphs 1, 2 , 3 to 7"

    assert Asides.strip("32(1) to (13) and (15) to (18)") == "32(1) to (13) and (15) to (18)"
  end

  test "items/1: each numbered item with the aside after it" do
    assert Asides.items(
             "1, 2 (except sub-paragraphs (2) and (9)(b)), 35 (for certain purposes), 36"
           ) ==
             [{"2", "except sub-paragraphs (2) and (9)(b)"}, {"35", "for certain purposes"}]
  end

  test "drop_headings/1: a heading goes, whatever place or purpose it names; a qualifier stays" do
    assert Asides.drop_headings(
             "section 86 (water and sewerage undertakers in England: modifying appointments)"
           ) == "section 86 "

    assert Asides.drop_headings(
             "section 9 (meaning of local authority for the purpose of access rights)"
           ) == "section 9 "

    for kept <- [
          "section 61 (in relation to Wales)",
          "section 105 (in so far as it is not already in force)",
          "Section 33 (except subsection (1)(a) and (b))",
          "Schedule 9 (paragraph 2 and paragraph 3 so far as it relates to the Commission)",
          "paragraphs 10 to 14 of Schedule 3 (and section 44(1) so far as relating thereto)"
        ],
        do: assert(Asides.drop_headings(kept) == kept)
  end
end
