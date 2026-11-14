defmodule SertantaiLegal.Scraper.LawStart.ListItemsTest do
  @moduledoc "A commencement list's items and what each says of itself (`LawStart.ListItems`)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.ListItems

  test "items part at \";\" and the rows under the statement" do
    assert ListItems.split("", "section 1, 2 and 3; Part II", ["section 9"]) ==
             ["section 1, 2 and 3", "Part II", "section 9"]
  end

  test "a list with no \";\" parts at a comma before a provision noun (1996 c.56 s.583(3))" do
    assert ListItems.split(
             "section 8, section 317(6), Part II of Schedule 37 and section 582(1) so far as relating thereto, and Part II of Schedule 38",
             "",
             []
           ) == [
             "section 8",
             "section 317(6)",
             "Part II of Schedule 37 and section 582(1) so far as relating thereto",
             "Part II of Schedule 38"
           ]

    # never inside a number list or brackets
    assert ListItems.split(
             "",
             "sections 72(4), (6) and (14), Part III (apart from sections 1, 2 and section 3)",
             []
           ) ==
             ["sections 72(4), (6) and (14)", "Part III (apart from sections 1, 2 and section 3)"]
  end

  test "an item's exception: after “except”, or in brackets with “that Schedule”" do
    assert %{plain: "Part II", excepted: "sections 29 to 32", qualified: ""} =
             ListItems.read("Part II, except sections 29 to 32")

    assert %{
             plain: "sections 64 to 67 and Schedule 7",
             excepted: "paragraphs 6 and 7 of Schedule 7"
           } =
             ListItems.read(
               "sections 64 to 67 and Schedule 7 (apart from paragraphs 6 and 7 of that Schedule)"
             )
  end

  test "a qualifier binds the last provision before it (1986 c.44 s.68(2))" do
    assert %{plain: "Part I of Schedule 8", excepted: "", qualified: "section 67(3)"} =
             ListItems.read(
               "Part I of Schedule 8 and section 67(3) so far as relating to that Part"
             )

    assert %{plain: "paragraph 1(2) of Schedule 3", qualified: "Article 65"} =
             ListItems.read(
               "paragraph 1(2) of Schedule 3 (and Article 65 so far as relating thereto)"
             )

    assert %{plain: "", qualified: "section 5 so far as relating to dogs"} =
             ListItems.read("section 5 so far as relating to dogs")
  end

  test "a qualifier in the exception: excepted only so far, in partly (1981 c.69 s.74(2))" do
    assert %{plain: "and Part IV", excepted: excepted, qualified: "section 73(1)"} =
             ListItems.read(
               "and Part IV, except section 72(4), (6) and (14) and section 73(1) so far as relating to Part II of Schedule 17"
             )

    assert excepted =~ "section 72(4), (6) and (14)"
    assert excepted =~ "section 73(1)"
    refute excepted =~ "Schedule 17"
  end

  test "a bracketed exception before more of the item; a heading qualifies nothing (2007 c.28 s.245(2))" do
    assert %{
             plain: "Chapter 1 of Part 5, Part 5 of Schedule 18",
             excepted: "section 116",
             qualified: "section 241"
           } =
             ListItems.read(
               "Chapter 1 of Part 5 (except section 116), Part 5 of Schedule 18 and section 241 so far as relating to that Part of that Schedule"
             )

    assert %{qualified: ""} =
             ListItems.read(
               "section 221 (exercise of compulsory purchase powers in relation to Crown land)"
             )
  end

  test "a qualifier over several items keeps the list whole (1996 c.52 s.232(2))" do
    list =
      "section 95, and sections 222 and 227, and Schedule 19, in so far as they relate to those paragraphs"

    assert ListItems.split("", list, []) == [list]
  end
end
