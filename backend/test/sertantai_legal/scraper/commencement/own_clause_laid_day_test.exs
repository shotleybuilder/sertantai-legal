defmodule SertantaiLegal.Scraper.Commencement.OwnClauseLaidDayTest do
  @moduledoc """
  A law's own commencement clause counting from the day it is laid (LAT
  Change Pipeline, step Commencement reader): the laid day is carried with
  the made day (`LawStart.OwnDays`), read from the CLML's `ukm:Laid`
  (`LawStart.LaidDay`); a clause counting from a laid day not held is an
  unread statement with its reason, never dropped.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.{Clause, LaidDay, OwnDays}

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

  defp input(specs, made, laid),
    do: %{type_code: "uksi", rows: rows(specs), made: made, laid: laid}

  defp read(specs, made, laid), do: OwnClause.read("UK_x", input(specs, made, laid))

  defp full_from(specs, id, made, laid) do
    rules = read(specs, made, laid).rules
    {outcome, result} = OwnCommencement.outcome(rules, "UK_x", id, OwnClause.context(rows(specs)))
    {outcome, result && result.full_from}
  end

  defp days(made, laid), do: %OwnDays{made: made, laid: laid}

  # The Exotic Disease (Amendment etc.) (EU Exit) Regulations 2018
  @si_2018_1221 [
    "reg.1",
    {"reg.2", "These Regulations come into force—"},
    {"reg.2(a)",
     "for the purposes of regulations 1, 2 and 3 on the 22nd day after the day on which these Regulations are laid, and"},
    {"reg.2(b)", "for all other purposes, on exit day."},
    "reg.3",
    "reg.3(1)",
    "reg.4"
  ]

  # The Certification of Fuels and Fireplaces (Charges) (England)
  # Regulations 2025
  @si_2025_287 [
    "reg.1",
    {"reg.1(1)",
     "These Regulations may be cited as the Certification of Fuels and Fireplaces (Charges) (England) Regulations 2025."},
    {"reg.1(2)",
     "These Regulations come into force at the end of a period of 21 days beginning with the day after the day on which these Regulations are laid."},
    "reg.2"
  ]

  describe "the laid day in the CLML's metadata (LaidDay)" do
    test "the day laid before Parliament (SI 2018/1221)" do
      head =
        ~s(<ukm:Made Date="2018-11-22"/><ukm:Laid Date="2018-11-28" Class="UnitedKingdomParliament"/>)

      assert LaidDay.parse(head) == ~D[2018-11-28]
    end

    test "laid before two Houses on different days: the later" do
      head =
        ~s(<ukm:Laid Date="2019-02-05" Class="HouseOfCommons"/><ukm:Laid Date="2019-02-06" Class="HouseOfLords"/>)

      assert LaidDay.parse(head) == ~D[2019-02-06]
    end

    test "none stated, or no metadata" do
      assert LaidDay.parse(~s(<ukm:Made Date="2018-11-22"/>)) == nil
      assert LaidDay.parse(nil) == nil
    end
  end

  describe "a tail counting from the laid day (Clause.tail_date)" do
    test "the Nth day after the day on which these Regulations are laid (SI 2018/1221 reg.2(a))" do
      tail = "on the 22nd day after the day on which these Regulations are laid"

      assert Clause.tail_date(tail, days(~D[2018-11-22], ~D[2018-11-28])) ==
               {:clause_laid_relative, ~D[2018-12-20]}
    end

    test "the end of a period beginning with the day after the laid day (SI 2025/287 reg.1(2))" do
      tail =
        "at the end of a period of 21 days beginning with the day after the day on which these Regulations are laid"

      assert Clause.tail_date(tail, days(~D[2025-03-06], ~D[2025-03-10])) ==
               {:clause_laid_relative, ~D[2025-04-01]}
    end

    test "laid before Parliament, or a House (SI 2020/559 reg.1; SI 2021/917 reg.1)" do
      d = days(~D[2020-06-01], ~D[2020-06-03])

      assert Clause.tail_date(
               "on the 21st day after the day on which they are laid before Parliament",
               d
             ) == {:clause_laid_relative, ~D[2020-06-24]}

      assert Clause.tail_date(
               "on the 21st day after the day on which they are laid before the House of Commons",
               d
             ) == {:clause_laid_relative, ~D[2020-06-24]}
    end

    test "N days after, and the day after, the day on which they are laid (SI 2026/425; SI 2020/1142)" do
      d = days(~D[2020-06-01], ~D[2020-06-03])

      assert Clause.tail_date("21 days after the day on which they are laid", d) ==
               {:clause_laid_relative, ~D[2020-06-24]}

      assert Clause.tail_date("on the day after the day on which they are laid", d) ==
               {:clause_laid_relative, ~D[2020-06-04]}
    end

    test "no laid day held: unknown, as a made day not held is; a made-relative tail still reads" do
      tail = "on the 22nd day after the day on which these Regulations are laid"
      assert Clause.tail_date(tail, days(~D[2018-11-22], nil)) == :laid_unknown
      assert Clause.tail_date(tail, ~D[2018-11-22]) == :laid_unknown
      assert Clause.tail_date(tail, nil) == :laid_unknown

      assert Clause.tail_date(
               "on the day after the day on which they are made",
               days(~D[2018-11-22], nil)
             ) == {:clause_made_relative, ~D[2018-11-23]}
    end
  end

  describe "the law's own clause (OwnClause)" do
    test "SI 2018/1221 reg.2: regs 1, 2 and 3 on the 22nd day after laying, the rest on exit day, nothing partly" do
      made = ~D[2018-11-22]
      laid = ~D[2018-11-28]

      for id <- ["reg.1", "reg.2", "reg.3", "reg.3(1)"] do
        assert full_from(@si_2018_1221, id, made, laid) == {:dated, ~D[2018-12-20]}
      end

      # exit day in an instrument made before it: IP completion day
      assert full_from(@si_2018_1221, "reg.4", made, laid) == {:dated, ~D[2020-12-31]}

      assert [] ==
               for(
                 r <- read(@si_2018_1221, made, laid).rules,
                 r.treatment == :provision_qualified,
                 do: r
               )
    end

    test "SI 2018/1221 reg.2 with no laid day held: (a) is an unread record with its reason, never dropped" do
      read = read(@si_2018_1221, ~D[2018-11-22], nil)

      assert [unread] = Enum.filter(read.unread, &(&1.evidence == "UK_x:reg.2(a)"))
      assert unread.reason == :laid_day_not_held
      assert unread.text =~ "are laid"

      # … and its rule: regs 1, 2 and 3 unread, never on exit day with the rest
      assert [rule] = Enum.filter(read.rules, &(&1.treatment == :provision_unread))
      assert rule.scope == ["reg.1", "reg.2", "reg.3"]
      assert rule.when == :unread
      assert rule.source.ref == "reg.2(a)"

      assert {outcome, nil} = full_from(@si_2018_1221, "reg.3", ~D[2018-11-22], nil)
      assert outcome != :dated
      assert full_from(@si_2018_1221, "reg.4", ~D[2018-11-22], nil) == {:dated, ~D[2020-12-31]}
    end

    test "SI 2025/287 reg.1(2): the whole law, the day after the 21 days end" do
      assert full_from(@si_2025_287, "reg.2", ~D[2025-03-06], ~D[2025-03-10]) ==
               {:dated, ~D[2025-04-01]}
    end

    test "SI 2025/287 reg.1(2) with no laid day held: unread, never Royal Assent or a made day" do
      read = read(@si_2025_287, ~D[2025-03-06], nil)
      assert read.law.treatment == :clause_unread
      assert [%{scope: :all, when: :unread}] = read.rules
      assert {outcome, nil} = full_from(@si_2025_287, "reg.2", ~D[2025-03-06], nil)
      assert outcome != :dated
    end
  end

  describe "the law's start (LawStart)" do
    test "SI 2025/287: the clause's laid-relative day" do
      start = LawStart.resolve(input(@si_2025_287, ~D[2025-03-06], ~D[2025-03-10]))
      assert start.treatment == :clause_laid_relative
      assert start.date == ~D[2025-04-01]
    end

    test "SI 2025/287 with no laid day held: the clause is unread" do
      start = LawStart.resolve(input(@si_2025_287, ~D[2025-03-06], nil))
      assert start.treatment == :clause_unread
      assert start.date == nil
    end
  end
end
