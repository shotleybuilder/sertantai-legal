defmodule SertantaiLegal.Scraper.Commencement.Review.PartItemsTest do
  @moduledoc """
  The review of own-clause rules naming a Part: each with the law's own
  words for it, and the ones dated in full whose words carry a limit (the
  Agriculture Act 2020 s.57(1)(b): "any provision of Parts 1 to 7 which—").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Review.PartItems
  alias SertantaiLegal.Scraper.Commencement.Rule

  @law "UK_ukpga_2020_21"

  defp row(sid, text, part \\ "8"), do: %{section_id: "#{@law}:#{sid}", text: text, part: part}

  defp rows,
    do: [
      row(
        "s.57(1)",
        "The following provisions come into force on the day on which this Act is passed—"
      ),
      row("s.57(1)(a)", "sections 17 and 18;"),
      row("s.57(1)(b)", "any provision of Parts 1 to 7 which—"),
      row("s.57(1)(d)", "this Part, apart from section 52 and Schedule 7.")
    ]

  defp rule(scope, treatment, purposes \\ nil),
    do:
      Rule.new(
        commences: @law,
        scope: scope,
        when: {:date, ~D[2020-11-11]},
        purposes: purposes,
        source: %{law: @law, ref: "s.57(1)", text: nil},
        treatment: treatment
      )

  test "a limit: a relative clause, so far as, for the purposes of; never a completing form" do
    assert PartItems.limited?("any provision of Parts 1 to 7 which—")
    assert PartItems.limited?("Part 3 so far as it confers power to make regulations")
    assert PartItems.limited?("Part 2 for the purposes of making regulations")

    refute PartItems.limited?(
             "Parts 3 to 8, so far as not brought into force by subsection (2)(b)"
           )

    refute PartItems.limited?("this Part, apart from section 52 and Schedule 7.")
  end

  test "a rule dating Parts in full from limited words is the misreading; a qualified one is not" do
    misread = rule(["s.17", "pt.1", "pt.4", "pt.8"], :provision_dated)
    items = PartItems.items(@law, [misread, rule(["s.17"], :provision_dated)], rows())

    assert [%{ref: "s.57(1)", qualified: false, limited: true, words: words}] = items
    assert words =~ "any provision of Parts 1 to 7 which—"
    assert PartItems.full_with_limit(items) == items

    assert PartItems.line(hd(items)) =~
             "UK_ukpga_2020_21 | s.57(1) | provision_dated | full | LIMIT |"

    read = rule(["pt.1", "pt.4"], :provision_qualified, :in_relation_to)
    assert [%{qualified: true, limited: true} = ok] = PartItems.items(@law, [read], rows())
    assert PartItems.full_with_limit([ok]) == []
  end

  test "a plain Part item is full with no limit" do
    assert [%{limited: false, words: "this Part, apart from section 52 and Schedule 7."}] =
             PartItems.items(@law, [rule(["pt.8"], :provision_dated)], rows())
  end
end
