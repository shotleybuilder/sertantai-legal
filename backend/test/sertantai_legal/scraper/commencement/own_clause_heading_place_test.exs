defmodule SertantaiLegal.Scraper.Commencement.OwnClauseHeadingPlaceTest do
  @moduledoc """
  A country named only in a provision's bracketed heading ("section 52
  (termination of grants for redevelopment in Scotland)") is the heading's,
  never the territory of the statement's partial rule: the Housing and
  Planning Act 1986 s.57(1) and SI 2010/490 reg.1(4). A country the
  statement's own words state stays its territory.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause

  defp row(law, sid, text), do: %{section_id: "#{law}:#{sid}", text: text, part: nil}

  defp partial(law, type, made, rows) do
    input = %{type_code: type, rows: rows, made: made, clml_head: nil, lrt_date: nil}
    for r <- OwnClause.rules(law, input), is_list(r.scope), r.purposes || r.territory, do: r
  end

  test "the Housing and Planning Act 1986 s.57(1): section 24(3) is partly in, for no one country" do
    law = "UK_ukpga_1986_63"

    rows = [
      row(law, "s.21", "…"),
      row(law, "s.24(1)(j)", "…"),
      row(law, "s.24(3)", "…"),
      row(law, "s.52", "…"),
      row(
        law,
        "s.57(1)",
        "The following provisions of this Act come into force on the day this Act is passed— section 21 (effect of resolutions relating to housing action area or general improvement area); section 24(1)(j), paragraphs 10 to 13 of Schedule 5, the repeals specified in the first part of Part I of Schedule 12 and section 24(3) so far as relating to those repeals (miscellaneous corrections); section 52 (termination of grants for redevelopment in Scotland); this Part."
      )
    ]

    assert [rule] = partial(law, "ukpga", ~D[1986-11-07], rows)
    assert rule.scope == ["s.24(3)"]
    assert rule.territory == nil
    assert rule.purposes == :in_relation_to
  end

  test "SI 2010/490 reg.1(4): regulation 38 is partly in, for no one country" do
    law = "UK_uksi_2010_490"

    rows = [
      row(
        law,
        "reg.1(2)",
        "Except as provided by paragraphs (3) and (4), these Regulations come into force on 1st April 2010."
      ),
      row(
        law,
        "reg.1(4)",
        "The following provisions come into force immediately after section 134 of the Marine Act (orders for protection of marine conservation zones in Wales) comes into force (so far as not already brought into force)—"
      ),
      row(
        law,
        "reg.1(4)(a)",
        "paragraph (2) of regulation 38 (European marine sites: byelaws and orders), and paragraphs (3), (4) and (5) of that regulation in so far as they relate to paragraph (2)."
      ),
      row(law, "reg.38", "…")
    ]

    got = partial(law, "uksi", ~D[2010-03-01], rows)
    assert got != []
    assert Enum.map(got, & &1.territory) |> Enum.uniq() == [nil]
  end

  test "a country in the statement's own words stays its territory" do
    law = "UK_uksi_2020_1"

    rows = [
      row(
        law,
        "reg.1(2)",
        "Regulation 4 (fees in Scotland) comes into force in relation to Wales on 1st October 2020."
      ),
      row(law, "reg.4", "…")
    ]

    assert [%{territory: "W"}] = partial(law, "uksi", ~D[2020-01-06], rows)
  end
end
