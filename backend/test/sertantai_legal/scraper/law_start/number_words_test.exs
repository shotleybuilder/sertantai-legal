defmodule SertantaiLegal.Scraper.LawStart.NumberWordsTest do
  @moduledoc "Provision numbers written in words, as digits (`LawStart.NumberWords`)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.NumberWords

  test "one number after its noun (Pipe-lines Act 1962 s.70(3))" do
    assert NumberWords.digits("Section forty-one of this Act shall come into operation") ==
             "Section 41 of this Act shall come into operation"
  end

  test "an “and” after “hundred” is the number's, any other parts two (1954 c.70 s.194)" do
    assert NumberWords.digits(
             "This Act, except sections one hundred and seventy-two and one hundred and ninety thereof, shall"
           ) == "This Act, except sections 172 and 190 thereof, shall"
  end

  test "a range, a list and a trailing separator" do
    assert NumberWords.digits("Sections one to three, five and twenty-two apply") ==
             "Sections 1 to 3, 5 and 22 apply"

    assert NumberWords.digits("Section one and the Schedule") == "Section 1 and the Schedule"
  end

  test "digits and other words are left alone" do
    text = "Sections 1 and 2 come into force on the first day of April; no one section applies."
    assert NumberWords.digits(text) == text
  end
end
