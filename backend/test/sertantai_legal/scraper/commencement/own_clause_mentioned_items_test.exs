defmodule SertantaiLegal.Scraper.Commencement.OwnClauseMentionedItemsTest do
  @moduledoc """
  A commencement statement naming its provisions by another subsection's
  list (LAT Change Pipeline, step Commencement reader; the Waste, Water and
  Climate round): "The provisions specified in subsection (2) come into
  force—" (Clean Neighbourhoods and Environment Act 2005 s.108(1)). Each
  listed item is read as a list item: what it excepts is left out ("Part 7
  above except sections 83(2) and 85"), and another Act's provision is
  never this Act's ("the repeals to the Environmental Protection Act 1990,
  other than the repeal to section 33 of that Act").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause

  defp row({sid, text, part}),
    do: %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: nil}

  @cnea_2005 [
    {"s.33", "", "4"},
    {"s.47", "", "5"},
    {"s.83", "", "7"},
    {"s.83(2)", "", "7"},
    {"s.84", "", "7"},
    {"s.85", "", "7"},
    {"s.108", "", "10"},
    {"s.108(1)", "The provisions specified in subsection (2) come into force—", "10"},
    {"s.108(1)(a)",
     "in relation to England, in accordance with provision made by order by the Secretary of State; and",
     "10"},
    {"s.108(1)(b)",
     "in relation to Wales, in accordance with provision so made by the National Assembly for Wales.",
     "10"},
    {"s.108(2)", "The provisions referred to in subsection (1) are—", "10"},
    {"s.108(2)(h)",
     "section 47, paragraph 4 of Schedule 4 and, in Part 4 of Schedule 5, the repeals to the Environmental Protection Act 1990, other than the repeal to section 33 of that Act;",
     "10"},
    {"s.108(2)(n)",
     "Part 7 above except sections 83(2) and 85, and in Part 7 of Schedule 5, the repeals to the Noise and Statutory Nuisance Act 1993 (c. 40) and the Noise Act 1996 (c. 37);",
     "10"},
    {"s.108(4)",
     "These provisions come into force at the end of the period of two months beginning with the day on which this Act is passed—",
     "10"},
    {"s.108(4)(d)", "section 33;", "10"},
    {"s.108(4)(i)", "section 83(2).", "10"}
  ]

  test "a subsection's listed items are read as items: their exceptions out, another Act's section never this Act's" do
    rules =
      OwnClause.rules("UK_x", %{
        type_code: "ukpga",
        rows: Enum.map(@cnea_2005, &row/1),
        made: ~D[2005-04-07],
        clml_head: ~s(<ukm:EnactmentDate Date="2005-04-07"/>)
      })

    for ref <- ["s.108(1)(a)", "s.108(1)(b)"] do
      # the Parts of Schedule 5 named for their repeals only are partly in
      # (`own_clause_nested_items_test`): a rule of their own
      assert [rule, partly] = Enum.filter(rules, &(&1.source.ref == ref))
      assert rule.treatment == :provision_by_order
      assert "s.47" in rule.scope
      assert "sch.4.para.4" in rule.scope
      assert "sch.5.pt.7" in partly.scope
      assert partly.purposes == :in_relation_to
      refute "sch.5.pt.7" in rule.scope
      refute "sch.5.pt.7" in rule.except
      refute "s.33" in rule.scope
      refute "s.85" in rule.scope
      refute "s.83(2)" in rule.scope
      assert "s.85" in rule.except
      assert "s.83(2)" in rule.except
    end

    # section 85, excepted and named nowhere else, keeps the Act's general
    # rule; section 83(2) has its own date
    general = Enum.find(rules, &(&1.scope == :all))
    assert "pt.7" in general.except
    assert [kept] = Enum.filter(rules, &(&1.scope == ["s.85"]))
    assert kept.when == general.when
  end
end
