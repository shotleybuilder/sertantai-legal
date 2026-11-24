defmodule SertantaiLegal.Scraper.LawStart.Clause.TailTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Clause.Tail
  alias SertantaiLegal.Scraper.LawStart.OwnDays

  test "a dated tail" do
    assert Tail.tail_date("on 17th April 1995", nil) == {:clause_date, ~D[1995-04-17]}
  end

  test "a named day and a made-relative day" do
    assert Tail.tail_date("immediately before the principal appointed day.", ~D[1999-06-23]) ==
             {:clause_named_day, ~D[1999-07-01]}

    assert Tail.tail_date("on the day after the day they are made", ~D[2019-04-01]) ==
             {:clause_made_relative, ~D[2019-04-02]}
  end

  test "a laid-relative tail without its laid day is unknown" do
    days = %OwnDays{made: ~D[2018-11-22], laid: nil}

    assert Tail.tail_date("on the 21st day after the day on which they are laid", days) ==
             :laid_unknown
  end

  test "no date stated" do
    assert Tail.tail_date("on such day as the Secretary of State may by order appoint", nil) ==
             nil
  end
end
