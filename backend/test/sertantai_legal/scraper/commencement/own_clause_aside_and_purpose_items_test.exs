defmodule SertantaiLegal.Scraper.Commencement.OwnClauseAsideAndPurposeItemsTest do
  @moduledoc """
  A law's own commencement clause (LAT Change Pipeline, step Commencement
  reader; the Waste, Water and Climate round): an exception set aside
  between two named items, and a named provision's items each opening with
  its purpose and closing with its day.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.{Check, OwnClause, Rule}

  defp rows(specs) do
    for spec <- specs do
      {sid, text, part} =
        case spec do
          {sid, text, part} -> {sid, text, part}
          {sid, text} -> {sid, text, nil}
          sid -> {sid, "", nil}
        end

      %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: nil, extent_code: nil}
    end
  end

  defp outcome(specs, id) do
    rs = rows(specs)
    rules = OwnClause.rules("UK_x", %{type_code: "uksi", rows: rs, made: ~D[2012-08-06]})
    {outcome, result} = OwnCommencement.outcome(rules, "UK_x", id, OwnClause.context(rs))
    {outcome, result && result.partial_from, result && result.full_from}
  end

  @green_deal [
    {"pt.1", "Introduction", "1"},
    {"reg.1", "", "1"},
    {"reg.1(2)",
     "Parts 1 to 4 of these Regulations, other than regulations 24(1)(d)(i) and (2) and 26, come into force on the day after the day on which these Regulations are made.",
     "1"},
    {"reg.1(3)",
     "Regulations 24(1)(d)(i) and (2) and 26 and , other than regulation 42, Parts 5 to 7 of these Regulations come into force on 28th January 2013.",
     "1"},
    {"reg.1(3A)", "Regulation 42 comes into force—", "1"},
    {"reg.1(3A)(a)",
     "so far as is necessary for the purpose of enabling the Secretary of State to make provision under section 9 and the Scottish Ministers to make provision under section 10, on the relevant date;",
     "1"},
    {"reg.1(3A)(b)", "for all remaining purposes, on 28th January 2013.", "1"},
    {"reg.1(4)", "Part 8 of these Regulations comes into force—", "1"},
    {"reg.1(4)(a)",
     "so far as is necessary for the purpose of enabling the Secretary of State to take action in relation to a breach of the requirements listed in regulation 63 of these Regulations (other than the requirements in regulations 24(1)(d)(i) and (2) and 26), on 1st October 2012;",
     "1"},
    {"reg.1(4)(b)", "for all remaining purposes, on 28th January 2013.", "1"},
    {"pt.4", "Part 4", "4"},
    {"reg.24", "", "4"},
    {"reg.26", "", "4"},
    {"pt.5", "Part 5", "5"},
    {"reg.30", "", "5"},
    {"pt.7", "Part 7", "7"},
    {"reg.42", "", "7"},
    {"reg.43", "", "7"},
    {"pt.8", "Part 8", "8"},
    {"reg.63", "", "8"}
  ]

  describe "SI 2012/2079 reg.1" do
    test "\"A and , other than regulation 42, Parts 5 to 7 … come into force on\": the Parts are named, the aside excepted" do
      assert outcome(@green_deal, "reg.30") == {:dated, nil, ~D[2013-01-28]}
      assert outcome(@green_deal, "reg.43") == {:dated, nil, ~D[2013-01-28]}
      assert outcome(@green_deal, "reg.26") == {:dated, nil, ~D[2013-01-28]}
      assert outcome(@green_deal, "reg.24") == {:dated, nil, ~D[2012-08-07]}
    end

    test "\"for all remaining purposes, on 28th January 2013\": the head's provision, fully" do
      assert {_, _, ~D[2013-01-28]} = outcome(@green_deal, "reg.42")
    end

    test "\"so far as is necessary for the purpose of …, on 1st October 2012\": partly from that day" do
      assert outcome(@green_deal, "reg.63") == {:staged, ~D[2012-10-01], ~D[2013-01-28]}
    end
  end

  describe "2004 c.33 s.263(10)" do
    @cpa [
      "s.261",
      "s.261(1)",
      "s.261(2)",
      "s.261(4)",
      "s.263",
      {"s.263(10)(a)",
       "section 261(2) and Schedule 28 and, so far as relating to any Acts of the Scottish Parliament, section 261(4) and Schedule 30 come into force in accordance with provision made by order by the Scottish Ministers, after consulting the Secretary of State,"},
      {"s.263(10)(b)",
       "section 261(1) and Schedule 27 and, except so far as relating to any Acts of the Scottish Parliament or any provision which extends to Northern Ireland only, section 261(4) and Schedule 30 come into force in accordance with provision made by order by the Secretary of State,"},
      "sch.27",
      "sch.28",
      "sch.30"
    ]

    defp by_order(ref) do
      rs = rows(@cpa)
      rules = OwnClause.rules("UK_x", %{type_code: "ukpga", rows: rs, made: ~D[2004-11-18]})

      for %Rule{scope: scope, when: {:appointed, _}} = r <- rules,
          is_list(scope),
          ref in scope,
          do: {r.source.ref, r.purposes != nil}
    end

    test "\"A and, except so far as relating to …, B\": the qualifier reaches only the items after it" do
      assert by_order("s.261(1)") == [{"s.263(10)(b)", false}]
      assert by_order("sch.27") == [{"s.263(10)(b)", false}]
      assert by_order("s.261(2)") == [{"s.263(10)(a)", false}]

      assert Enum.sort(by_order("s.261(4)")) == [{"s.263(10)(a)", true}, {"s.263(10)(b)", true}]
      assert Enum.sort(by_order("sch.30")) == [{"s.263(10)(a)", true}, {"s.263(10)(b)", true}]
    end
  end

  describe "Check.no_clause?/2" do
    test "a law whose only rules give its Schedules effect states no commencement" do
      effect =
        Rule.new(
          commences: "UK_x",
          scope: ["sch.3"],
          when: {:with, "reg.44(1)"},
          source: %{law: "UK_x", ref: "reg.44(1)", text: "Schedule 3 shall have effect."},
          treatment: :schedule_effect
        )

      assert Check.no_clause?([], :no_clause)
      assert Check.no_clause?([effect], :no_clause)
      refute Check.no_clause?([%{effect | treatment: :provision_dated}], :no_clause)
      refute Check.no_clause?([], :clause_unread)
    end
  end
end
