defmodule SertantaiLegal.Scraper.Commencement.OwnClauseRelativeDayFormsTest do
  @moduledoc """
  A law's own commencement clause, three forms of a day counted or chosen
  (LAT Change Pipeline, step Commencement reader; the Waste, Water and
  Climate round): "X or, if later, Y" (the later day), a purpose before
  the day of passing, and "beginning with day on which this Act is passed".
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
      clml_head: opts[:head]
    })
    |> Enum.map(&(&1 |> Rule.to_text() |> String.split(" — UK_x") |> hd()))
  end

  describe "\"or, if later,\"" do
    test "the later of the two days is the start (SI 2018/797 reg.1(2)(b))" do
      got =
        lines(
          [
            "reg.1",
            {"reg.1(2)", "Subject to paragraph (3)—"},
            {"reg.1(2)(a)",
             "regulations 1 and 2 come into force on the twenty-first day after the day on which these Regulations are made, and"},
            {"reg.1(2)(b)",
             "regulation 3 comes into force on the twenty-first day after the day on which these Regulations are made or, if later, the 1st October 2018."},
            "reg.2",
            "reg.3"
          ],
          made: ~D[2018-06-27]
        )

      assert "reg.3 — 2018-10-01 — everywhere, fully — provision_dated" in got
      assert "reg.1, reg.2 — 2018-07-18 — everywhere, fully — provision_dated" in got
    end

    test "the counted day when it is the later" do
      assert Clause.tail_date(
               "on the twenty-first day after the day on which these Regulations are made or, if later, the 1st October 2018.",
               ~D[2018-09-20]
             ) == {:clause_made_relative, ~D[2018-10-11]}
    end

    test "a second day that is an unread event leaves the start unread, never the first day" do
      tail =
        "on 1st October 2018 or, if later, the day on which the Convention enters into force for the United Kingdom."

      assert Clause.tail_date(tail, ~D[2018-06-27]) == nil

      got =
        lines(
          [
            "reg.1",
            {"reg.1(1)",
             "Except as provided in paragraph (2), these Regulations come into force on 1st July 2018."},
            {"reg.1(2)", "Regulation 3 comes into force " <> tail},
            "reg.3"
          ],
          made: ~D[2018-06-27]
        )

      assert "reg.3 — unread — everywhere, fully — provision_unread" in got
    end
  end

  describe "counted from the passing" do
    @assent ~s(<ukm:EnactmentDate Date="2012-12-19"/>)

    test "beginning with day on which this Act is passed, with no article (2012 c.21 s.122(2))" do
      got =
        lines(
          [
            "s.108",
            "s.113",
            "s.122",
            {"s.122(2)",
             "Sections 108 and 113 come into force at the end of the period of 2 months beginning with day on which this Act is passed."}
          ],
          type: "ukpga",
          made: ~D[2012-12-19],
          head: @assent
        )

      assert "s.108, s.113 — 2013-02-19 — everywhere, fully — provision_dated" in got
    end

    test "the day after the purpose: partly in on the passing (2011 c.19 s.38(1))" do
      got =
        lines(
          [
            "s.4",
            "s.38",
            {"s.38(1)",
             "Section 4 comes into force, for the purposes of the exercise of the power, on the day on which this Act is passed."}
          ],
          type: "ukpga",
          made: ~D[2011-11-03],
          head: ~s(<ukm:EnactmentDate Date="2011-11-03"/>)
        )

      assert Enum.any?(
               got,
               &(&1 =~ ~r/^s\.4 — 2011-11-03 — everywhere, (?!fully).* — provision_qualified$/)
             )
    end
  end
end
