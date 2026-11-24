defmodule SertantaiLegal.Scraper.Commencement.Order.ScheduleTablesTest do
  @moduledoc "A commencement order's Schedule tables (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.ScheduleTables

  test "depth/1: the brackets still open at a text's end" do
    assert ScheduleTables.depth("section 3 (so far as (a)") == 1
    assert ScheduleTables.depth("section 3(1)") == 0
  end

  test "capitalize_first/1" do
    assert ScheduleTables.capitalize_first("paragraph 5") == "Paragraph 5"
    assert ScheduleTables.capitalize_first("") == ""
  end
end
