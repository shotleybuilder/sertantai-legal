defmodule SertantaiLegal.Scraper.LawStart.Provisions.ClauseSentencesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.ClauseSentences

  test "a clause sentence naming a provision and its day" do
    s = "Regulation 12 shall come into force on 31st May 2015."
    row = %{section_id: "UK_x:reg.1(2)", text: s}
    rows = [row, %{section_id: "UK_x:reg.12", text: ""}]

    assert Enum.any?(
             ClauseSentences.clause_sentence_groups(s, row, rows, nil, "UK_x:reg.1", nil),
             &(&1.date == ~D[2015-05-31] and &1.refs == [{"UK_x:reg.12", 11}])
           )
  end
end
