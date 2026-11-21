defmodule SertantaiLegal.Scraper.Commencement.OwnClauseContainerRestTest do
  @moduledoc """
  A law's own commencement clause naming the rest of a container (LAT
  Change Pipeline, step Commencement reader; the Waste, Water and Climate
  round): "the remaining provisions of Part 5", "The remainder of
  regulation 11". The rest is that container's, never the whole law's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.OwnClause

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

  defp input(specs, opts),
    do: %{
      type_code: opts[:type] || "uksi",
      rows: rows(specs),
      made: opts[:made] || ~D[1970-01-01]
    }

  defp outcome(specs, id, opts) do
    rs = rows(specs)
    rules = OwnClause.rules("UK_x", input(specs, opts))
    {outcome, result} = OwnCommencement.outcome(rules, "UK_x", id, OwnClause.context(rs))
    {outcome, result && result.full_from}
  end

  @ssi_2020_154 [
    {"pt.1", "", "1"},
    {"reg.1", "", "1"},
    {"reg.1(2)",
     "Parts 1, 4 and 6 come into force on the day after the day on which these Regulations are made.",
     "1"},
    {"reg.1(3)", "In Part 5, regulations 22 to 25 come into force on 1 January 2021.", "1"},
    {"reg.1(4)", "Part 3 comes into force on 1 January 2022.", "1"},
    {"reg.1(4A)",
     "In Part 5, regulations 19, 20 and 21 come into force on 1 July 2025 for the purposes only of registration of groceries retailers, return point operators and takeback service providers.",
     "1"},
    {"reg.1(5)",
     "Parts 2 , 7 and 8, and regulations 19, 20 and 21 for all purposes and the remaining provisions of Part 5 come into force on 1 October 2027.",
     "1"},
    {"pt.2", "", "2"},
    {"reg.4", "", "2"},
    {"pt.3", "", "3"},
    {"reg.10", "", "3"},
    {"pt.4", "", "4"},
    {"reg.15", "", "4"},
    {"pt.5", "", "5"},
    {"reg.19", "", "5"},
    {"reg.20", "", "5"},
    {"reg.21", "", "5"},
    {"reg.22", "", "5"},
    {"reg.25", "", "5"},
    {"reg.26", "", "5"},
    {"pt.6", "", "6"},
    {"reg.30", "", "6"},
    {"pt.7", "", "7"},
    {"reg.40", "", "7"}
  ]

  describe "the rest within a container" do
    test "\"the remaining provisions of Part 5\" is Part 5's rest (SSI 2020/154 reg.1(5))" do
      o = [made: ~D[2020-05-19]]
      assert outcome(@ssi_2020_154, "reg.26", o) == {:dated, ~D[2027-10-01]}
      # (partly in from 1 July 2025 by reg.1(4A), "for the purposes only of")
      assert outcome(@ssi_2020_154, "reg.19", o) == {:staged, ~D[2027-10-01]}
      assert outcome(@ssi_2020_154, "reg.4", o) == {:dated, ~D[2027-10-01]}
      assert outcome(@ssi_2020_154, "reg.40", o) == {:dated, ~D[2027-10-01]}
      assert outcome(@ssi_2020_154, "reg.22", o) == {:dated, ~D[2021-01-01]}
      assert outcome(@ssi_2020_154, "reg.10", o) == {:dated, ~D[2022-01-01]}
      assert outcome(@ssi_2020_154, "reg.15", o) == {:dated, ~D[2020-05-20]}
      assert outcome(@ssi_2020_154, "reg.30", o) == {:dated, ~D[2020-05-20]}
    end

    @nisr_2008_231 [
      "reg.1",
      {"reg.1(1)",
       "These Regulations may be cited as the Quality of Bathing Water Regulations (Northern Ireland) 2008 and come into operation in accordance with paragraphs (2) to (6)."},
      {"reg.1(2)",
       "Regulations 1- 6, regulation 19, paragraph 2 (1) (a) of Schedule 3 and regulation 8 insofar as it relates to that paragraph, come into operation on 30th June 2008."},
      {"reg.1(3)", "Regulation 7 comes into operation on 24th March 2011."},
      {"reg.1(4)",
       "Subject to paragraph (6), regulations 8 to10, 11(1) (a) and (5), 13, 15 to 18 and 20 come into operation on 24th March 2012."},
      {"reg.1(5)",
       "The remainder of regulation 11 and regulations 12 and 14 come into operation on 24th March 2015."},
      {"reg.1(6)",
       "Sub-paragraph (a) of paragraph (1) of regulation 9, regulation 10 insofar as it relates to that sub-paragraph and regulation 21 come into operation on 30th September 2015."},
      "reg.2",
      "reg.6",
      "reg.7",
      "reg.8",
      "reg.9",
      "reg.9(1)",
      "reg.9(1)(a)",
      "reg.10",
      "reg.11",
      "reg.11(1)",
      "reg.11(1)(a)",
      "reg.11(1)(b)",
      "reg.11(2)",
      "reg.11(5)",
      "reg.12",
      "reg.13",
      "reg.14",
      "reg.15",
      "reg.16",
      "reg.18",
      "reg.19",
      "reg.20",
      "reg.21"
    ]

    test "\"The remainder of regulation 11\" is regulation 11's rest (NISR 2008/231 reg.1(4), (5))" do
      o = [type: "nisr"]
      assert outcome(@nisr_2008_231, "reg.11(2)", o) == {:dated, ~D[2015-03-24]}
      assert outcome(@nisr_2008_231, "reg.11(1)(b)", o) == {:dated, ~D[2015-03-24]}
      assert outcome(@nisr_2008_231, "reg.11(1)(a)", o) == {:dated, ~D[2012-03-24]}
      assert outcome(@nisr_2008_231, "reg.11(5)", o) == {:dated, ~D[2012-03-24]}
      assert outcome(@nisr_2008_231, "reg.12", o) == {:dated, ~D[2015-03-24]}
      assert outcome(@nisr_2008_231, "reg.14", o) == {:dated, ~D[2015-03-24]}
      assert outcome(@nisr_2008_231, "reg.13", o) == {:dated, ~D[2012-03-24]}
      assert outcome(@nisr_2008_231, "reg.16", o) == {:dated, ~D[2012-03-24]}
      assert outcome(@nisr_2008_231, "reg.20", o) == {:dated, ~D[2012-03-24]}
      assert outcome(@nisr_2008_231, "reg.2", o) == {:dated, ~D[2008-06-30]}
      assert outcome(@nisr_2008_231, "reg.7", o) == {:dated, ~D[2011-03-24]}
      assert outcome(@nisr_2008_231, "reg.21", o) == {:dated, ~D[2015-09-30]}
    end
  end
end
