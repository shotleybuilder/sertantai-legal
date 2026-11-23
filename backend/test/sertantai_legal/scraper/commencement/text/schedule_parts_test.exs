defmodule SertantaiLegal.Scraper.Commencement.Text.SchedulePartsTest do
  @moduledoc "A Schedule's Part in an order's item where it is not the whole Part brought in."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Text.ScheduleParts

  test "partial_ref/1: a Part's entries and a lettered division are the Part, partly (SI 2007/709)" do
    assert ScheduleParts.partial_ref(
             "in Part 1(B) (other repeals relating to Part 1) of Schedule 15 the entries relating to"
           ) == "sch.15.pt.1"

    assert ScheduleParts.partial_ref(
             "in Part 2 of Schedule 15 (repeals: powers of police etc) the entries relating to"
           ) == "sch.15.pt.2"

    assert ScheduleParts.partial_ref(
             "Part 1(A) (national policing improvement agency) of Schedule 15"
           ) == "sch.15.pt.1"
  end

  test "partial_ref/1: a whole Part, the order's own Schedule, any other line: nil" do
    assert ScheduleParts.partial_ref("Part III of Schedule 4") == nil

    assert ScheduleParts.partial_ref(
             "in Part I of Schedule 2 to this Order the entries relating to"
           ) == nil

    assert ScheduleParts.partial_ref("section 26 (recovery of compensation)") == nil
  end

  test "as_place/1: a Part that says where the paragraphs are is taken out" do
    assert ScheduleParts.as_place("paragraphs 3 and 19 in Part 2 of Schedule 11") ==
             "paragraphs 3 and 19 of Schedule 11"

    assert ScheduleParts.as_place("In Part 1 of Schedule 7, paragraphs 1, 2 and 13 to 20") ==
             "in Schedule 7, paragraphs 1, 2 and 13 to 20"

    assert ScheduleParts.as_place("Schedule 13, Part 2, paragraph 2.") ==
             "Schedule 13, paragraph 2."

    assert ScheduleParts.as_place("Part III of Schedule 4") == "Part III of Schedule 4"
  end
end
