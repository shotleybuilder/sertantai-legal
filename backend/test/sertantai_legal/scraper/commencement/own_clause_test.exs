defmodule SertantaiLegal.Scraper.Commencement.OwnClauseTest do
  @moduledoc """
  CR-03: a law's own commencement clause as rules — the law-level start
  (`LawStart`'s treatment) and the provision-level sentences
  (`LawStart.Provisions.groups/3`) — and the evaluator dating rows from them.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Evaluator, OwnClause, Rule}

  defp rows(specs),
    do:
      for(
        spec <- specs,
        do:
          case spec do
            {sid, text, part, chapter} ->
              %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: chapter}

            {sid, text, part} ->
              %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: nil}

            {sid, text} ->
              %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}

            sid ->
              %{section_id: "UK_x:" <> sid, text: "", part: nil, chapter: nil}
          end
      )

  defp read(specs, opts \\ []) do
    rs = rows(specs)

    rules =
      OwnClause.rules("UK_x", %{
        type_code: Keyword.get(opts, :type, "uksi"),
        rows: rs,
        made: opts[:made],
        clml_head: opts[:head]
      })

    {rules, rs}
  end

  defp lines(rules),
    do: Enum.map(rules, &(&1 |> Rule.to_text() |> String.split(" — UK_x") |> hd()))

  defp date_of(rules, rows, sid) do
    rules
    |> Evaluator.evaluate(sid, OwnClause.context(rows))
    |> Map.fetch!(:full_from)
  end

  test "one date for the whole law" do
    {rules, _} =
      read([{"reg.1", "These Regulations come into force on 1st April 2020."}, "reg.2"])

    assert lines(rules) == ["all — 2020-04-01 — everywhere, fully — clause_date"]
    assert [%Rule{source: %{law: "UK_x", ref: "reg.1"}}] = rules
  end

  test "an Act left to orders: all appointed by order" do
    {rules, rs} =
      read(
        [
          {"s.30(2)",
           "This Act comes into force on such day as the Secretary of State may by order appoint."},
          "s.1"
        ],
        type: "ukpga"
      )

    assert lines(rules) == ["all — appointed (by order) — everywhere, fully — by_order"]
    assert date_of(rules, rs, "UK_x:s.1") == nil
  end

  describe "provision-level sentences (wsi 2026/103)" do
    @specs [
      {"reg.1(2)",
       "Except as provided in paragraphs (3) and (4), these Regulations come into force on 1 October 2027.",
       "1"},
      {"reg.1(3)",
       "The following provisions come into force on the day after the day on which these Regulations are made—",
       "1"},
      {"reg.1(3)(a)", "this Part;", "1"},
      {"reg.1(3)(b)", "Chapter 1 of Part 6 (items subject to overseas schemes);", "1"},
      {"reg.1(3)(c)", "Part 7 (the scheme administrator), except regulation 73;", "1"},
      {"reg.1(4)",
       "Regulation 73 (reuse of returned refund items) comes into force on 1 October 2030.", "1"},
      {"reg.2", "", "1"},
      {"reg.50", "", "6", "1"},
      {"reg.60", "", "6", "2"},
      {"reg.70", "", "7"},
      {"reg.73", "", "7"}
    ]

    test "the rules, one readable line each" do
      {rules, _} = read(@specs, made: ~D[2026-03-25])

      assert lines(rules) == [
               "all — 2027-10-01 — everywhere, fully — clause_date",
               "pt.1, pt.6.ch.1, pt.7 except reg.73 — 2026-03-26 — everywhere, fully — provision_dated",
               "reg.73 — 2030-10-01 — everywhere, fully — provision_dated"
             ]
    end

    test "each row's date from the evaluator" do
      {rules, rs} = read(@specs, made: ~D[2026-03-25])
      on = &date_of(rules, rs, "UK_x:" <> &1)

      assert on.("reg.2") == ~D[2026-03-26]
      assert on.("reg.50") == ~D[2026-03-26]
      assert on.("reg.60") == ~D[2027-10-01]
      assert on.("reg.70") == ~D[2026-03-26]
      assert on.("reg.73") == ~D[2030-10-01]
    end
  end

  test "named provisions, the remaining ones by order; the clause itself commences with them" do
    {rules, rs} =
      read(
        [
          {"s.40(1)", "Sections 1 and 2 come into force on 1st January 2025."},
          {"s.40(2)",
           "The remaining provisions of this Act come into force on such day as the Scottish Ministers may by order appoint."},
          "s.1",
          "s.2",
          "s.3"
        ],
        type: "asp"
      )

    assert "rest except s.40 — appointed (by order) — everywhere, fully — provision_by_order" in lines(
             rules
           )

    on = &date_of(rules, rs, "UK_x:" <> &1)
    assert on.("s.1") == ~D[2025-01-01]
    assert on.("s.3") == nil
  end

  describe "qualified sentences: partial entries" do
    test "for some purposes — in_relation_to, with the exception subtracted" do
      {rules, rs} =
        read([
          {"reg.1(1)",
           "These Regulations may be cited as the Quarries Regulations (Northern Ireland) 2006 and, subject to paragraphs (2) and (3), shall come into operation on 1st August 2006."},
          {"reg.1(2)",
           "Regulation 26, with the exception of paragraph (4), shall come into operation on 1st August 2007 with respect to any tip which was not a classified tip."},
          "reg.26",
          "reg.26(4)"
        ])

      assert "reg.26 except reg.26(4) — 2007-08-01 — everywhere, in relation to — provision_qualified" in lines(
               rules
             )

      # in force for classified tips with the Regulations, fully once the rest is added
      r = Evaluator.evaluate(rules, "UK_x:reg.26", OwnClause.context(rs))
      assert %{partial_from: ~D[2006-08-01], full_from: ~D[2007-08-01]} = r
    end

    test "in relation to a territory — the territory, not purposes" do
      {rules, _} =
        read([
          {"reg.1(1)", "These Regulations come into force on 1st April 2020."},
          {"reg.1(2)", "Regulation 5 comes into force in relation to Wales on 1st October 2020."},
          "reg.5"
        ])

      assert "reg.5 — 2020-10-01 — W, fully — provision_qualified" in lines(rules)
    end

    test "\"in Wales on …\" is qualified too" do
      {rules, _} =
        read([
          {"reg.1(1)", "These Regulations come into force on 1st April 2020."},
          {"reg.1(2)", "Regulation 5 comes into force in Wales on 1st October 2020."},
          "reg.5"
        ])

      assert "reg.5 — 2020-10-01 — W, fully — provision_qualified" in lines(rules)
    end

    test "for the purpose of making regulations" do
      {rules, _} =
        read(
          [
            {"s.20(1)", "This Act comes into force on 1st April 2020."},
            {"s.20(2)",
             "Section 5 comes into force on 1st January 2020 for the purpose of making regulations."},
            "s.5"
          ],
          type: "ukpga"
        )

      assert "s.5 — 2020-01-01 — everywhere, for making secondary legislation — provision_qualified" in lines(
               rules
             )
    end
  end

  test "uksi 2017/469: \"the day after the day on which the Order is made\"; otherwise 8 May" do
    {rules, rs} =
      read(
        [
          {"reg.1(1)", "This Order may be cited as the X Order 2017."},
          {"reg.1(2)",
           "This article, article 2 and article 11 come into force on the day after the day on which the Order is made."},
          {"reg.1(3)", "Otherwise this Order comes into force on 8th May 2017."},
          "reg.2",
          "reg.5",
          "reg.11"
        ],
        made: ~D[2017-03-24]
      )

    on = &date_of(rules, rs, "UK_x:" <> &1)
    assert on.("reg.1(2)") == ~D[2017-03-25]
    assert on.("reg.11") == ~D[2017-03-25]
    assert on.("reg.5") == ~D[2017-05-08]
  end

  test "no clause, an EU directive: no rule (unknown stays unknown)" do
    {rules, _} = read(["reg.1", "reg.2"])
    assert rules == []
  end
end
