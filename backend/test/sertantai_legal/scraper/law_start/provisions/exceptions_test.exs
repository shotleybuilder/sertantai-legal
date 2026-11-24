defmodule SertantaiLegal.Scraper.LawStart.Provisions.ExceptionsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Provisions.Exceptions

  test "a list of another law's provisions" do
    assert Exceptions.other_law_list?(
             "The following provisions of the Environment Act 1995 shall come into force on 1st April 1996—"
           )

    refute Exceptions.other_law_list?(
             "The following provisions of the Act shall come into force at the end of the period of two months beginning with the day on which it is passed, namely—"
           )
  end

  test "no clause read, nothing excepted" do
    assert Exceptions.except_refs(nil, []) == []
    assert Exceptions.except_partly(nil, []) == []
  end

  test "a sentence's statements" do
    assert [_ | _] =
             Exceptions.statements("Regulation 12 shall come into force on 31st May 2015")
  end

  _ = LawStart
end
