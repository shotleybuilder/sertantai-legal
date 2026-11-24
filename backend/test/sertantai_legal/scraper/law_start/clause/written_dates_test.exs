defmodule SertantaiLegal.Scraper.LawStart.Clause.WrittenDatesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Clause.WrittenDates

  test "a date in figures at the start of a tail" do
    assert WrittenDates.date_at_start("17th April 1995") == ~D[1995-04-17]
  end

  test "a date in words, with its year in words" do
    assert WrittenDates.date_at_start(
             "the twenty-first day of July, nineteen hundred and thirty-eight : Provided"
           ) == ~D[1938-07-21]

    assert WrittenDates.date_at_start("the first day of January, two thousand and one") ==
             ~D[2001-01-01]
  end

  test "no month, no date" do
    assert WrittenDates.date_at_start("the first day of Smarch, nineteen hundred") == nil
  end
end
