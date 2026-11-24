defmodule SertantaiLegal.Scraper.Commencement.Order.DatesTest do
  @moduledoc "The date a commencement statement gives (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Dates

  test "parse_dates/1: every date, in order" do
    assert Dates.parse_dates("on 1st October 2001 and 2 April 1994") == [
             ~D[2001-10-01],
             ~D[1994-04-02]
           ]

    assert Dates.parse_dates("on the day after this Order is made") == []
  end

  test "appointed/1: the date before \"is the day appointed for the coming into force of\"" do
    assert {~D[2015-04-01], rest} =
             Dates.appointed(
               "1st April 2015 is the day appointed for the coming into force of section 3"
             )

    assert String.trim(rest) == "section 3"
  end

  test "two_days/1: one head, two days, read as two statements" do
    head =
      "The day appointed for the coming into force of section 3 for the purposes of making regulations is 1st April 2007 and for all other purposes is 1st October 2007."

    assert [_, _] = Dates.two_days(head)

    assert Dates.two_days("Section 3 comes into force on 1st April 2007.") == [
             "Section 3 comes into force on 1st April 2007."
           ]
  end
end
