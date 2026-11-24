defmodule SertantaiLegal.Scraper.LawStart.Provisions.WordsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Words

  test "a row's provision drops its paragraphs" do
    assert Words.provision("UK_x:reg.1(2)(a)") == "UK_x:reg.1"
    assert Words.provision("UK_x:s.12") == "UK_x:s.12"
  end

  test "a row with no text reads as one empty sentence" do
    assert Words.sentences(%{section_id: "UK_x:reg.1"}) == [""]
  end

  test "the shared patterns" do
    assert Regex.match?(Words.cif(), "Regulation 12 shall come into force on 31st May 2015")
    assert Regex.match?(Words.qualified(), "so far as it relates to Wales")
  end
end
