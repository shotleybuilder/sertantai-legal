defmodule SertantaiLegal.Scraper.LawStart.PrincipalAppointedDayTest do
  @moduledoc """
  Fire and OH&S: Commencement reader — "the principal appointed day" of the
  Scotland Act 1998 (1st July 1999: SI 1998/3178 art.3) read as a named day
  in an instrument made under that Act before it.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Clause

  test "“shall come into force on the principal appointed day” (SI 1999/1750 art.1(1), made 1999)" do
    assert Clause.tail_date("on the principal appointed day", ~D[1999-06-23]) ==
             {:clause_named_day, ~D[1999-07-01]}
  end

  test "“immediately before the principal appointed day” (SI 1999/1756 art.1(1))" do
    assert Clause.tail_date("immediately before the principal appointed day.", ~D[1999-06-23]) ==
             {:clause_named_day, ~D[1999-07-01]}
  end

  test "another Act's principal appointed day is no named day (Wales Act 2017), nor one with no made date" do
    refute match?(
             {:clause_named_day, _},
             Clause.tail_date("on the principal appointed day", ~D[2017-11-29])
           )

    refute match?({:clause_named_day, _}, Clause.tail_date("on the principal appointed day", nil))
  end
end
