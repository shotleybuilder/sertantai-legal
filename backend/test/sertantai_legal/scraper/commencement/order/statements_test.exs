defmodule SertantaiLegal.Scraper.Commencement.Order.StatementsTest do
  @moduledoc "A commencement order article's statements and their heads (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Statements

  test "already_in_force?/1: a head that only speaks of provisions as in force states nothing" do
    assert Statements.already_in_force?("provisions which have come into force under article 2")
    refute Statements.already_in_force?("Section 3 comes into force on 1st April 2015")
  end

  test "closing_date/1: \"… is 1st April 2015\" after the list dates the open head" do
    lines = [
      "The day appointed for the coming into force of the following provisions—",
      "section 3;",
      "is 1st April 2015."
    ]

    assert [head | _] = Statements.closing_date(lines)
    assert head =~ "the following is 1st April 2015"
  end
end
