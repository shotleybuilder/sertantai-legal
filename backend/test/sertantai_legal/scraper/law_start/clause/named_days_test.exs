defmodule SertantaiLegal.Scraper.LawStart.Clause.NamedDaysTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Clause.NamedDays

  test "IP completion day, by either name" do
    assert NamedDays.named_day_on("on IP completion day", ~D[2020-11-01]) == ~D[2020-12-31]

    assert NamedDays.named_day_on("on implementation period completion day.", ~D[2020-11-01]) ==
             ~D[2020-12-31]
  end

  test "the Scotland Act 1998's principal appointed day, for an instrument made in its span" do
    assert NamedDays.named_day_on("on the principal appointed day", ~D[1999-06-23]) ==
             ~D[1999-07-01]

    refute NamedDays.named_day_on("on the principal appointed day", ~D[2017-11-29])
    refute NamedDays.named_day_on("on the principal appointed day", nil)
  end
end
