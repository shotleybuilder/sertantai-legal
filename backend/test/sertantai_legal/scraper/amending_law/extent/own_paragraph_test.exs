defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.OwnParagraphTest do
  @moduledoc """
  A Schedule paragraph's own extent: the forms CV-S05f adds, on SOCPA 2005
  Sch.7's wording (paras 47, 49, 54, 56), beside round 11's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.OwnParagraph

  test "round 11's forms stay" do
    assert OwnParagraph.list(
             "This paragraph does not extend to Northern Ireland.",
             "sch.8.para.27"
           ) ==
             {:not, "NI", ["sch.8.para.27"]}

    assert OwnParagraph.list("This paragraph extends only to England and Wales.", "sch.8.para.2") ==
             {:only, "E+W", ["sch.8.para.2"]}
  end

  test "the whole of the United Kingdom (para 47(5))" do
    assert OwnParagraph.list(
             "This paragraph extends to the whole of the United Kingdom.",
             "sch.7.para.47"
           ) ==
             {:named, "E+W+S+NI", ["sch.7.para.47"]}
  end

  test "places with a bracket saying the same (para 49(4))" do
    assert OwnParagraph.list(
             "This paragraph extends to England and Wales and to Northern Ireland (but not to Scotland).",
             "sch.7.para.49"
           ) == {:named, "E+W+NI", ["sch.7.para.49"]}

    # (a bracket contradicting the places: never read)
    assert OwnParagraph.list(
             "This paragraph extends to England and Wales and to Scotland (but not to Scotland).",
             "sch.7.para.49"
           ) == nil
  end

  test "also (para 56)" do
    assert OwnParagraph.list("This paragraph extends also to Scotland.", "sch.7.para.56") ==
             {:also, "S", ["sch.7.para.56"]}
  end

  test "the same extent as the Act it amends (para 54)" do
    assert OwnParagraph.list("This paragraph has the same extent as that Act.", "sch.7.para.54") ==
             {:same, nil, ["sch.7.para.54"]}

    assert OwnParagraph.list(
             "This paragraph has the same extent as the provision amended.",
             "sch.7.para.54"
           ) == {:same, nil, ["sch.7.para.54"]}
  end

  test "never more after its places" do
    assert OwnParagraph.list(
             "This paragraph extends to England and Wales and to the territorial waters adjacent to England and Wales.",
             "sch.7.para.1"
           ) == nil
  end
end
