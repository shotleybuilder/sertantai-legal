defmodule SertantaiLegal.Scraper.LawStart.Provisions.SentenceTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Sentence

  test "a sentence naming a provision and its day" do
    row = %{section_id: "UK_x:reg.1(2)", text: ""}
    rows = [row, %{section_id: "UK_x:reg.12", text: ""}]

    assert Enum.any?(
             Sentence.of_sentence(
               "Regulation 12 shall come into force on 31st May 2015",
               row,
               rows,
               nil,
               "UK_x:reg.1"
             ),
             &(&1.treatment == :provision_dated and &1.date == ~D[2015-05-31] and
                 &1.refs == [{"UK_x:reg.12", 11}])
           )
  end
end
