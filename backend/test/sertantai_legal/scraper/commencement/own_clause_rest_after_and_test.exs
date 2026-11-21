defmodule SertantaiLegal.Scraper.Commencement.OwnClauseRestAfterAndTest do
  @moduledoc """
  A law's own commencement clause whose rest statement follows a date and
  "and" (LAT Change Pipeline, step Commencement reader; the Waste, Water
  and Climate round): "… on 30th June 2005 and all other regulations come
  into force on 1st August 2005". The rest statement is read, so the rows
  no statement names take its day.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.{Leftovers, OwnClause}
  alias SertantaiLegal.Scraper.LawStart.Statements

  defp rows(specs) do
    for spec <- specs do
      {sid, text, part} =
        case spec do
          {sid, text, part} -> {sid, text, part}
          {sid, text} -> {sid, text, nil}
          sid -> {sid, "", nil}
        end

      %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: nil}
    end
  end

  defp full_from(specs, id) do
    rs = rows(specs)
    rules = OwnClause.rules("UK_x", %{type_code: "uksi", rows: rs, made: ~D[1970-01-01]})
    {outcome, result} = OwnCommencement.outcome(rules, "UK_x", id, OwnClause.context(rs))
    {outcome, result && result.full_from}
  end

  test "\"and all other regulations come into force on\" (SI 2005/1726 reg.1(2))" do
    specs = [
      "reg.1",
      {"reg.1(2)",
       "This regulation and regulation 18(1) come into force on 30th June 2005 and all other regulations come into force on 1st August 2005."},
      "reg.2",
      "reg.18",
      "reg.18(1)"
    ]

    assert full_from(specs, "reg.2") == {:dated, ~D[2005-08-01]}
    assert full_from(specs, "reg.18(1)") == {:dated, ~D[2005-06-30]}
    assert full_from(specs, "reg.1") == {:dated, ~D[2005-06-30]}
  end

  test "\"and the remaining provisions shall come into operation on\" (SI 1974/607 art.1(2))" do
    specs = [
      "reg.1",
      {"reg.1(2)",
       "Article 16 of this order shall come into operation on 31st March 1974 and the remaining provisions shall come into operation on 1st April 1974."},
      "reg.2",
      "reg.16"
    ]

    assert full_from(specs, "reg.2") == {:dated, ~D[1974-04-01]}
    assert full_from(specs, "reg.16") == {:dated, ~D[1974-03-31]}
  end

  test "\"and all other regulations shall come into force on\" (SI 2005/1638 reg.1(2))" do
    specs = [
      "reg.1",
      {"reg.1(1)",
       "These Regulations may be cited as the Water Supply Licence (Application) Regulations 2005 and shall come into force in accordance with paragraph (2)."},
      {"reg.1(2)",
       "Regulations 1, 2 and 3 shall come into force on 11th July 2005 and all other regulations shall come into force on 1st August 2005."},
      "reg.2",
      "reg.3",
      "reg.4"
    ]

    assert full_from(specs, "reg.4") == {:dated, ~D[2005-08-01]}
    assert full_from(specs, "reg.2") == {:dated, ~D[2005-07-11]}
  end

  test "\"and the remaining provisions of these Regulations shall\" (SSI 2004/358 reg.1(2))" do
    specs = [
      "reg.1",
      {"reg.1(2)",
       "Regulation 7 shall come into force on 31st August 2004 and the remaining provisions of these Regulations shall come into force on 31st March 2005."},
      "reg.2",
      "reg.7"
    ]

    assert full_from(specs, "reg.2") == {:dated, ~D[2005-03-31]}
    assert full_from(specs, "reg.7") == {:dated, ~D[2004-08-31]}
  end

  test "\", and the remainder on\": the verb left out (SI 1988/1048 reg.1(2))" do
    specs = [
      {"pt.I", "", "I"},
      {"reg.1", "", "I"},
      {"reg.1(2)",
       "Parts I, II and V of these Regulations shall come into force on 11th July 1988, and the remainder on 1st October 1988.",
       "I"},
      {"pt.II", "", "II"},
      {"reg.3", "", "II"},
      {"pt.III", "", "III"},
      {"reg.5", "", "III"},
      {"pt.V", "", "V"},
      {"reg.9", "", "V"}
    ]

    assert full_from(specs, "reg.5") == {:dated, ~D[1988-10-01]}
    assert full_from(specs, "pt.III") == {:dated, ~D[1988-10-01]}
    assert full_from(specs, "reg.3") == {:dated, ~D[1988-07-11]}
  end

  test "the leftovers hold the rest's rule from the sentence as written (SI 1988/1048 reg.1(2))" do
    sentence =
      "Parts I, II and V of these Regulations shall come into force on 11th July 1988, and the remainder on 1st October 1988."

    rs =
      rows([
        {"pt.I", "", "I"},
        {"reg.1", "", "I"},
        {"reg.1(2)", sentence, "I"},
        {"pt.III", "", "III"}
      ])

    read = OwnClause.read("UK_x", %{type_code: "uksi", rows: rs, made: ~D[1970-01-01]})

    {_text, own} = Leftovers.statement("UK_x:reg.1(2)", sentence, rs, read)
    assert Enum.any?(own, &(&1.when == {:date, ~D[1988-10-01]}))
  end

  describe "Statements.split/1" do
    test "a list's last item after \"and\" is no break" do
      s = "Regulations 2 and 3 come into force on 1st May 2001 and regulation 4 on 1st June 2001."
      assert Statements.split(s) == [s]
    end

    test "\"and the remainder on\" takes the verb of the statement before" do
      assert Statements.split(
               "Parts I, II and V of these Regulations shall come into force on 11th July 1988, and the remainder on 1st October 1988."
             ) == [
               "Parts I, II and V of these Regulations shall come into force on 11th July 1988",
               "the remainder shall come into force on 1st October 1988."
             ]
    end
  end
end
