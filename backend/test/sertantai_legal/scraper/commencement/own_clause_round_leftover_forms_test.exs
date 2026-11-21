defmodule SertantaiLegal.Scraper.Commencement.OwnClauseRoundLeftoverFormsTest do
  @moduledoc """
  A law's own commencement clause, the forms the Waste, Water and Climate
  round's leftovers named (LAT Change Pipeline, step Commencement reader):
  "the day on which it receives Royal Assent", "that day" in a list's head,
  a named provision then "all other regulations", and "Except for …, these
  Regulations come into force".
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}
  alias SertantaiLegal.Scraper.LawStart.Clause

  defp rows(specs) do
    for spec <- specs do
      {sid, text} = if is_tuple(spec), do: spec, else: {spec, ""}
      %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}
    end
  end

  defp lines(specs, opts) do
    "UK_x"
    |> OwnClause.rules(%{
      type_code: Keyword.get(opts, :type, "uksi"),
      rows: rows(specs),
      made: opts[:made],
      lrt_date: opts[:lrt]
    })
    |> Enum.map(&(&1 |> Rule.to_text() |> String.split(" — UK_x") |> hd()))
  end

  test "\"the day after the day on which it receives Royal Assent\" (2022 c.31 (N.I.) s.64)" do
    assert Clause.tail_date(
             "on the day after the day on which it receives Royal Assent.",
             ~D[2022-06-06]
           ) == {:clause_made_relative, ~D[2022-06-07]}
  end

  test "a list's head counting from \"that day\", the day two heads back (2011 c.19 s.38)" do
    got =
      lines(
        [
          {"s.38(1)",
           "Any provision of Part 2 that amends another Act so as to confer any such power comes into force, for the purposes of the exercise of the power, on the day on which this Act is passed."},
          {"s.38(2)", "The following provisions of this Act come into force on that day—"},
          {"s.38(2)(a)", "sections 30 to 33;"},
          {"s.38(2)(b)", "section 37;"},
          {"s.38(3)",
           "The following provisions of this Act come into force at the end of the period of 2 months beginning with that day—"},
          {"s.38(3)(a)", "section 1 (and Schedule 1);"},
          {"s.38(3)(b)", "section 25;"},
          {"s.38(4)",
           "The other provisions of this Act come into force in accordance with provision made by order by the Secretary of State."},
          "s.1",
          "s.25",
          "s.30",
          "s.31",
          "s.32",
          "s.33",
          "s.37"
        ],
        type: "ukpga",
        made: ~D[2011-11-03]
      )

    assert Enum.any?(got, &(&1 =~ ~r/^s\.1, sch\.1, s\.25 — 2012-01-03 — everywhere, fully/))
    assert Enum.any?(got, &(&1 =~ ~r/^s\.30.*s\.37 — 2011-11-03 — everywhere, fully/))
  end

  test "a named provision's day, then \"all other regulations\" (SI 2010/740 reg.1(2))" do
    got =
      lines(
        [
          {"reg.1(1)", "These Regulations may be cited as the Detergents Regulations 2010."},
          {"reg.1(2)",
           "Regulation 9 comes into force on 1st\u00A0January 2015 and all other regulations come into force on 6th\u00A0April 2010."},
          "reg.2",
          "reg.9"
        ],
        made: ~D[2010-03-10],
        lrt: ~D[2015-01-01]
      )

    assert "reg.9 — 2015-01-01 — everywhere, fully — provision_dated" in got
    assert Enum.any?(got, &(&1 =~ ~r/^rest except reg\.1 — 2010-04-06 — everywhere, fully/))
    # the law's own start is the earliest day its statements state
    assert Enum.any?(got, &(&1 =~ ~r/^all — 2010-04-06 — everywhere, fully — clause_staged/))
  end

  test "a list item's date with a no-break space (SSI 2010/426 reg.1)" do
    got =
      lines(
        [
          {"reg.1", "These Regulations—"},
          {"reg.1(a)",
           "may be cited as the Flood Risk Management (Scotland) Regulations 2010; and"},
          {"reg.1(b)", "come into force on 24th\u00A0December 2010."}
        ],
        made: ~D[2010-11-30]
      )

    assert Enum.any?(got, &(&1 =~ ~r/^all — 2010-12-24 — everywhere, fully — clause_date/))
  end

  test "\"Except for regulation 2(3) and (4), these Regulations come into force on\" (SI 2025/407 reg.1(2))" do
    got =
      lines(
        [
          {"reg.1(2)",
           "Except for regulation 2(3) and (4), these Regulations come into force on 22nd May 2025."},
          {"reg.1(3)", "Regulation 2(3) and (4) comes into force on 29th November 2025."},
          "reg.2",
          "reg.2(3)",
          "reg.2(4)"
        ],
        made: ~D[2025-04-01]
      )

    assert Enum.any?(got, &(&1 =~ ~r/^all except reg\.2\(3\), reg\.2\(4\) — 2025-05-22/))
    assert "reg.2(3), reg.2(4) — 2025-11-29 — everywhere, fully — provision_dated" in got
  end

  describe "SI 2013/3113 reg.1(3), (4): a list run on without a comma; a Schedule's Part named after it" do
    # (its regulations in Parts 1 to 3; the Schedules' Parts are no Part of
    # the regulations themselves)
    defp s3113_rows do
      clause = [
        {"reg.1(2)",
         "Subject to paragraphs (3), (4) and (5) these Regulations shall come into force on 1st January 2014."},
        {"reg.1(3)",
         "Regulation 66(6) and Schedule 11, Part 2, paragraph 23 shall come into force on 1st January 2016."},
        {"reg.1(4)",
         "Regulations 6, 11(11)(a)(ii), 11(13)(b), 17(1)(d)(ii), 20(2) 28(8)(a)(ii), 28(10)(b), 36, 38, 41, 57(g)(ii), 58(3)(c)(ii), 66(7) and (8), schedule 7, Part 1, paragraph 6(c), schedule 8 Part 3 and schedule 11, Part 2, paragraph 24 shall come into force on 1st January 2019."}
      ]

      held =
        for {id, part} <- [
              {"reg.1", "1"},
              {"reg.2", "1"},
              {"reg.6", "1"},
              {"reg.11(11)(a)(ii)", "2"},
              {"reg.11(13)(b)", "2"},
              {"reg.17(1)(d)(ii)", "2"},
              {"reg.20(2)", "2"},
              {"reg.28(8)(a)(ii)", "3"},
              {"reg.28(10)(b)", "3"},
              {"reg.36", "3"},
              {"reg.38", "3"},
              {"reg.41", "3"},
              {"reg.57(g)(ii)", "3"},
              {"reg.58(3)(c)(ii)", "3"},
              {"reg.66(6)", "3"},
              {"reg.66(7)", "3"},
              {"reg.66(8)", "3"}
            ],
            do: %{section_id: "UK_x:" <> id, text: "", part: part, chapter: nil}

      held ++
        for(
          {sid, text} <- clause,
          do: %{section_id: "UK_x:" <> sid, text: text, part: "1", chapter: nil}
        )
    end

    defp scope_on(date) do
      "UK_x"
      |> OwnClause.rules(%{
        type_code: "uksi",
        rows: s3113_rows(),
        made: ~D[2013-12-10],
        lrt_date: nil
      })
      |> Enum.find(&(&1.when == {:date, date}))
      |> Map.fetch!(:scope)
    end

    test "every regulation listed after the missing comma is in the 2019 list" do
      scope = scope_on(~D[2019-01-01])

      for r <- [
            "reg.20(2)",
            "reg.28(8)(a)(ii)",
            "reg.28(10)(b)",
            "reg.36",
            "reg.41",
            "reg.57(g)(ii)",
            "reg.66(7)",
            "reg.66(8)"
          ],
          do: assert(r in scope, "#{r} in #{inspect(scope)}")
    end

    test "\"schedule 7, Part 1, paragraph 6(c)\" names no Part of the regulations" do
      refute Enum.any?(scope_on(~D[2019-01-01]), &String.starts_with?(&1, "pt."))
      refute Enum.any?(scope_on(~D[2016-01-01]), &String.starts_with?(&1, "pt."))
    end
  end
end
