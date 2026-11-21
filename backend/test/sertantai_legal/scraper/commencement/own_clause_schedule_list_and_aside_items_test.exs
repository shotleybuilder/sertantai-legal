defmodule SertantaiLegal.Scraper.Commencement.OwnClauseScheduleListAndAsideItemsTest do
  @moduledoc """
  A law's own commencement list read item by item (LAT Change Pipeline,
  step Commencement reader; the Waste, Water and Climate round): a list of
  one Schedule's provisions ("The following provisions of Schedule 2 …—
  paragraph 2; Part 2") names that Schedule's paragraphs and Parts, never
  the law's own Part; an item qualified in an aside ("sections 117(7) (and
  section 117(6) so far as relates to it), 158, 167") leaves only the
  aside's provision partly in.
  """
  use ExUnit.Case, async: true

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

  defp rules(specs, type, made, ref) do
    "UK_x"
    |> OwnClause.rules(%{type_code: type, rows: rows(specs), made: made})
    |> Enum.filter(&(&1.source.ref == ref and &1.scope != :all))
    |> Enum.map(&{Enum.sort(List.wrap(&1.scope)), &1.when, &1.treatment})
    |> Enum.sort()
  end

  @asc_2023_4 [
    {"s.8", "", "2"},
    {"s.9", "", "2"},
    {"s.55", "", "6"},
    {"s.56", "", "6"},
    {"s.56(3)",
     "The following provisions of Schedule 2, and section 55 to the extent it relates to those provisions, also come into force at the end of the period of two months beginning with the day on which this Act receives Royal Assent—",
     "6"},
    {"s.56(3)(a)",
     "paragraph 1(5)(b) for the purposes of the application of section 53(5)(a) of the Agriculture Act 2020 (c. 21) in relation to Part 1 of Schedule 5 to that Act;",
     "6"},
    {"s.56(3)(b)",
     "paragraph 1(9) for the purposes of the repeal of Part 1 of Schedule 5 to the Agriculture Act 2020;",
     "6"},
    {"s.56(3)(c)", "paragraph 2;", "6"},
    {"s.56(3)(d)", "Part 2.", "6"},
    {"s.56(4)",
     "Except as provided for by subsections (1) to (3), the provisions of this Act come into force on a day appointed by the Welsh Ministers in an order made by statutory instrument.",
     "6"},
    {"s.57", "", "6"}
  ]

  test "a list of one Schedule's provisions names its paragraphs and Parts (asc 2023/4 s.56(3))" do
    assert rules(@asc_2023_4, "asc", ~D[2023-08-17], "s.56(3)") == [
             {["s.55", "sch.2.para.1(5)(b)", "sch.2.para.1(9)"], {:date, ~D[2023-10-17]},
              :provision_qualified},
             {["sch.2.para.2", "sch.2.pt.2"], {:date, ~D[2023-10-17]}, :provision_dated}
           ]
  end

  @socpa_2005 [
    {"s.117", "", "3"},
    {"s.117(6)", "", "3"},
    {"s.117(7)", "", "3"},
    {"s.158", "", "5"},
    {"s.167", "", "5"},
    {"s.172", "", "6"},
    {"s.173", "", "6"},
    {"s.174", "", "6"},
    {"s.174(2)", "", "6"},
    {"s.176", "", "6"},
    {"s.177", "", "6"},
    {"s.178", "", "6"},
    {"s.178(1)",
     "The following provisions come into force on the day on which this Act is passed—", "6"},
    {"s.178(1)(a)",
     "sections 117(7) (and section 117(6) so far as relates to it), 158, 167, 172, 173, 176, 177, this section and section 179, and",
     "6"},
    {"s.178(1)(b)",
     "Part 1 of Schedule 17 and (so far as it relates to that Part of that Schedule) section 174(2).",
     "6"},
    {"s.178(8)",
     "Otherwise, this Act comes into force on such day as the Secretary of State may by order appoint.",
     "6"},
    {"s.179", "", "6"}
  ]

  test "an item qualified in an aside leaves only the aside's provision partly in (SOCPA 2005 s.178(1))" do
    assert rules(@socpa_2005, "ukpga", ~D[2005-04-07], "s.178(1)") == [
             {["s.117(6)", "s.174(2)"], {:date, ~D[2005-04-07]}, :provision_qualified},
             {[
                "s.117(7)",
                "s.158",
                "s.167",
                "s.172",
                "s.173",
                "s.176",
                "s.177",
                "s.178",
                "s.179",
                "sch.17.pt.1"
              ], {:date, ~D[2005-04-07]}, :provision_dated}
           ]
  end
end
