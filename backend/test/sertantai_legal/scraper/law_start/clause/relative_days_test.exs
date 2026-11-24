defmodule SertantaiLegal.Scraper.LawStart.Clause.RelativeDaysTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Clause.RelativeDays

  @made ~D[1987-07-21]

  test "counted from the day made: after excludes the day, beginning with includes it" do
    assert RelativeDays.made_relative("on the day after the day on which they are made", @made) ==
             {:clause_made_relative, ~D[1987-07-22]}

    assert RelativeDays.made_relative(
             "on the twenty-first day after the day on which they are made",
             @made
           ) == {:clause_made_relative, ~D[1987-08-11]}

    assert RelativeDays.made_relative("six months after the date on which they are made", @made) ==
             {:clause_made_relative, ~D[1988-01-21]}
  end

  test "counted from the day laid" do
    assert RelativeDays.laid_relative(
             "on the 21st day after the day on which they are laid before Parliament",
             ~D[2020-06-03]
           ) == {:clause_laid_relative, ~D[2020-06-24]}
  end

  test "a made-relative tail with no made day is unknown" do
    assert RelativeDays.laid_relative("on the day after the day on which they are laid", nil) ==
             :laid_unknown
  end
end
