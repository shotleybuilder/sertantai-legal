defmodule SertantaiLegal.Scraper.Commencement.Order.ScheduleDateTest do
  @moduledoc "How an order's articles name the Schedule they date (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.ScheduleDate

  test "schedule_named/1: the order's own Schedule, never the Act's" do
    assert "the provisions specified in the Schedule to this Order" =~
             ScheduleDate.schedule_named("schedule")

    assert "the provisions in Schedule 2" =~ ScheduleDate.schedule_named("schedule-2")
    refute "Schedule 2 to the Act" =~ ScheduleDate.schedule_named("schedule-2")
  end

  test "part_named/1: a Part of the Schedule" do
    assert "Part 1 of the Schedule hereto" =~ ScheduleDate.part_named("schedule-part-1")
    assert "Part I of Schedule 2" =~ ScheduleDate.part_named("schedule-2-part-I")
  end
end
