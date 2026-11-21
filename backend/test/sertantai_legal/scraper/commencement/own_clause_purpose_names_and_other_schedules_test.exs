defmodule SertantaiLegal.Scraper.Commencement.OwnClausePurposeNamesAndOtherSchedulesTest do
  @moduledoc """
  A law's own commencement clause (LAT Change Pipeline, step Commencement
  reader; Waste, Water and Climate round): a provision that only names a
  statement's purpose is not in its scope, and another Act's Schedule is
  never the law's own.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, OwnClause}

  defp rows(specs) do
    for spec <- specs do
      {sid, text} =
        case spec do
          {sid, text} -> {sid, text}
          sid -> {sid, ""}
        end

      %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}
    end
  end

  defp read(specs, made, type),
    do: OwnClause.read("UK_x", %{type_code: type, rows: rows(specs), made: made})

  test "\"In relation to an offence under regulation 3(2), regulations 6 to 8 …\": 3(2) names the purpose (SI 2017/1312 reg.1(4))" do
    specs = [
      "reg.1",
      {"reg.1(2)",
       "Except as provided in paragraphs (3) and (4), these Regulations come into force 21 days after the day on which they are made."},
      {"reg.1(4)",
       "In relation to an offence under regulation 3(2), regulations 6 to 8 come into force 6 months after the day on which these Regulations are made."},
      "reg.2",
      "reg.3",
      "reg.3(2)",
      "reg.6",
      "reg.7",
      "reg.8"
    ]

    rules = read(specs, ~D[2017-12-19], "uksi").rules

    assert [%{scope: ["reg.6", "reg.7", "reg.8"], when: {:date, ~D[2018-06-19]}}] =
             Enum.filter(rules, &(&1.treatment == :provision_qualified))

    refute Enum.any?(rules, &(is_list(&1.scope) and "reg.3(2)" in &1.scope))

    # … and the purpose's provision is no word left unread
    read = read(specs, ~D[2017-12-19], "uksi")

    assert [] ==
             for(
               %{row: "UK_x:reg.1(4)", leftovers: [_ | _] = l} <-
                 Leftovers.sentences(rows(specs), read),
               do: l
             )
  end

  test "\"Schedule 3 to the Criminal Justice Act 1967\" is that Act's, never the law's own (1988 c.33 s.171(6))" do
    specs = [
      "s.44",
      "s.170",
      "s.170(1)",
      "s.170(2)",
      "s.171",
      {"s.171(1)",
       "Subject to the following provisions of this section, this Act shall come into force on such day as the Secretary of State may by order made by statutory instrument appoint."},
      {"s.171(6)",
       "The following provisions— section 44; subsection (1) of section 170, so far as relating to the Sexual Offences (Amendment) Act 1976; subsection (2) of that section, so far as relating to the following— the Prevention of Corruption Act 1916; Schedule 3 to the Criminal Justice Act 1967; section 28(3) of the Criminal Justice Act 1972; shall come into force at the end of the period of two months beginning with the day this Act is passed."},
      "sch.3"
    ]

    rules = read(specs, ~D[1988-07-29], "ukpga").rules
    dated = for r <- rules, r.when == {:date, ~D[1988-09-29]}, is_list(r.scope), do: r
    assert Enum.any?(dated, &("s.44" in &1.scope))
    refute Enum.any?(dated, &("sch.3" in &1.scope))
  end

  test "a Part of another Act's Schedule is no Part of the law (asc 2023/4 s.56(3)(b))" do
    specs = [
      {"s.1", ""},
      "s.56",
      {"s.56(3)",
       "Paragraph 9 of Schedule 2, for the purposes of the repeal of Part 1 of Schedule 5 to the Agriculture Act 2020, comes into force on 1st October 2023."},
      "sch.2.para.9",
      "sch.5.pt.1"
    ]

    scopes =
      for r <- read(specs, ~D[2023-08-17], "asc").rules, is_list(r.scope), s <- r.scope, do: s

    assert scopes == ["sch.2.para.9"]
  end
end
