defmodule SertantaiLegal.Scraper.Commencement.OwnClauseCompletingFormTest do
  @moduledoc """
  A completing form ("so far as not already in force", "to the extent that
  it does not come into force in accordance with subsection (1)") limits
  nothing: its provisions come into force in full on the statement's day,
  and the subsection it points to is never one of them. The Tobacco and
  Vapes Act 2026 s.175(3), the Local Government and Public Involvement in
  Health Act 2007 s.245(2) and SI 2026/15 reg.1(3).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart.Completing

  defp row(law, sid, text, part \\ nil),
    do: %{section_id: "#{law}:#{sid}", text: text, part: part}

  defp rules(law, type, made, rows),
    do:
      OwnClause.rules(law, %{
        type_code: type,
        rows: rows,
        made: made,
        clml_head: nil,
        lrt_date: nil
      })

  describe "Completing.drop/1" do
    test "a bracket after the verb" do
      assert Completing.drop(
               "The following come into force on 1 January 2027 (so far as not in force by virtue of subsection (2))—"
             ) == "The following come into force on 1 January 2027—"
    end

    test "a bracket after an item" do
      assert Completing.drop(
               "Part 3 (to the extent that it does not come into force in accordance with subsection (1));"
             ) == "Part 3;"
    end

    test "the words leading a sentence" do
      assert Completing.drop(
               "In so far as they are not already in force, these Regulations come into force on 6th April 2026."
             ) == "these Regulations come into force on 6th April 2026."
    end

    test "the words after an item, with the subsection they point to (the Planning (Wales) Act 2015 s.58(4)(b))" do
      assert Completing.drop(
               "Parts 3 to 8, so far as they are not brought into force by subsection (2)(b)."
             ) == "Parts 3 to 8."
    end

    test "a qualifier that limits stays" do
      text = "section 70 so far as relating to paragraph 23 of Schedule 8."
      assert Completing.drop(text) == text
    end
  end

  describe "the Tobacco and Vapes Act 2026 s.175(3)" do
    @law "UK_ukpga_2026_18"

    test "the listed provisions are in full on 1 January 2027" do
      rows = [
        row(@law, "s.1", "…"),
        row(@law, "s.2", "…"),
        row(@law, "s.52", "…"),
        row(@law, "sch.7.para.1", "…"),
        row(
          @law,
          "s.175(3)",
          "The following (which relate to the age of sale of tobacco etc) come into force on 1 January 2027 (so far as not in force by virtue of subsection (2))—"
        ),
        row(@law, "s.175(3)(a)", "sections 1 and 2 and Schedule 7;"),
        row(@law, "s.175(3)(b)", "section 52.")
      ]

      got = for r <- rules(@law, "ukpga", ~D[2026-04-29], rows), is_list(r.scope), do: r

      assert [rule] = Enum.filter(got, &("s.52" in &1.scope))
      assert rule.scope == ~w[s.1 s.2 sch.7 s.52]
      assert rule.when == {:date, ~D[2027-01-01]}
      assert rule.purposes == nil
      assert rule.source.text =~ "so far as not in force by virtue of subsection (2)"
    end
  end

  describe "the Local Government and Public Involvement in Health Act 2007 s.245(2)" do
    @law "UK_ukpga_2007_28"

    test "Part 3 is in full two months on, and subsection (1) is no provision of the list" do
      rows = [
        row(@law, "s.23", "…", "2"),
        row(@law, "s.74", "…", "3"),
        row(@law, "s.235", "…", "15"),
        row(
          @law,
          "s.245(1)",
          "This section and sections 74(2), 240, 242, 244 and 246, and Part 3 of Schedule 4, come into force on the day on which this Act is passed.",
          "16"
        ),
        row(
          @law,
          "s.245(2)",
          "The following provisions come into force at the end of two months beginning with the day on which this Act is passed—",
          "16"
        ),
        row(@law, "s.245(2)(a)", "Part 2;", "16"),
        row(
          @law,
          "s.245(2)(b)",
          "Part 3 (to the extent that it does not come into force in accordance with subsection (1));",
          "16"
        ),
        row(@law, "s.245(2)(c)", "section 235 and Schedule 17.", "16")
      ]

      got =
        for r <- rules(@law, "ukpga", ~D[2007-10-30], rows),
            is_list(r.scope),
            r.source.ref == "s.245(2)",
            do: r

      assert [rule] = got
      assert "pt.3" in rule.scope
      assert "pt.2" in rule.scope
      refute "s.245(1)" in rule.scope
      assert rule.purposes == nil
      assert rule.when == {:date, ~D[2007-12-30]}
    end
  end

  describe "SI 2026/15 reg.1(3)" do
    @law "UK_uksi_2026_15"

    test "the rest of the Regulations come into force on 6th April 2026, in full" do
      rows = [
        row(
          @law,
          "reg.1(2)",
          "The following provisions of these Regulations come into force on 18th February 2026—"
        ),
        row(@law, "reg.1(2)(a)", "this regulation and regulations 2 and 3;"),
        row(@law, "reg.1(2)(b)", "regulation 9."),
        row(
          @law,
          "reg.1(3)",
          "In so far as they are not already in force, these Regulations come into force on 6th April 2026."
        ),
        row(@law, "reg.2", "…"),
        row(@law, "reg.3", "…"),
        row(@law, "reg.4", "…"),
        row(@law, "reg.9", "…")
      ]

      got = rules(@law, "uksi", ~D[2026-01-12], rows)

      assert [rest] = Enum.filter(got, &(&1.scope == :rest))
      assert rest.when == {:date, ~D[2026-04-06]}
      assert rest.purposes == nil
    end
  end
end
