defmodule SertantaiLegal.Scraper.Commencement.OwnClauseOtherLawListTest do
  @moduledoc """
  A commencement order's list of another law's provisions is never the
  order's own commencement (LAT Change Pipeline, step Commencement reader):
  "The following provisions of the 2014 Act come into force on 6th March
  2017—" (SI 2017/58 art.2) names the Water Act 2014's sections, not the
  order's articles.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, OwnClause}
  alias SertantaiLegal.Scraper.LawStart.Provisions

  defp rows(specs),
    do:
      for(
        {sid, text} <- specs,
        do: %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}
      )

  defp rules(specs),
    do: OwnClause.rules("UK_x", %{type_code: "uksi", rows: rows(specs), made: ~D[2017-01-25]})

  test "\"The following provisions of the 2014 Act come into force on\" (SI 2017/58 art.2)" do
    assert rules([
             {"reg.1", ""},
             {"reg.2",
              "The following provisions of the 2014 Act come into force on 6th March 2017—"},
             {"reg.2(a)",
              "section 32 (interim duty: sewerage services) so far as it inserts section 110K into the 1991 Act;"},
             {"reg.2(b)",
              "section 56 (further amendments) so far as it relates to paragraph (c);"},
             {"reg.2(c)", "paragraph 64 of Schedule 7 (further amendments)."},
             {"reg.3", ""},
             {"sch.7", ""},
             {"sch.7.para.64", ""}
           ]) == []
  end

  test "\"Subject to article 6, the following provisions of the 2014 Act\" (SI 2015/773 art.2(3))" do
    assert rules([
             {"reg.1", ""},
             {"reg.2", ""},
             {"reg.2(3)",
              "Subject to article 6, the following provisions of the 2014 Act come into force on 6th April 2015 and are brought into force by the Welsh Ministers only—"},
             {"reg.2(3)(a)", "section 4 (duty to supply);"},
             {"reg.2(3)(b)", "section 5 so far as it relates to Schedule 4."},
             {"reg.4", ""},
             {"reg.5", ""},
             {"sch.4", ""}
           ]) == []
  end

  test "the leftovers leave another law's list alone: its date is not the order's (SI 2017/58 art.2)" do
    sentence = "The following provisions of the 2014 Act come into force on 6th March 2017—"

    rs =
      rows([
        {"reg.1", ""},
        {"reg.2", sentence},
        {"reg.2(a)", "section 56 (further amendments) so far as it relates to paragraph (c);"},
        {"reg.3", ""}
      ])

    read = OwnClause.read("UK_x", %{type_code: "uksi", rows: rs, made: ~D[2017-01-25]})

    assert Leftovers.for_law(rs, read, [{"UK_x:reg.2", sentence}]) ==
             [{"UK_x:reg.2", sentence, []}]
  end

  test "an Act's own \"The following provisions of the Act\" is its own (EPA 1990 s.164(2))" do
    assert Provisions.other_law_list?(
             "The following provisions of the Act shall come into force at the end of the period of two months beginning with the day on which it is passed, namely—"
           ) == false

    assert Provisions.other_law_list?(
             "The following provisions of the Environment Act 1995 shall come into force on 1st April 1996—"
           )
  end

  test "a list of the law's own provisions is still read" do
    lines =
      [
        {"reg.1", ""},
        {"reg.1(2)",
         "The following provisions of these Regulations come into force on 6th March 2017—"},
        {"reg.1(2)(a)", "regulation 3;"},
        {"reg.1(2)(b)", "regulation 4."},
        {"reg.3", ""},
        {"reg.4", ""}
      ]
      |> rules()
      |> Enum.map(& &1.scope)

    assert ["reg.3", "reg.4"] in lines
  end
end
